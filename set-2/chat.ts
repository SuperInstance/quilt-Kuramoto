// scrap-quilt — /chat: Spark, the scrapyard mentor, through the quilt.
//
// Pincher-cached doctrine (mist-quilt / mist-voice): "model-call heavy at
// first, then more and more canned responses." Cache key = SHA-256 of the
// normalized question + a quantized digest of the live Yard Sheet — same
// question in a similar robot state answers instantly.
//
// SEAM: runModel() is the single AI entry point. When the scrap-spark lane
// ships its own explainer, swap that one function for a fetch to scrap-spark
// and keep everything else (context injection, cache, ledger, cell updates).

import type { CellValue } from './sheet';
import { routeQuestion } from './router';

export interface ChatEnv {
  AI: Ai;
  INDEX: KVNamespace;
  DB: D1Database;
}

export const CHAT_MODEL = '@cf/deepseek-ai/deepseek-v4-flash-0731'; // cheap lane (proven on this account)
export const STRONG_MODEL = '@cf/zai-org/glm-5.2';                 // strong lane (quilt-ai router)
const KV_TTL = 60 * 60 * 6; // 6 h — robot states evolve; don't serve stale forever

function normalize(text: string): string {
  return text.replace(/\s+/g, ' ').trim().toLowerCase();
}

async function sha256(parts: string[]): Promise<string> {
  const enc = new TextEncoder().encode(parts.join('\u0001'));
  const digest = await crypto.subtle.digest('SHA-256', enc);
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
}

// Quantize the volatile sheet into a coarse digest: the same question in a
// "similar enough" yard state hits the cache — the teaching moment.
function stateDigest(cells: Record<string, { v: unknown }>): string {
  const q = (id: string, step: number): string => {
    const v = cells[id]?.v;
    return typeof v === 'number' ? String(Math.round(v / step) * step) : String(v ?? '');
  };
  return [
    q('robot.think', 1), q('robot.battery.pct', 10), q('robot.speed', 1),
    q('robot.sensor.ultrasonic', 1), q('race.lap', 1), q('program.currentTile', 1),
    q('program.state', 1), q('player.biome', 1), q('build.integrityPct', 25),
    q('flash.board', 1),
  ].join('|');
}

function systemPrompt(): string {
  return [
    'You are Spark — the friendly robot mentor inside SCRAPCRAFT, a voxel scrapyard where middle schoolers build robots and program them with tile code.',
    'You are explaining a LIVE QUILT SHEET: the whole game shown as spreadsheet cells that talk to each other (sensors flow into logic, logic into motors).',
    'Your audience is curious middle schoolers. Be warm, concrete, and short: 3-6 sentences or a few short bullets.',
    'Use the live cell data as evidence. When you mention a cell, write its id exactly (like `robot.motorL.volts` or `race.lapFrac`) so the app can draw a sparkline next to it.',
    'Connect cells to real embedded engineering when it fits (PWM duty, battery sag, encoder odometry, ultrasonic ranging) — that is the point of the game.',
    'One tiny analogy max. Never mention JSON, prompts, or that you are a language model.',
  ].join(' ');
}

function contextBlock(sheetState: { t: number; cells: Record<string, { v: unknown }> }, history: { t: number[]; series: Record<string, unknown[]> }): string {
  const lines = Object.entries(sheetState.cells).map(([id, c]) => `  ${id} = ${JSON.stringify(c.v)}`).join('\n');
  const tapeLines = Object.entries(history.series).slice(0, 8).map(([id, vals]) => {
    const tail = (vals ?? []).slice(-6).map(v => JSON.stringify(v)).filter(v => v !== 'null' && v !== 'undefined').join(' → ');
    return `  ${id}: ${tail}`;
  }).join('\n');
  return `LIVE YARD SHEET (lamport t=${sheetState.t}):\n${lines}\n\nRECENT TAPE (newest last):\n${tapeLines}`;
}

// ── THE SEAM ─────────────────────────────────────────────────────────────────
// Swap this for a fetch to scrap-spark when that lane ships. Everything else
// (context injection, pincher cache, D1 ledger) stays.
async function runModel(env: ChatEnv, system: string, prompt: string, model: string): Promise<string> {
  const res: any = await env.AI.run(model as never, {
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: prompt },
    ],
    // deepseek-v4-flash is a reasoner: it spends tokens on reasoning_content
    // BEFORE message.content — budget for both or content comes back empty.
    max_tokens: 2000,
  } as never);
  const msg = res?.choices?.[0]?.message ?? {};
  const text = (msg?.content ?? res?.response ?? res?.output ?? '').trim();
  if (!text) throw new Error(`empty model response — keys=[${Object.keys(res ?? {}).join(',')}] finish=${res?.choices?.[0]?.finish_reason}`);
  return text;
}
// ── END SEAM ────────────────────────────────────────────────────────────────

export interface ChatResult {
  answer: string;
  cached: boolean;
  model: string;
  route?: string;      // 'cheap' | 'strong' — the quilt-ai router lane
  because?: string[];  // why the router picked that lane
  took_ms: number;
  hash: string;
  cells: Record<string, CellValue>; // spark.* cell updates for the sheet
}

export async function handleSparkChat(
  env: ChatEnv,
  question: string,
  sheetState: { t: number; cells: Record<string, { v: unknown }> },
  history: { t: number[]; series: Record<string, unknown[]> },
): Promise<ChatResult> {
  const q = normalize(question);
  const digest = stateDigest(sheetState.cells);
  const hash = await sha256(['spark-chat', q, digest]);
  const started = Date.now();

  // 1) pincher hit?
  const cached = await env.INDEX.get<{ a: string; m: string; ts: number }>(`spark:${hash}`, 'json');
  if (cached?.a) {
    env.DB.prepare('UPDATE chat_ledger SET hits = hits + 1 WHERE hash = ?1').bind(hash).run().catch(() => {});
    return {
      answer: cached.a, cached: true, model: cached.m, took_ms: Date.now() - started, hash,
      cells: { 'spark.lastQuestion': question, 'spark.cacheHit': true, 'spark.lastTookMs': Date.now() - started },
    };
  }

  // 2) miss → model — ROUTED (quilt-ai pattern): cheap lane for casual,
  //    strong lane for code help. Same /chat contract; the lane is underneath.
  const route = routeQuestion(question);
  const prompt = `${contextBlock(sheetState, history)}\n\nKID ASKS: ${question}\n\nAnswer as Spark:`;
  let answer = '';
  try {
    answer = await runModel(env, systemPrompt(), prompt, route.model);
  } catch (e) {
    throw new Error(`spark model call failed: ${(e as Error).message}`);
  }
  if (!answer) throw new Error('spark model returned empty answer');
  const took_ms = Date.now() - started;

  // 3) can it
  await env.INDEX.put(`spark:${hash}`, JSON.stringify({ a: answer, m: CHAT_MODEL, ts: started }), { expirationTtl: KV_TTL });
  env.DB.prepare(
    `INSERT INTO chat_ledger (hash, question, answer, model, tokens, hits, created_at)
     VALUES (?1,?2,?3,?4,?5,0,?6)
     ON CONFLICT(hash) DO UPDATE SET hits = hits + 1`,
  ).bind(hash, q, answer, route.model, answer.length, started).run().catch(() => {});

  return {
    answer, cached: false, model: route.model, route: route.route, because: route.because, took_ms, hash,
    cells: { 'spark.lastQuestion': question, 'spark.cacheHit': false, 'spark.lastTookMs': took_ms },
  };
}
