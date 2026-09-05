// scrap-quilt — YardRoom Durable Object.
// The live heart, pattern-proven by mist-quilt's GameRoom: ingests ticks from
// the game (≤2/sec), evaluates formula cells (the quilt cascade), keeps the
// in-memory tape, checkpoints to D1, broadcasts to WebSocket subscribers,
// detects laps from position crossing around the oval, records real-board
// flashes, and answers /predict with an honest forward-sim.

import {
  CELLS, CELL_IDS, LIVE_CELLS, EDGES, evalFormulas, angleAroundTrack,
  type CellValue, type TickCell,
} from './sheet';
import { predictAhead } from './predict';
import { DurableObject } from 'cloudflare:workers';

export interface Env {
  DB: D1Database;
}

interface TapePoint { t: number; v: CellValue; }

const TAPE_MAX = 480;              // in-memory ticks (~4 min at 2 Hz)
const CHECKPOINT_EVERY_TICKS = 10; // ~5 s → D1
const SHEET = 'scrap';

interface TickRow { sheet_id: string; cell_id: string; old_value: string; new_value: string; t: number; author: string; created_at: number; }

const DEFAULTS: Record<string, CellValue> = {
  'player.x': 0, 'player.z': 0,
  'player.biome': 'heaps', 'player.scrap': 0, 'player.inventoryCount': 0,
  'robot.x': 0, 'robot.z': 0,
  'robot.batteryV': 8.4, 'robot.dutyL': 0, 'robot.dutyR': 0,
  'robot.drivePower': 0, 'robot.turnPower': 0,
  'robot.heading': 0, 'robot.sensor.ultrasonic': 6, 'robot.sensor.ir': 0,
  'robot.sensor.encoder': 0, 'robot.gripper': 'open',
  'program.currentTile': '—', 'program.state': 'idle', 'program.length': 1, 'program.ip': 0, 'program.loopDepth': 0, 'program.tilesRun': 0,
  'race.lap': 0, 'race.splitMs': 0, 'race.bestLapMs': 0, 'race.position': 1,
  'build.partsCount': 0, 'build.chassisIntegrity': 100, 'build.maxIntegrity': 100, 'build.motorTier': 1,
  'spark.lastQuestion': '—', 'spark.cacheHit': false, 'spark.lastTookMs': 0, 'spark.hits': 0, 'spark.misses': 0,
  'flash.hexHash': '—', 'flash.board': '—', 'flash.size': 0, 'flash.at': '—', 'flash.count': 0,
};

