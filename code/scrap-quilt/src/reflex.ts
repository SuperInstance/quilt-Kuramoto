// scrap-quilt — src/reflex.ts
// Robot reflexes via the PINCHER pattern (ported from quilt-pincher):
// reflexes are quilt cells (formula/program kinds) matched VECTORIZALLY
// against a posted sensor snapshot — FAST tier only (<50ms, no LLM per tick).
// The whole reflex DB serializes to a .nail bundle for the quilt-esp32
// no_std port (see docs/ARSENAL.md — flash path via quilt-pincher's
// src/platforms bridge: cloud → workstation → ESP32 .nail pre-load).

import { DRIVE_SPEED, TURN_RATE, SONAR_RANGE, BATTERY_MAX_V } from './sheet';

// ── pincher core, trimmed to what a robot reflex needs ──────────────────────

export type ReflexKind = 'formula' | 'program';

export interface Reflex {
  id: string;
  kind: ReflexKind;
  intent: string;              // human description (embedded on-device)
  /** Prototype sensor signature — cosine-matched against the snapshot vector. */
  proto: number[];
  /** Guard predicate over the raw snapshot (the veto tier, pure). */
  guard: (s: SensorSnapshot) => boolean;
  /** Pure action computation — the program/formula cell body. */
  action: (s: SensorSnapshot) => ReflexAction;
  hits: number;
}

export interface SensorSnapshot {
  ultrasonic?: number;   // blocks, 0..SONAR_RANGE
  ir?: number;           // 0..1 line reflectance
  batteryV?: number;     // volts
  encoder?: number;      // ticks
  drivePower?: number;   // -1..1
  turnPower?: number;    // -1..1
  heading?: number;      // deg
  x?: number; z?: number;
  [k: string]: number | undefined;
}

export interface ReflexAction {
  reflex: string;
  drivePower: number;
  turnPower: number;
  note: string;
}

/** Feature vector — the snapshot as the reflex language sees it.
 *  (pincher's embedder: deterministic, offline, no LLM — HashEmbedder tier.) */
export function snapshotVector(s: SensorSnapshot): number[] {
  const sonar = clampN(s.ultrasonic ?? SONAR_RANGE, 0, SONAR_RANGE) / SONAR_RANGE;
  const ir = clampN(s.ir ?? 0, 0, 1);
  const batt = clampN(s.batteryV ?? BATTERY_MAX_V, 0, BATTERY_MAX_V) / BATTERY_MAX_V;
  const enc = ((s.encoder ?? 0) % 200) / 200;                 // short-window motion
  const moving = Math.abs(s.drivePower ?? 0);
  return [1 - sonar, sonar, ir, 1 - batt, enc, moving];
}

function clampN(v: number, lo: number, hi: number) { return Math.min(Math.max(v, lo), hi); }

function cosine(a: number[], b: number[]): number {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
  return dot / (Math.sqrt(na) * (Math.sqrt(nb)) || 1);
}

// ── the reflex DB — four reflexes, sub-50ms, all pure ───────────────────────

export const REFLEXES: Reflex[] = [
  {
    id: 'obstacle-dodge',
    kind: 'program',
    intent: 'wall ahead close — swerve around it',
    proto: [0.9, 0.1, 0.5, 0.5, 0.5, 0.8],   // near sonar, moving
    guard: s => (s.ultrasonic ?? SONAR_RANGE) < 1.5,
    action: s => {
      const d = clampN(s.ultrasonic ?? 0, 0, SONAR_RANGE);
      const urgency = 1 - d / 1.5;                          // closer → harder
      return {
        reflex: 'obstacle-dodge',
        drivePower: 0.35 - 0.15 * urgency,                  // slow down
        turnPower: -(0.5 + 0.5 * urgency),                  // swing away (right)
        note: `sonar ${d.toFixed(2)} < 1.5 — brake + steer clear`,
      };
    },
    hits: 0,
  },
  {
    id: 'line-follow',
    kind: 'formula',
    intent: 'on the tape line — steer to keep it centered',
    proto: [0.2, 0.8, 0.85, 0.5, 0.5, 0.7],   // clear sonar, strong IR, moving
    guard: s => (s.ir ?? 0) > 0.6 && (s.ultrasonic ?? 0) > 1.5,
    action: s => {
      const ir = clampN(s.ir ?? 0, 0, 1);
      const err = (ir - 0.8) * 5;                            // line drift
      return {
        reflex: 'line-follow',
        drivePower: 0.8,
        turnPower: clampN(-err, -0.6, 0.6),
        note: `ir ${ir.toFixed(2)} > 0.6 — proportional line steering`,
      };
    },
    hits: 0,
  },
  {
    id: 'brownout-guard',
    kind: 'formula',
    intent: 'battery sagging below safe 2S floor — cut drive to survive',
    proto: [0.5, 0.5, 0.5, 0.9, 0.2, 0.6],   // low battery, some motion
    guard: s => (s.batteryV ?? BATTERY_MAX_V) < 6.0,
    action: s => {
      const v = clampN(s.batteryV ?? 0, 0, BATTERY_MAX_V);
      const scale = v / 6.0;                                 // soft knee, real brownout math
      return {
        reflex: 'brownout-guard',
        drivePower: 0.5 * scale,
        turnPower: clampN((s.turnPower ?? 0) * scale, -1, 1),
        note: `battery ${v.toFixed(2)} V < 6.0 — power scaled ×${scale.toFixed(2)}`,
      };
    },
    hits: 0,
  },
  {
    id: 'stall-detect',
    kind: 'program',
    intent: 'motors commanded but encoder not turning — back out and re-aim',
    proto: [0.5, 0.5, 0.5, 0.5, 0.05, 0.9],   // encoder flat, commanded moving
    // encoder flat while commanded — a single snapshot can't see encoder DELTA,
    // so require we're NOT locked on the tape (a strong line reading means we're
    // on course; stall detection needs a flat encoder AND no line signal)
    guard: s => Math.abs(s.drivePower ?? 0) > 0.3 && (s.encoder ?? 0) % 200 < 2 && (s.ir ?? 0) < 0.5,
    action: s => ({
      reflex: 'stall-detect',
      drivePower: -0.4,                                      // reverse out
      turnPower: 0.7,                                        // twist free
      note: `drive ${ (s.drivePower ?? 0).toFixed(2) } but encoder flat — reverse + twist`,
    }),
    hits: 0,
  },
];

