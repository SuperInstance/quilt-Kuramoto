// Band skeleton — SOAK HARNESS (the gate-1 instrument).
//
// Runs against a deployed scrap-quilt worker or local `wrangler dev`:
//   1. POST /band/open            → learn startMs/barMs (server clock anchor)
//   2. four scripted voices commit each bar ~2 bars before its freeze
//      deadline, on absolute-time timers (one optional voice is "killed"
//      partway through to prove the shell policy fires)
//   3. polls /band/stats, logging per-bar fire jitter as it arrives
//   4. POST /band/stop → GET /band/bars → dumps JSON + .song + .mid
//   5. prints the verdict math: % bars fired ≤100 ms late, worst drift,
//      per-voice on-time rate
//
// Usage:
//   npx tsx scripts/band-soak.ts --url http://127.0.0.1:8787 --minutes 5.5
//   npx tsx scripts/band-soak.ts --url https://scrap-quilt.<acct>.workers.dev --minutes 5.5 \
//          --kill keys --kill-frac 0.6

import { mkdirSync, writeFileSync } from 'node:fs';
import { PATTERNS, VOICE_NAMES, summarizeJitter, type JitterSample } from '../src/band/common';
import { barsToSong, songToMidi } from '../src/band/midi';

// ---------------------------------------------------------------- args

const argv = process.argv.slice(2);
const arg = (name: string, dflt: string): string => {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : dflt;
};
const BASE = arg('url', 'http://127.0.0.1:8787').replace(/\/$/, '');
const MINUTES = parseFloat(arg('minutes', '5.5'));
const TEMPO = parseInt(arg('tempo', '96'), 10);
const ROOM = arg('room', `soak-${new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)}`);
const KILL_VOICE = arg('kill', 'keys');           // voice silenced at kill-frac to prove shells
const KILL_FRAC = parseFloat(arg('kill-frac', '0.6'));
const LEAD_BARS = parseFloat(arg('lead-bars', '2')); // bars of commit lead BEFORE FREEZE (spec §3.1 H)
const OUT_DIR = arg('out', 'out');

// ---------------------------------------------------------------- http

async function call(path: string, init?: RequestInit, timeoutMs = 15000): Promise<any> {
  const ctrl = new AbortController();
  const to = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(`${BASE}${path}`, { ...init, signal: ctrl.signal });
    const text = await res.text();
    try { return JSON.parse(text); } catch { return { error: `non-JSON response: ${text.slice(0, 120)}` }; }
  } finally { clearTimeout(to); }
}

const log = (...a: unknown[]) => console.log(new Date().toISOString().slice(11, 23), ...a);

// ---------------------------------------------------------------- run