export class YardRoom extends DurableObject<Env> {
  private values: Record<string, CellValue> = {};
  private lamport = 0;
  private tickCount = 0;
  private lastWallMs = 0;
  private tape = new Map<string, TapePoint[]>();      // cellId → newest-last
  private wsClients = new Set<WebSocket>();
  private loaded = false;
  // lap detection state (position crossing)
  private prevLapFrac = 0;
  private lapStartWall = 0;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
  }

  // ------------------------------------------------------------------ load
  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    this.loaded = true;
    try {
      const rows = await this.env.DB.prepare('SELECT id, value, t FROM cells WHERE sheet_id = ?').bind(SHEET).all();
      for (const row of rows.results as any[]) {
        try { this.values[row.id] = JSON.parse(row.value); } catch { /* skip */ }
        this.lamport = Math.max(this.lamport, row.t ?? 0);
      }
      const snap = await this.ctx.storage.get<{ values: Record<string, CellValue>; lamport: number; tickCount: number; wallMs: number; prevLapFrac: number; lapStartWall: number }>('snapshot');
      if (snap && snap.lamport >= this.lamport) {
        this.values = snap.values;
        this.lamport = snap.lamport;
        this.tickCount = snap.tickCount;
        this.lastWallMs = snap.wallMs;
        this.prevLapFrac = snap.prevLapFrac ?? 0;
        this.lapStartWall = snap.lapStartWall ?? 0;
      }
      const stored = await this.ctx.storage.get<TapePoint[]>(LIVE_CELLS.map(id => `tape:${id}`));
      for (const [key, pts] of stored) this.tape.set(key.slice(5), (pts ?? []).slice(-TAPE_MAX));
      // seed defaults for anything missing so /state renders before first tick
      for (const [id, v] of Object.entries(DEFAULTS)) if (this.values[id] === undefined) this.values[id] = v;
      this.values = evalFormulas(this.values);
      if (this.lapStartWall === 0) this.lapStartWall = Date.now();
      if (typeof this.values['robot.x'] === 'number' && typeof this.values['robot.z'] === 'number') {
        this.prevLapFrac = angleAroundTrack(this.values['robot.x'] as number, this.values['robot.z'] as number);
      }
    } catch (e) {
      console.error('YardRoom load failed', e);
      for (const [id, v] of Object.entries(DEFAULTS)) if (this.values[id] === undefined) this.values[id] = v;
      this.values = evalFormulas(this.values);
    }
  }

  private async persistToStorage(): Promise<void> {
    const data: Record<string, unknown> = {
      snapshot: {
        values: this.values, lamport: this.lamport, tickCount: this.tickCount,
        wallMs: this.lastWallMs, prevLapFrac: this.prevLapFrac, lapStartWall: this.lapStartWall,
      },
    };
    for (const id of LIVE_CELLS) {
      const pts = this.tape.get(id);
      if (pts?.length) data[`tape:${id}`] = pts.slice(-TAPE_MAX);
    }
    try { await this.ctx.storage.put(data); } catch (e) { console.error('storage persist failed', e); }
  }

  private pushTape(id: string, t: number, v: CellValue): void {
    if (!LIVE_CELLS.includes(id)) return;
    const arr = this.tape.get(id) ?? [];
    arr.push({ t, v });
    if (arr.length > TAPE_MAX) arr.splice(0, arr.length - TAPE_MAX);
    this.tape.set(id, arr);
  }

  private broadcast(msg: unknown): void {
    const data = JSON.stringify(msg);
    for (const ws of this.wsClients) {
      try {
        if (ws.readyState === WebSocket.READY_STATE_OPEN) ws.send(data);
        else if (ws.readyState >= WebSocket.READY_STATE_CLOSED) this.wsClients.delete(ws);
      } catch { this.wsClients.delete(ws); }
    }
  }

  private snapshotCells(): Record<string, TickCell> {
    const out: Record<string, TickCell> = {};
    for (const id of CELL_IDS) out[id] = { v: this.values[id], t: this.lamport, ch: false };
    return out;
  }

  private async checkpoint(historyRows: TickRow[]): Promise<void> {
    const now = Date.now();
    const stmts: D1PreparedStatement[] = [];
    for (const id of CELL_IDS) {
      if (this.values[id] === undefined) continue;
      stmts.push(
        this.env.DB.prepare(
          `INSERT INTO cells (sheet_id, id, kind, value, value_type, t, author, created_at, updated_at, metadata)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT (sheet_id, id) DO UPDATE SET value = excluded.value, value_type = excluded.value_type,
             t = excluded.t, author = excluded.author, updated_at = excluded.updated_at`,
        ).bind(SHEET, id, CELLS.find(c => c.id === id)?.kind ?? 'value', JSON.stringify(this.values[id]), typeof this.values[id], this.lamport, 'game', now, now, '{}'),
      );
    }
    for (const r of historyRows) {
      stmts.push(
        this.env.DB.prepare(
          `INSERT INTO history (sheet_id, cell_id, old_value, new_value, t, author, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        ).bind(r.sheet_id, r.cell_id, r.old_value, r.new_value, r.t, r.author, r.created_at),
      );
    }
    stmts.push(
      this.env.DB.prepare(
        `INSERT INTO sheet_meta (sheet_id, t, tick_count, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT (sheet_id) DO UPDATE SET t = excluded.t, tick_count = excluded.tick_count, updated_at = excluded.updated_at`,
      ).bind(SHEET, this.lamport, this.tickCount, now),
    );
    try { await this.env.DB.batch(stmts); } catch (e) { console.error('checkpoint failed', e); }
  }

  // Apply a batch of cell updates through the cascade; returns per-cell
  // results, pushes tape, collects history rows, and broadcasts.
  private applyCells(incoming: Record<string, CellValue>, author: string): { result: Record<string, TickCell>; historyRows: TickRow[] } {
    this.lamport += 1;
    this.tickCount += 1;
    this.lastWallMs = Date.now();

    const out = evalFormulas({ ...this.values, ...incoming });
    const result: Record<string, TickCell> = {};
    const historyRows: TickRow[] = [];

    for (const id of CELL_IDS) {
      const prev = this.values[id];
      const next = out[id];
      const changed = !Object.is(prev, next) && JSON.stringify(prev) !== JSON.stringify(next);
      result[id] = { v: next, t: this.lamport, ch: changed };
      if (changed) {
        this.pushTape(id, this.lamport, next);
        if (LIVE_CELLS.includes(id)) {
          historyRows.push({ sheet_id: SHEET, cell_id: id, old_value: JSON.stringify(prev ?? null), new_value: JSON.stringify(next), t: this.lamport, author, created_at: this.lastWallMs });
        }
      }
    }
    this.values = out;
    return { result, historyRows };
  }

  // ------------------------------------------------------------------ fetch
  async fetch(request: Request): Promise<Response> {
    await this.ensureLoaded();
    const url = new URL(request.url);
    const CORS = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });

    // ---- POST /tick ----
    if (url.pathname === '/tick' && request.method === 'POST') {
      let body: { cells?: Record<string, CellValue> };
      try { body = await request.json(); } catch { return Response.json({ error: 'invalid json' }, { status: 400, headers: CORS }); }
      const incoming = body.cells ?? {};

      // ── LAP DETECTION: position crossing around the oval ──
      // If the game posts fresh robot.x/robot.z, compute the new lap fraction
      // and detect the 1→0 wrap while moving. The yard itself is the referee.
      const px = incoming['robot.x'], pz = incoming['robot.z'];
      let lapEvents: string[] = [];
      if (typeof px === 'number' && typeof pz === 'number') {
        const frac = angleAroundTrack(px, pz);
        const speed = (typeof incoming['robot.drivePower'] === 'number' ? incoming['robot.drivePower'] : (this.values['robot.drivePower'] as number) ?? 0);
        if (this.prevLapFrac > 0.9 && frac < 0.1 && speed > 0.05) {
          const now = Date.now();
          const split = this.lapStartWall > 0 ? now - this.lapStartWall : 0;
          const lap = ((this.values['race.lap'] as number) ?? 0) + 1;
          const priorBest = (this.values['race.bestLapMs'] as number) ?? 0;
          const best = priorBest > 0 ? Math.min(priorBest, split) : split;
          incoming['race.lap'] = lap;
          incoming['race.splitMs'] = split;
          incoming['race.bestLapMs'] = best;
          this.lapStartWall = now;
          lapEvents = [`lap ${lap}`, `${split} ms`];
        }
        this.prevLapFrac = frac;
      }

      const { result, historyRows } = this.applyCells(incoming, 'game');
      this.broadcast({ type: 'tick', t: this.lamport, cells: result, events: lapEvents });

      if (this.tickCount % 2 === 0) await this.persistToStorage();
      if (this.tickCount % CHECKPOINT_EVERY_TICKS === 0) await this.checkpoint(historyRows);
      else if (historyRows.length) this.pendingRows.push(...historyRows);
      if (this.pendingRows.length > 400) await this.checkpoint(this.pendingRows.splice(0, this.pendingRows.length));

      return Response.json({ ok: true, t: this.lamport, tickCount: this.tickCount, lapEvents, cells: result }, { headers: CORS });
    }

    // ---- GET /state ----
    if (url.pathname === '/state' && request.method === 'GET') {
      return Response.json({
        sheetId: SHEET, t: this.lamport, tickCount: this.tickCount, wallMs: this.lastWallMs,
        cells: this.snapshotCells(),
      }, { headers: CORS });
    }

    // ---- GET /history ----
    if (url.pathname === '/history' && request.method === 'GET') {
      const cellsParam = url.searchParams.get('cells');
      const limit = Math.min(Math.max(parseInt(url.searchParams.get('limit') ?? '120', 10) || 120, 10), TAPE_MAX);
      const ids = cellsParam ? cellsParam.split(',').filter(c => LIVE_CELLS.includes(c)) : LIVE_CELLS;
      const points: Record<string, TapePoint[]> = {};
      for (const id of ids) points[id] = (this.tape.get(id) ?? []).slice(-limit);
      const oldestT = Math.min(...ids.map(id => this.tape.get(id)?.[0]?.t ?? Infinity), Infinity);
      if (!Number.isFinite(oldestT) || oldestT > this.lamport - limit) {
        try {
          const from = this.lamport - limit - 1;
          const placeholders = ids.map(() => '?').join(',');
          const rows = await this.env.DB.prepare(
            `SELECT cell_id, new_value, t FROM history WHERE sheet_id = ? AND t > ? AND cell_id IN (${placeholders}) ORDER BY t ASC`,
          ).bind(SHEET, from, ...ids).all();
          for (const row of rows.results as any[]) {
            let v: CellValue; try { v = JSON.parse(row.new_value); } catch { v = row.new_value; }
            const arr = points[row.cell_id] ?? [];
            if (!arr.some(p => p.t === row.t)) arr.push({ t: row.t, v });
            points[row.cell_id] = arr;
          }
        } catch (e) { console.error('history D1 fallback failed', e); }
      }
      for (const id of ids) (points[id] ??= []).sort((a, b) => a.t - b.t);
      // aligned t axis (union) + forward-fill → DAW/sparkline contract
      const tSet = new Set<number>();
      for (const arr of Object.values(points)) for (const p of arr) tSet.add(p.t);
      const ts = [...tSet].sort((a, b) => a - b).slice(-limit);
      const series: Record<string, CellValue[]> = {};
      for (const id of ids) {
        const cols: CellValue[] = [];
        let cursor = 0;
        const pts = points[id] ?? [];
        let last: CellValue | null = null;
        for (const t of ts) {
          while (cursor < pts.length && pts[cursor].t <= t) { last = pts[cursor].v; cursor++; }
          cols.push(last as CellValue);
        }
        series[id] = cols;
      }
      return Response.json({ t: ts, series }, { headers: CORS });
    }

    // ---- POST /predict ----
    if (url.pathname === '/predict' && request.method === 'POST') {
      let body: { ticks?: number } = {};
      try { body = await request.json(); } catch { /* default */ }
      const ticks = Math.min(Math.max(body.ticks ?? 10, 5), 60);
      const ghosts = predictAhead(this.values, this.tape, ticks);
      return Response.json({ base_t: this.lamport, dt_ms: 500, ghosts }, { headers: CORS });
    }

    // ---- POST /flash-log — the hardware bridge becomes part of the sheet ----
    if (url.pathname === '/flash-log' && request.method === 'POST') {
      let body: { hexHash?: string; board?: string; size?: number; source?: string };
      try { body = await request.json(); } catch { return Response.json({ error: 'invalid json' }, { status: 400, headers: CORS }); }
      const hexHash = String(body.hexHash ?? '').trim();
      const board = String(body.board ?? '').trim();
      if (!hexHash || !board) return Response.json({ error: 'hexHash and board are required' }, { status: 400, headers: CORS });

      const now = Date.now();
      const count = ((this.values['flash.count'] as number) ?? 0) + 1;
      const incoming: Record<string, CellValue> = {
        'flash.hexHash': hexHash.slice(0, 64),
        'flash.board': board.slice(0, 32),
        'flash.size': Number(body.size ?? 0) | 0,
        'flash.at': new Date(now).toISOString(),
        'flash.count': count,
      };
      const { result, historyRows } = this.applyCells(incoming, 'flash');
      this.broadcast({ type: 'flash', t: this.lamport, cells: result });
      // the tapestry record: one durable row per real-board flash
      const flashRow = this.env.DB.prepare(
        `INSERT INTO flash_log (sheet_id, hex_hash, board, size, source, t, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ).bind(SHEET, hexHash.slice(0, 64), board.slice(0, 32), Number(body.size ?? 0) | 0, String(body.source ?? 'webserial').slice(0, 32), this.lamport, now);
      await Promise.all([this.persistToStorage(), this.checkpoint(historyRows), flashRow.run().catch(() => {})]);
      return Response.json({ ok: true, t: this.lamport, flashCount: count, cells: result }, { headers: CORS });
    }

    // ---- GET /flash-log — the tapestry record ----
    if (url.pathname === '/flash-log' && request.method === 'GET') {
      const rows = await this.env.DB.prepare(
        'SELECT hex_hash, board, size, source, t, created_at FROM flash_log WHERE sheet_id = ? ORDER BY created_at DESC LIMIT 50',
      ).bind(SHEET).all();
      return Response.json({
        count: this.values['flash.count'] ?? 0,
        cells: {
          'flash.hexHash': this.values['flash.hexHash'],
          'flash.board': this.values['flash.board'],
          'flash.size': this.values['flash.size'],
          'flash.at': this.values['flash.at'],
        },
        flashes: rows.results,
      }, { headers: CORS });
    }

    // ---- GET /ws ----
    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') {
        return Response.json({ error: 'expected websocket' }, { status: 400, headers: CORS });
      }
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      this.ctx.acceptWebSocket(server as WebSocket);
      this.wsClients.add(server as WebSocket);
      (server as WebSocket).send(JSON.stringify({
        type: 'snapshot', t: this.lamport, tickCount: this.tickCount, cells: this.snapshotCells(),
      }));
      return new Response(null, { status: 101, webSocket: client });
    }

    return Response.json({ error: 'not found', path: url.pathname }, { status: 404, headers: CORS });
  }

  private pendingRows: TickRow[] = [];

  webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): void {
    try {
      const msg = typeof message === 'string' ? JSON.parse(message) : {};
      if (msg.type === 'ping') ws.send(JSON.stringify({ type: 'pong', t: this.lamport }));
    } catch { /* ignore */ }
  }

  webSocketClose(ws: WebSocket): void { this.wsClients.delete(ws); }
  webSocketError(ws: WebSocket): void { this.wsClients.delete(ws); }
}

// Re-export edges for /state layout consumers.
export { EDGES };
