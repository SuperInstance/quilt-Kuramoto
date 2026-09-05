// scrap-quilt — BandRoom Durable Object: the yard-band BAR CLOCK (skeleton).
//
// The self-rescheduling DO alarm IS the metronome (spec §2.1 — the new,
// spike-gated pattern; nothing else in the fleet self-schedules):
//   · alarm() schedules the NEXT alarm at an ABSOLUTE deadline
//     (startMs + nextTick*barMs), never "+interval" — drift can't accumulate.
//   · a catch-up loop drains every tick whose deadline has passed, in order,
//     so one late fire processes the missed boundaries without losing beats.
//   · tick N freezes bar N+1 (freeze lead = 1 bar): committed intent becomes
//     immutable truth; a voice with no intent gets the SHELL POLICY (held
//     root / rest, miss logged) — never an error (§3.3).
//   · bar blobs live in D1 (band_bars: pending at commit, frozen at freeze).
//
// Measured alarm reliability: docs/BAND_SKELETON.md (the go/no-go).

import { DurableObject } from 'cloudflare:workers';
import {
  VOICES, VOICE_NAMES, barMsFor, shellFor, summarizeJitter, validateEvents,
  HORIZON, type BarEvent, type JitterSample,
} from './band/common';

export interface Env { DB: D1Database }

interface CommitStat {
  accepted: number;   // commits that landed before freeze
  late: number;       // commits rejected because the bar had already frozen
  leadSumMs: number; leadMinMs: number; leadMaxMs: number; leadN: number;
}

interface RoomState {
  room: string;
  tempo: number; barMs: number;
  playing: boolean;
  openedAt: number; startMs: number;   // tick 0 fires at startMs; tick −1 one bar earlier
  nextTick: number;                    // next bar boundary to process
  tickCount: number; frozenBars: number;
  pending: Record<string, { events: BarEvent[]; committedAt: number }>; // `${bar}:${voice}`
  misses: Record<string, number>;      // shell substitutions per voice (logged, not errors)
  commits: Record<string, CommitStat>;
  jitter: JitterSample[];              // bounded ring — the soak's evidence
  lastTickJitterMs: number;
}

const JITTER_RING = 2400;   // ~100 min at 2.5 s bars; DO memory stays O(ring)
const CATCHUP_CAP = 64;     // bound ticks per firing (fail-safe; 64 × barMs ≈ full stop already)
const SNAPSHOT_KEY = 'band-snapshot-v1';

function freshCommits(): Record<string, CommitStat> {
  const c: Record<string, CommitStat> = {};
  for (const v of VOICE_NAMES) c[v] = { accepted: 0, late: 0, leadSumMs: 0, leadMinMs: 0, leadMaxMs: 0, leadN: 0 };
  return c;
}

function freshState(room: string): RoomState {
  return {
    room, tempo: 96, barMs: barMsFor(96), playing: false,
    openedAt: 0, startMs: 0, nextTick: 0, tickCount: 0, frozenBars: 0,
    pending: {}, misses: {}, commits: freshCommits(), jitter: [], lastTickJitterMs: 0,
  };
}

export class BandRoom extends DurableObject<Env> {
  private s: RoomState = freshState('yard');
  private loaded = false;
  private wsClients = new Set<WebSocket>();

  constructor(ctx: DurableObjectState, env: Env) { super(ctx, env); }