async function main(): Promise<void> {
  log(`band soak — room=${ROOM} tempo=${TEMPO} minutes=${MINUTES} url=${BASE}`);
  log(`commit lead: ${LEAD_BARS} bars before freeze | shell-policy demo: voice '${KILL_VOICE}' goes silent at ${Math.round(KILL_FRAC * 100)}% through`);

  const open = await call(`/band/open?room=${ROOM}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tempo: TEMPO, prerollBars: 2 }),
  });
  if (!open?.ok) throw new Error(`open failed: ${JSON.stringify(open)}`);
  const { startMs, barMs, serverNow } = open as { startMs: number; barMs: number; serverNow: number };

  // server-clock anchor: local wall time for a server timestamp
  const offset = serverNow - Date.now();
  const localFor = (serverT: number) => serverT - offset;
  const soundAt = (bar: number) => startMs + bar * barMs; // server wall time

  const totalBars = Math.max(8, Math.floor((MINUTES * 60000) / barMs));
  const killBar = KILL_VOICE ? Math.floor(totalBars * KILL_FRAC) : Infinity;
  log(`clock anchored: startMs=${startMs} barMs=${barMs} totalBars=${totalBars} (kill ${KILL_VOICE} at bar ${killBar})`);

  // ---- scripted voices: commit each bar ~2 bars before its freeze deadline
  interface VoiceLog { sent: number; accepted: number; late: number; rejected: number; rttMs: number[]; leads: number[]; }
  const vlog: Record<string, VoiceLog> = {};
  for (const v of VOICE_NAMES) vlog[v] = { sent: 0, accepted: 0, late: 0, rejected: 0, rttMs: [], leads: [] };
  const timers: NodeJS.Timeout[] = [];

  for (let bar = 0; bar < totalBars; bar++) {
    // commit target: LEAD_BARS before the bar's FREEZE deadline (= sound − 1
    // bar). Lead 2 → commits land ~2 bars before freeze (spec §3.1 H=2).
    const commitAtServer = soundAt(bar) - barMs - (LEAD_BARS - 1) * barMs;
    const delay = Math.max(0, localFor(commitAtServer) - Date.now());
    timers.push(setTimeout(async () => {
      for (const voice of VOICE_NAMES) {
        if (voice === KILL_VOICE && bar >= killBar) continue; // the kill: intent stream stops
        const t0 = Date.now();
        try {
          const r = await call(`/band/commit?room=${ROOM}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ voice, bar, events: PATTERNS[voice](bar) }),
          });
          const L = vlog[voice]; L.sent++; L.rttMs.push(Date.now() - t0);
          if (r?.ok === true) { L.accepted++; L.leads.push(r.leadMs); }
          else if (r?.late) L.late++;
          else L.rejected++;
        } catch (e) { vlog[voice].rejected++; log(`commit ${voice} bar ${bar} ERROR ${(e as Error).message}`); }
      }
    }, delay));
  }

  // ---- poll stats: log per-bar fire jitter as the DO reports it
  let seen = 0;
  let lastSummaryLine = 0;
  const poll = setInterval(async () => {
    try {
      const s = await call(`/band/stats?room=${ROOM}`);
      const recent: JitterSample[] = s?.recent ?? [];
      for (const smp of recent) {
        if (smp.t > seen - 1 && smp.t !== 0 && smp.t >= seen) {
          if (smp.t > seen) seen = smp.t;
          if (smp.j > 100 || smp.c === 1) log(`  ⚠ tick ${smp.t} fired ${smp.j} ms late${smp.c ? ' (catch-up)' : ''}`);
        }
      }
      seen = Math.max(seen, s?.tickCount ?? 0);
      if (Date.now() - lastSummaryLine > 30000) {
        lastSummaryLine = Date.now();
        const sum = s?.summary;
        if (sum) log(`  … ticks=${sum.n} p95=${sum.p95Ms}ms max=${sum.maxMs}ms ≤100ms=${sum.within100Pct}% catchups=${sum.catchups}`);
      }
    } catch { /* transient */ }
  }, 3000);

  // ---- wait for the last bar to sound + settle, then stop
  const soakEnd = localFor(soundAt(totalBars - 1) + 2 * barMs) - Date.now();
  log(`soaking ${(soakEnd / 60000).toFixed(1)} min…`);
  await new Promise(r => setTimeout(r, soakEnd));
  clearInterval(poll);
  for (const t of timers) clearTimeout(t);

  // ---- report
  const stop = await call(`/band/stop?room=${ROOM}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  const sum = stop?.summary;
  const samples: JitterSample[] = stop?.samples ?? [];

  log('\n════════ SOAK REPORT — alarm reliability (the gate-1 question) ════════');
  if (sum) {
    log(`bars fired            : ${sum.n}`);
    log(`fire jitter mean      : ${sum.meanMs} ms`);
    log(`fire jitter median    : ${sum.medianMs} ms`);
    log(`fire jitter p95 / p99 : ${sum.p95Ms} / ${sum.p99Ms} ms`);
    log(`worst drift (max)     : ${sum.maxMs} ms`);
    log(`fired ≤ 50 ms late    : ${sum.within50Pct}%`);
    log(`fired ≤ 100 ms late   : ${sum.within100Pct}%   ← pass bar: >100 ms rate < 1%`);
    log(`fired > 100 ms late   : ${sum.over100Pct}%`);
    log(`catch-up batches      : ${sum.catchups} (${sum.catchupPct}%)`);
  } else log('NO SUMMARY RETURNED', JSON.stringify(stop).slice(0, 400));

  log('\n── voice discipline ──');
  const barsPlayed = stop?.frozenBars ?? 0;
  for (const v of VOICE_NAMES) {
    const L = vlog[v];
    const commits = stop?.commits?.[v];
    const misses = stop?.misses?.[v] ?? 0;
    const attempted = L.sent + L.late;
    const onTime = attempted ? ((L.accepted / attempted) * 100).toFixed(1) : '—';
    const rttMed = L.rttMs.length ? L.rttMs.slice().sort((a, b) => a - b)[Math.floor(L.rttMs.length / 2)] : 0;
    const leads = L.leads.slice().sort((a, b) => a - b);
    const leadMed = leads.length ? leads[Math.floor(leads.length / 2)] : 0;
    const leadMin = leads[0] ?? 0;
    log(`${v.padEnd(7)} sent=${L.sent} accepted=${L.accepted} late=${L.late} rej=${L.rejected}` +
      ` on-time=${onTime}% commitRtt~${rttMed}ms lead med/min=${leadMed}/${leadMin}ms` +
      ` | server: accepted=${commits?.accepted ?? 0} late=${commits?.late ?? 0} misses(shells)=${misses}`);
  }
  if (KILL_VOICE && killBar < totalBars) {
    log(`shell-policy proof: ${KILL_VOICE} silenced from bar ${killBar} → shells for ${barsPlayed - killBar} bars (see misses + D1 kind='shell'/'rest')`);
  }

  // ---- render proof: dump frozen bars → JSON + .song + .mid (retry: the
  // take dump is the proof, tolerate one transient)
  let take: any = null;
  for (let i = 0; i < 3 && !take?.bars; i++) {
    take = await call(`/band/bars?room=${ROOM}`, undefined, 30000);
    if (!take?.bars) { log(`bars fetch retry ${i + 1}: ${take?.error ?? 'no bars'}`); await new Promise(r => setTimeout(r, 2000)); }
  }
  const rows = (take?.bars ?? []).map((b: any) => ({ bar: b.bar, voice: b.voice, kind: b.kind, events: b.events }));
  const kinds: Record<string, number> = {};
  for (const r of rows) kinds[r.kind] = (kinds[r.kind] ?? 0) + 1;

  mkdirSync(OUT_DIR, { recursive: true });
  const stem = `${OUT_DIR}/band-soak-${ROOM}`;
  writeFileSync(`${stem}.json`, JSON.stringify({ room: ROOM, tempo: TEMPO, summary: sum, commits: stop?.commits, misses: stop?.misses, bars: rows }, null, 2));
  const song = barsToSong(ROOM, TEMPO, rows);
  writeFileSync(`${stem}.song.json`, JSON.stringify(song));
  const midi = songToMidi(song);
  writeFileSync(`${stem}.mid`, midi);

  log('\n── render proof ──');
  log(`frozen rows: ${rows.length} across ${song.bars.length} bars — kinds: ${JSON.stringify(kinds)}`);
  log(`wrote ${stem}.json, ${stem}.song.json, ${stem}.mid (${midi.length} bytes)`);

  // ---- verdict (spec §14.0: late-fire > 100 ms rate < 1%)
  const verdict = sum ? (sum.over100Pct < 1 ? 'PASS — the room holds tempo' : 'FAIL — external-ticker fallback (spec §2.1) becomes the design')
    : 'INCONCLUSIVE — no stats';
  const clientOnTime = VOICE_NAMES.every(v => {
    const L = vlog[v]; const att = L.sent + L.late;
    return !att || L.accepted / att > 0.99;
  });
  log(`\nVERDICT: ${verdict}`);
  log(`voice on-time ≥99% (excl. intentional kill): ${clientOnTime ? 'PASS' : 'FAIL'} (lead ${LEAD_BARS} bars before freeze)`);

  const harnessSummary = summarizeJitter(samples); // cross-check from raw samples
  if (sum && (harnessSummary.n !== sum.n || harnessSummary.maxMs !== sum.maxMs)) {
    log(`⚠ harness recompute mismatch: ${JSON.stringify(harnessSummary)} vs ${JSON.stringify(sum)}`);
  }
  process.exit(0);
}

main().catch(e => { console.error('soak failed:', e); process.exit(1); });