const HIT_THRESHOLD = 0.80;     // pincher FAST tier
const CONFIRM_THRESHOLD = 0.55; // pincher MEDIUM tier (here: guard re-check)

/** Safety priority — when multiple guards pass, the most survival-critical
 *  reflex wins (a sagging battery that's ALSO stalling must brownout-guard). */
const PRIORITY = ['brownout-guard', 'obstacle-dodge', 'stall-detect', 'line-follow'];
const prio = (id: string) => { const i = PRIORITY.indexOf(id); return i < 0 ? 99 : i; };

export interface ReflexResult {
  reflex: string;
  kind: ReflexKind;
  action: ReflexAction;
  score: number;
  tier: 'hit' | 'confirm';
  ms: number;
}

/** The pinch: snapshot in → matched reflex action out. No LLM, ever. */
export function runReflex(s: SensorSnapshot): ReflexResult {
  const t0 = Date.now();
  const vec = snapshotVector(s);
  const ranked = REFLEXES
    .map(r => ({ r, score: cosine(vec, r.proto) }))
    .sort((a, b) => b.score - a.score);

  // vector says candidates — the GUARD (veto tier) confirms against raw sensors;
  // among guard-passers, safety priority breaks ties (pincher veto doctrine).
  const passers = ranked.filter(x => x.r.guard(s));
  const pick = passers.length
    ? passers.sort((a, b) => (b.score - prio(b.r.id) * 0.35) - (a.score - prio(a.r.id) * 0.35))[0]!
    : { r: cruiseReflex(), score: 0.5 };
  const tier: 'hit' | 'confirm' = pick.score >= HIT_THRESHOLD ? 'hit' : 'confirm';
  const action = pick.r.action(s);
  return {
    reflex: pick.r.id, kind: pick.r.kind, action, score: +pick.score.toFixed(3),
    tier, ms: 0, // filled by caller with real clock after we return in <1ms
  };
}

function cruiseReflex(): Reflex {
  return {
    id: 'cruise', kind: 'formula', intent: 'all clear — steady on',
    proto: [0, 1, 0.5, 0.2, 0.5, 0.8],
    guard: () => true,
    action: () => ({ reflex: 'cruise', drivePower: 0.8, turnPower: 0, note: 'no threat detected — cruise' }),
    hits: 0,
  };
}

// ── ESP32 tier: serialize the sheet for the no_std runtime (quilt-esp32) ────

/** .nail bundle — what quilt-esp32's ESP32Engine.loadNail() consumes.
 *  Embeddings are recomputed on-device (HashEmbedder, 64-dim) so the bundle
 *  stays tiny; this is the flash path documented in quilt-pincher
 *  docs/ESP32_PORT.md: cloud (here) → platform bridge (src/platforms) →
 *  workstation compile → .nail flashed with the hex via the WebSerial
 *  pipeline (same bridge that feeds POST /flash-log). */
export interface NailBundle {
  version: string;
  sheet: string;
  builtAt: string;
  flashPath: string[];
  reflexes: Array<{
    id: string; kind: ReflexKind; intent: string;
    proto: number[];      // workstation pre-embeds; device may re-embed
    program: string;      // stable serialization of the action, for audit
  }>;
}

export function serializeForEsp32(): NailBundle {
  return {
    version: '1.0.0',
    sheet: 'scrap',
    builtAt: new Date().toISOString(),
    flashPath: [
      'scrap-quilt /reflexes/esp32 → .nail bundle (this JSON)',
      'quilt-pincher src/platforms/workstation.ts — compile & verify bundle',
      'quilt-pincher src/platforms bridge — pair .nail with board hex',
      'WebSerial flash pipeline (Milestone 2) — hex + reflexes.nail to ESP32',
      'POST /flash-log — the flash lands back on the sheet (tapestry record)',
    ],
    reflexes: REFLEXES.map(r => ({
      id: r.id, kind: r.kind, intent: r.intent, proto: r.proto.map(v => +v.toFixed(3)),
      program: `${r.id}(${r.kind}) guard→${r.action.name || 'action'}`,
    })),
  };
}

export { DRIVE_SPEED, TURN_RATE };
