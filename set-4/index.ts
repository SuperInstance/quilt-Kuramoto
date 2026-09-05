// scrap-quilt — Scrapcraft's quilt backend on Workers.
// The whole game as a live sheet of cells: D1 (cells + history tape + flash
// log + chat ledger), Durable Object YardRoom for live ticks over WebSocket,
// pincher-cached /chat (Spark), /predict ghost states with real kinematics.
// See README.md for the full endpoint contract.

import { cellMeta, groups, FEEDS, EDGES } from './sheet';
import { YardRoom, type Env as RoomEnv } from './room';
import { BandRoom, type Env as BandEnv } from './band-room';
import { handleSparkChat, CHAT_MODEL, type ChatEnv } from './chat';
import { REFLEXES, runReflex, serializeForEsp32, type SensorSnapshot } from './reflex';
import { MODELS } from './router';
import {
  getIndexedChunks, retrieve, embedBatch, EMBED_MODEL,
  loreSystemPrompt, buildLorePrompt, citationsFor, parseCitations,
} from './lore';
import { evolve } from './evolve';

export interface Env extends RoomEnv, ChatEnv, BandEnv {
  ROOM: DurableObjectNamespace<YardRoom>;
  BAND: DurableObjectNamespace<BandRoom>;
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), { status, headers: { 'Content-Type': 'application/json', ...CORS } });
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });

    const room = () => env.ROOM.get(env.ROOM.idFromName('yard'));

    try {
      // ---- game → sheet (DO passthroughs) -------------------------------
      if (url.pathname === '/tick' && request.method === 'POST') return room().fetch(request);
      if (url.pathname === '/flash-log') return room().fetch(request);

      // ---- live views ----------------------------------------------------
      if (url.pathname === '/state' && request.method === 'GET') return room().fetch(request);
      if (url.pathname === '/history' && request.method === 'GET') return room().fetch(request);
      if (url.pathname === '/ws') return room().fetch(request);
      if (url.pathname === '/predict' && request.method === 'POST') return room().fetch(request);

      if (url.pathname === '/dashboard' && request.method === 'GET') {
        const cells = url.searchParams.get('cells') ?? '';
        const limit = url.searchParams.get('limit') ?? '60';
        const target = new URL(request.url);
        target.pathname = '/history';
        target.searchParams.set('cells', cells);
        target.searchParams.set('limit', limit);
        const res = await room().fetch(new Request(target.toString()));
        const data = await res.json<{ t: number[]; series: Record<string, unknown[]> }>();
        const ts = data.t ?? [];
        const series: Record<string, Array<{ t: number; v: unknown }>> = {};
        for (const [id, vals] of Object.entries(data.series ?? {})) {
          series[id] = (vals ?? []).map((v, i) => ({ t: ts[i], v })).filter(p => p.v !== null && p.v !== undefined);
        }
        return json({ series });
      }

      // ---- Spark, the explainer, through THIS worker ----------------------
      // (AI seam lives in chat.ts → runModel(); delegate to scrap-spark there
      // when that lane ships. The cell-context injection is here to stay.)
      if ((url.pathname === '/chat' || url.pathname === '/ask') && request.method === 'POST') {
        let body: { question?: string };
        try { body = await request.json(); } catch { return json({ error: 'invalid json body' }, 400); }
        const question = String(body.question ?? '').trim();
        if (!question) return json({ error: 'question is required' }, 400);
        if (question.length > 400) return json({ error: 'question too long (max 400 chars)' }, 400);

        const stateUrl = new URL(request.url); stateUrl.pathname = '/state';
        const histUrl = new URL(request.url); histUrl.pathname = '/history';
        histUrl.searchParams.set('limit', '12');
        const [stateRes, histRes] = await Promise.all([
          room().fetch(new Request(stateUrl.toString())),
          room().fetch(new Request(histUrl.toString())),
        ]);
        const sheetState = await stateRes.json<{ t: number; cells: Record<string, { v: unknown }> }>();
        const history = await histRes.json<{ t: number[]; series: Record<string, unknown[]> }>();

        const result = await handleSparkChat(env, question, sheetState, history);

        // fold spark.* cell updates back through the cascade + broadcast
        const hits = Number(sheetState.cells?.['spark.hits']?.v ?? 0) || 0;
        const misses = Number(sheetState.cells?.['spark.misses']?.v ?? 0) || 0;
        const tickUrl = new URL(request.url); tickUrl.pathname = '/tick';
        await room().fetch(new Request(tickUrl.toString(), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            cells: {
              ...result.cells,
              'spark.hits': result.cached ? hits + 1 : hits,
              'spark.misses': result.cached ? misses : misses + 1,
            },
          }),
        })).catch(() => {});

        return json(result);
      }

      if (url.pathname === '/chat/stats' && request.method === 'GET') {
        const res = await env.DB.prepare(
          'SELECT COUNT(*) AS entries, SUM(hits) AS hits FROM chat_ledger',
        ).first();
        const recent = await env.DB.prepare(
          'SELECT substr(question,1,80) AS question, substr(answer,1,120) AS answer, hits, model, created_at FROM chat_ledger ORDER BY created_at DESC LIMIT 10',
        ).all();
        return json({ doctrine: 'model-call heavy at first, then more and more canned responses', totals: res, recent: recent.results });
      }

      // (/ask is the same handler — same contract, router lane in the result)

      // ---- /reflex(es) — pincher-pattern robot reflexes, no LLM per tick --
      if (url.pathname === '/reflex' && request.method === 'POST') {
        let body: { sensorSnapshot?: SensorSnapshot };
        try { body = await request.json(); } catch { return json({ error: 'invalid json body' }, 400); }
        const t0 = Date.now();
        const result = runReflex(body.sensorSnapshot ?? {});
        result.ms = Date.now() - t0;
        return json(result);
      }
      if (url.pathname === '/reflexes' && request.method === 'GET') {
        return json({
          count: REFLEXES.length,
          reflexes: REFLEXES.map(r => ({ id: r.id, kind: r.kind, intent: r.intent, proto: r.proto })),
          esp32: serializeForEsp32(),
          doctrine: 'vector-matched reflex cells, sub-50ms, no LLM per tick (quilt-pincher FAST tier)',
        });
      }
      if (url.pathname === '/reflexes/esp32' && request.method === 'GET') {
        return new Response(JSON.stringify(serializeForEsp32(), null, 2), { headers: { 'Content-Type': 'application/json', ...CORS } });
      }

      // ---- /lore — RAG over the world bible (quilt-rag cell pattern) -------
      if (url.pathname === '/lore' && request.method === 'POST') {
        let body: { question?: string };
        try { body = await request.json(); } catch { return json({ error: 'invalid json body' }, 400); }
        const question = String(body.question ?? '').trim();
        if (!question) return json({ error: 'question is required' }, 400);

        const t0 = Date.now();
        const chunks = await getIndexedChunks(env.INDEX, env.AI);
        const [qvec] = await embedBatch(env.AI, [question]);
        const hits = retrieve(qvec, chunks, 4);
        let answer = '';
        try {
          const res: any = await env.AI.run(CHAT_MODEL as never, {
            messages: [
              { role: 'system', content: loreSystemPrompt() },
              { role: 'user', content: buildLorePrompt(question, hits) },
            ],
            max_tokens: 2000,
          } as never);
          const msg = res?.choices?.[0]?.message ?? {};
          answer = (msg?.content ?? res?.response ?? '').trim();
        } catch (e) { return json({ error: `lore model failed: ${(e as Error).message}` }, 500); }

        return json({
          answer,
          citations: citationsFor(hits, qvec),
          used: parseCitations(answer),
          embed_model: EMBED_MODEL,
          took_ms: Date.now() - t0,
        });
      }
      if (url.pathname === '/lore/index' && request.method === 'GET') {
        const chunks = await getIndexedChunks(env.INDEX, env.AI);
        return json({ chunks: chunks.length, files: [...new Set(chunks.map(c => c.file))], embed_model: EMBED_MODEL });
      }

      // ---- /ghost/evolve — quilt-evolve loop at ghost-racer scope ----------
      if (url.pathname === '/ghost/evolve' && request.method === 'POST') {
        let body: { generations?: number; seed?: number };
        try { body = await request.json(); } catch { body = {}; }
        const generations = Math.min(Math.max(body.generations ?? 3, 1), 20);

        // seed from the D1 tape (past race runs) if the yard has raced
        let seedRuns: Array<{ lapMs?: number; ticks?: number }> | null = null;
        try {
          const rows = await env.DB.prepare(
            `SELECT new_value FROM history WHERE sheet_id = 'scrap' AND cell_id = 'race.splitMs' ORDER BY t DESC LIMIT 10`,
          ).all();
          if (rows.results.length >= 3) seedRuns = rows.results.map(r => ({ lapMs: Number(JSON.parse(String(r.new_value))) || 0 }));
        } catch { /* tape empty → synthetic seed */ }

        const t0 = Date.now();
        const report = evolve(seedRuns, generations, 8, body.seed ?? 42);
        await env.INDEX.put('ghost:pool', JSON.stringify({
          at: Date.now(), seededFrom: report.seededFrom,
          pool: report.finalPool.map(r => ({ ...r.genome, lapMs: r.lapMs, crashes: r.crashes })),
        }));
        return json({
          generations: report.generations.map(g => ({
            gen: g.gen, bestLapMs: g.spread.lapMs, bestCrashes: g.spread.crashes,
            meanLapMs: g.meanLapMs, medianFitness: g.median, champion: g.best.genome,
          })),
          improvedPct: report.improvedPct,
          seededFrom: report.seededFrom,
          took_ms: Date.now() - t0,
        });
      }
      if (url.pathname === '/ghost/pool' && request.method === 'GET') {
        const pool = await env.INDEX.get('ghost:pool', 'json');
        return json(pool ?? { pool: [], note: 'run POST /ghost/evolve first' });
      }

      if (url.pathname === '/ask/routes' && request.method === 'GET') {
        return json({ lanes: MODELS, doctrine: 'cheap for casual, strong for code help — quilt-ai router' });
      }

      // ---- meta ------------------------------------------------------------
      // ---- yard-band skeleton: the bar-clock room (BandRoom DO) ----------
      // Additive: /band/* only. YardRoom, cells, tape — untouched.
      if (url.pathname.startsWith('/band/') || url.pathname === '/band') {
        const roomName = url.searchParams.get('room') ?? 'yard';
        return env.BAND.get(env.BAND.idFromName(roomName)).fetch(request);
      }

      if (url.pathname === '/health') return json({ ok: true, service: 'scrap-quilt' });

      if ((url.pathname === '/' || url.pathname === '') && request.method === 'GET') {
        return json({
          service: 'scrap-quilt',
          tagline: 'the yard IS the sheet — Scrapcraft\'s whole game state as live quilt cells',
          sheet: 'scrap',
          layout: cellMeta().map(c => ({ ...c, feeds: FEEDS[c.id] ?? [] })),
          groups: groups(),
          edges: EDGES,
          chat_model: CHAT_MODEL,
          endpoints: {
            'POST /tick': 'game → sheet: {cells:{id:value}} (≤2/sec) → cascade + WS broadcast + tape',
            'GET /state': 'full live snapshot',
            'GET /ws': 'WebSocket: snapshot on join, then tick deltas',
            'GET /history?cells=&limit=': 'aligned tape (DAW + sparklines)',
            'GET /dashboard?cells=&limit=': 'sparkline series',
            'POST /predict': '{ticks:5..60} → ghost states (real-kinematics forward sim)',
            'POST /chat': '{question} → Spark, pincher-cached (cached flag)',
            'POST /ask': 'same as /chat with the quilt-ai router lane visible',
            'GET /ask/routes': 'the two model lanes (cheap/strong)',
            'POST /reflex': '{sensorSnapshot} → {reflex, action, ms} — vector-matched reflex cells (quilt-pincher)',
            'GET /reflexes': 'reflex DB + .nail ESP32 bundle (quilt-esp32 flash path)',
            'POST /lore': '{question} → grounded answer with [file:lines] citations (quilt-rag)',
            'GET /lore/index': 'corpus stats',
            'POST /ghost/evolve': '{generations:N} → evolution report; winners replace the ghost pool (quilt-evolve)',
            'GET /ghost/pool': 'the evolved ghost pool',
            'GET /chat/stats': 'pincher ledger',
            'POST /flash-log': '{hexHash,board,size,source} — real-board flash becomes quilt cells',
            'GET /flash-log': 'the tapestry record — last 50 flashes',
            'POST /band/open': '{tempo,prerollBars,room} — start the bar clock (self-rescheduling DO alarm)',
            'POST /band/commit': '{voice,bar,events} — voice intent for a bar, accepted until freeze',
            'GET /band/state': 'clock + counters snapshot (?room=)',
            'GET /band/stats': 'fire-jitter samples + summary — the soak evidence',
            'POST /band/stop': 'stop the clock, persist the soak report',
            'GET /band/bars': 'frozen take from D1 (render proof input)',
            'GET /band/ws': 'bandtick frames',
          },
        });
      }

      return json({ error: 'not found', path: url.pathname }, 404);
    } catch (e) {
      return json({ error: (e as Error).message }, 500);
    }
  },
};

export { YardRoom };
export { BandRoom };