  // ---------------------------------------------------------------- load/persist

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    this.loaded = true;
    try {
      const snap = await this.ctx.storage.get<RoomState>(SNAPSHOT_KEY);
      if (snap && typeof snap.nextTick === 'number') {
        this.s = { ...freshState(snap.room ?? 'yard'), ...snap, commits: { ...freshCommits(), ...(snap.commits ?? {}) } };
      }
    } catch (e) { console.error('BandRoom load failed', e); }
    // if we come back mid-tune, the platform refires the persisted alarm and
    // the catch-up loop drains every boundary that came due while we were out
  }

  private async persist(): Promise<void> {
    try {
      this.s.jitter = this.s.jitter.slice(-JITTER_RING);
      await this.ctx.storage.put(SNAPSHOT_KEY, this.s);
    } catch (e) { console.error('BandRoom persist failed', e); }
  }

  // ---------------------------------------------------------------- clock

  private deadlineOf(tick: number): number { return this.s.startMs + tick * this.s.barMs; }

  private broadcast(msg: unknown): void {
    const data = JSON.stringify(msg);
    for (const ws of this.wsClients) {
      try {
        if (ws.readyState === WebSocket.READY_STATE_OPEN) ws.send(data);
        else if (ws.readyState >= WebSocket.READY_STATE_CLOSED) this.wsClients.delete(ws);
      } catch { this.wsClients.delete(ws); }
    }
  }

  // ---- one bar boundary: freeze bar (tick+1), log jitter, queue D1 blobs.
  // Pure in-memory + broadcast: NO awaits — the clock never waits on D1
  // (spec §12: "D1 hiccup → room runs from in-memory rings; blobs flush on
  // recovery"). The caller flushes the returned statements via waitUntil.
  private processTick(tick: number, deadlineMs: number, firedMs: number, catchup: boolean): D1PreparedStatement[] {
    const bar = tick + 1;
    const froze: Array<{ bar: number; voice: string; kind: string; n: number }> = [];
    const stmts: D1PreparedStatement[] = [];

    for (const v of VOICES) {
      const key = `${bar}:${v.voice}`;
      const intent = this.s.pending[key];
      let kind: string; let events: BarEvent[];
      if (intent) {
        kind = 'ok'; events = intent.events;
        delete this.s.pending[key];
      } else {
        // SHELL POLICY (§3.3 tier 3): no intent → held root / rest. A musical
        // act, logged as a miss for the voice — never an error, never a hole.
        const shell = shellFor(v, bar);
        kind = shell.kind; events = shell.events;
        this.s.misses[v.voice] = (this.s.misses[v.voice] ?? 0) + 1;
      }
      froze.push({ bar, voice: v.voice, kind, n: events.length });
      stmts.push(this.env.DB.prepare(
        `INSERT INTO band_bars (room, bar, voice, events_json, status, kind, committed_at, deadline_at, frozen_at)
         VALUES (?, ?, ?, ?, 'frozen', ?, ?, ?, ?)
         ON CONFLICT (room, bar, voice) DO UPDATE SET
           status = 'frozen', kind = excluded.kind, events_json = excluded.events_json,
           frozen_at = excluded.frozen_at`,
      ).bind(this.s.room, bar, v.voice, JSON.stringify(events), kind, intent?.committedAt ?? null, deadlineMs, firedMs));
    }

    this.s.tickCount += 1;
    this.s.frozenBars = bar + 1;
    this.s.jitter.push({ t: tick, j: Math.max(0, firedMs - deadlineMs), c: catchup ? 1 : 0 });
    this.s.lastTickJitterMs = firedMs - deadlineMs;

    this.broadcast({
      type: 'bandtick', tick, bar, firedAt: firedMs, deadlineMs,
      jitterMs: firedMs - deadlineMs, catchup, froze,
    });

    return stmts;
  }

  // ---- THE ALARM: self-rescheduling bar clock with catch-up loop --------
  async alarm(): Promise<void> {
    await this.ensureLoaded();
    const firedAt = Date.now(); // frozen at handler start — this IS the fire time
    if (!this.s.playing) return;

    let batch = 0;
    const blobStmts: D1PreparedStatement[] = [];
    while (firedAt >= this.deadlineOf(this.s.nextTick) && batch < CATCHUP_CAP) {
      const tick = this.s.nextTick;
      blobStmts.push(...this.processTick(tick, this.deadlineOf(tick), firedAt, batch > 0));
      this.s.nextTick += 1;
      batch += 1;
    }
    // THE critical section: reschedule at the ABSOLUTE next deadline before
    // anything slow — a late fire cannot drag the grid with it (never
    // "+interval"). Blob flushes and the snapshot ride behind via waitUntil.
    await this.ctx.storage.setAlarm(this.deadlineOf(this.s.nextTick));
    this.ctx.waitUntil((async () => {
      if (blobStmts.length) {
        try { await this.env.DB.batch(blobStmts); } catch (e) { console.error('freeze D1 batch failed', e); }
      }
      await this.persist();
    })());
  }

  // ---------------------------------------------------------------- fetch

  async fetch(request: Request): Promise<Response> {
    await this.ensureLoaded();
    const url = new URL(request.url);
    const path = url.pathname.replace(/^\/band/, '') || '/';
    const roomParam = url.searchParams.get('room');
    const CORS = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const ok = (data: unknown, status = 200) => Response.json(data, { status, headers: CORS });

    // ---- POST /band/open — start (or restart) the clock ------------------
    if (path === '/open' && request.method === 'POST') {
      let body: { tempo?: number; prerollBars?: number; room?: string } = {};
      try { body = await request.json(); } catch { /* defaults */ }
      const tempo = Math.min(Math.max(body.tempo ?? 96, 40), 240);
      const prerollBars = Math.min(Math.max(body.prerollBars ?? 2, 1), 8);
      const barMsV = barMsFor(tempo);

      this.s = freshState(roomParam ?? 'yard');
      this.s.tempo = tempo; this.s.barMs = barMsV;
      this.s.openedAt = Date.now();
      this.s.startMs = this.s.openedAt + prerollBars * barMsV;
      this.s.nextTick = -1;   // tick −1 (one bar before start) freezes bar 0
      this.s.playing = true;

      // fresh room = fresh table slice (soak rooms are unique names anyway)
      try { await this.env.DB.prepare('DELETE FROM band_bars WHERE room = ?').bind(this.s.room).run(); } catch { /* table may not exist yet locally */ }
      await this.ctx.storage.deleteAlarm();
      await this.ctx.storage.setAlarm(this.deadlineOf(-1)); // startMs − barMs
      await this.persist();
      return ok({
        ok: true, room: this.s.room, tempo, barMs: barMsV,
        startMs: this.s.startMs, prerollBars, serverNow: this.s.openedAt,
        tickRule: 'tick N fires at startMs + N*barMs and freezes bar N+1',
      });
    }

    // ---- POST /band/commit — voice intent for a bar, deadline-checked ----
    if (path === '/commit' && request.method === 'POST') {
      let body: { voice?: string; bar?: number; events?: unknown };
      try { body = await request.json(); } catch { return ok({ error: 'invalid json' }, 400); }
      const voice = String(body.voice ?? '');
      const bar = Number(body.bar);
      if (!VOICE_NAMES.includes(voice)) return ok({ error: `unknown voice: ${voice}` }, 400);
      if (!Number.isInteger(bar) || bar < 0) return ok({ error: 'bar must be a non-negative integer' }, 400);
      const checked = validateEvents(body.events);
      if (!checked.ok) return ok({ error: `validation rail rejected: ${checked.reason}` }, 400);

      const stat = this.s.commits[voice] ?? (this.s.commits[voice] = { accepted: 0, late: 0, leadSumMs: 0, leadMinMs: Infinity, leadMaxMs: 0, leadN: 0 });
      if (!this.s.playing) return ok({ ok: false, reason: 'room not playing' });
      // bar B froze at tick B−1: frozen iff B−1 < nextTick, i.e. B ≤ nextTick
      if (bar <= this.s.nextTick) {
        stat.late += 1;
        return ok({ ok: false, late: true, bar, voice, reason: `bar ${bar} already froze (past tick ${this.s.nextTick - 1})`, nowPastTick: this.s.nextTick - 1 });
      }
      if (bar > this.s.nextTick + HORIZON) {
        return ok({ ok: false, reason: `too far ahead: bar ${bar} beyond horizon ${HORIZON} (next tick ${this.s.nextTick})` });
      }

      const now = Date.now();
      const deadlineMs = this.deadlineOf(bar - 1); // freeze deadline for this bar
      this.s.pending[`${bar}:${voice}`] = { events: checked.events, committedAt: now };
      stat.accepted += 1;
      const leadMs = deadlineMs - now;
      stat.leadSumMs += leadMs; stat.leadN += 1;
      stat.leadMinMs = stat.leadN === 1 ? leadMs : Math.min(stat.leadMinMs, leadMs);
      stat.leadMaxMs = Math.max(stat.leadMaxMs, leadMs);

      try {
        await this.env.DB.prepare(
          `INSERT INTO band_bars (room, bar, voice, events_json, status, kind, committed_at, deadline_at, frozen_at)
           VALUES (?, ?, ?, ?, 'pending', NULL, ?, ?, NULL)
           ON CONFLICT (room, bar, voice) DO UPDATE SET
             events_json = excluded.events_json, committed_at = excluded.committed_at`,
        ).bind(this.s.room, bar, voice, JSON.stringify(checked.events), now, deadlineMs).run();
      } catch (e) { console.error('pending D1 insert failed', e); }

      return ok({ ok: true, bar, voice, leadMs, freezeDeadlineMs: deadlineMs });
    }

    // ---- GET /band/state — light snapshot -------------------------------
    if (path === '/state' && request.method === 'GET') {
      const pendingByVoice: Record<string, number> = {};
      for (const k of Object.keys(this.s.pending)) {
        const v = k.split(':')[1];
        pendingByVoice[v] = (pendingByVoice[v] ?? 0) + 1;
      }
      return ok({
        room: this.s.room, playing: this.s.playing, tempo: this.s.tempo, barMs: this.s.barMs,
        startMs: this.s.startMs, tickCount: this.s.tickCount, frozenBars: this.s.frozenBars,
        nextTick: this.s.nextTick, nowMs: Date.now(),
        misses: this.s.misses, pendingByVoice,
        lastTickJitterMs: this.s.lastTickJitterMs,
      });
    }

    // ---- GET /band/stats — the soak's evidence --------------------------
    if (path === '/stats' && request.method === 'GET') {
      return ok({
        room: this.s.room, playing: this.s.playing, tempo: this.s.tempo,
        tickCount: this.s.tickCount, frozenBars: this.s.frozenBars,
        summary: summarizeJitter(this.s.jitter),
        recent: this.s.jitter.slice(-200),
        misses: this.s.misses,
        commits: this.s.commits,
      });
    }

    // ---- POST /band/stop — end the tune, persist the report -------------
    if (path === '/stop' && request.method === 'POST') {
      this.s.playing = false;
      await this.ctx.storage.deleteAlarm();
      await this.persist();
      const summary = summarizeJitter(this.s.jitter);
      const report = {
        room: this.s.room, tempo: this.s.tempo, barMs: this.s.barMs,
        openedAt: this.s.openedAt, stoppedAt: Date.now(),
        ticks: this.s.tickCount, frozenBars: this.s.frozenBars,
        summary, misses: this.s.misses, commits: this.s.commits,
        samples: this.s.jitter,
      };
      try {
        await this.env.DB.prepare(
          `INSERT INTO band_soaks (room, started_at, ended_at, tempo, bar_ms, bars, stats_json, summary_json, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        ).bind(this.s.room, this.s.openedAt, report.stoppedAt, this.s.tempo, this.s.barMs,
          this.s.frozenBars, JSON.stringify(this.s.jitter), JSON.stringify(summary), Date.now()).run();
      } catch (e) { console.error('soak report D1 insert failed', e); }
      this.broadcast({ type: 'bandstop', room: this.s.room, summary });
      return ok(report);
    }

    // ---- GET /band/bars — frozen take from D1 (render proof input) ------
    if (path === '/bars' && request.method === 'GET') {
      const rows = await this.env.DB.prepare(
        `SELECT bar, voice, events_json, kind, committed_at, deadline_at, frozen_at
         FROM band_bars WHERE room = ? AND status = 'frozen' ORDER BY bar ASC, voice ASC`,
      ).bind(this.s.room).all();
      const bars = (rows.results as any[]).map(r => {
        let events: BarEvent[] = [];
        try { events = JSON.parse(r.events_json ?? '[]'); } catch { /* keep [] */ }
        return { bar: r.bar, voice: r.voice, kind: r.kind, events, committed_at: r.committed_at, deadline_at: r.deadline_at, frozen_at: r.frozen_at };
      });
      return ok({ room: this.s.room, tempo: this.s.tempo, count: bars.length, bars });
    }

    // ---- GET /band/ws — bandtick frames ---------------------------------
    if (path === '/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') return ok({ error: 'expected websocket' }, 400);
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      this.ctx.acceptWebSocket(server as WebSocket);
      this.wsClients.add(server as WebSocket);
      (server as WebSocket).send(JSON.stringify({
        type: 'snapshot', room: this.s.room, playing: this.s.playing,
        tempo: this.s.tempo, startMs: this.s.startMs, tickCount: this.s.tickCount,
      }));
      return new Response(null, { status: 101, webSocket: client });
    }

    return ok({ error: 'not found', path }, 404);
  }

  webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): void {
    try {
      const msg = typeof message === 'string' ? JSON.parse(message) : {};
      if (msg.type === 'ping') ws.send(JSON.stringify({ type: 'pong', tickCount: this.s.tickCount }));
    } catch { /* ignore */ }
  }
  webSocketClose(ws: WebSocket): void { this.wsClients.delete(ws); }
  webSocketError(ws: WebSocket): void { this.wsClients.delete(ws); }
}
