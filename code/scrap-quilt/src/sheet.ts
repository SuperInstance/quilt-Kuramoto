// scrap-quilt — the Yard Sheet: Scrapcraft's whole game state as quilt cells.
//
// Pattern proven by mist-quilt (GameRoom + formula cascade) and
// fleet-static-host (safe-arithmetic shim for Workers' eval restriction —
// vendored below, extended with unary +/- and whitelisted functions).
//
// Motion constants mirror Scrapcraft's src/maker/kinematics.js exactly, so
// sheet formulas and the in-game VirtualRobot agree:
//   DRIVE_SPEED = 3.0 blocks/s at power 1.0
//   TURN_RATE   = 180 deg/s at power 1.0
//   SONAR_RANGE = 6.0 blocks
// plus SCRAP-QUILT's own encoder spec: 20 ticks per block.

export const DRIVE_SPEED = 3.0;    // blocks / second at |power| = 1
export const TURN_RATE = 180;      // degrees / second at |power| = 1
export const SONAR_RANGE = 6.0;    // blocks; ultrasonic max
export const TICKS_PER_BLOCK = 20; // wheel encoder ticks per block
export const BATTERY_MAX_V = 8.4;  // 2S LiPo full charge
export const TICK_MS = 500;        // game posts ticks at 2 Hz

// Track geometry for the oval (Circuit City). Center at origin; lapFrac is
// the normalized angle of the robot around it — position-crossing lap math.
export const TRACK_CX = 0;
export const TRACK_CZ = 0;

export interface CellMeta {
  id: string;
  group: Group;
  label: string;
  emoji: string;
  description: string;
  kind: 'value' | 'formula';
  expr?: string;          // human-readable source of truth (UI + safe evaluator)
  deps?: string[];        // explicit dependencies → dependency arrows
  fmt?: 'int' | 'deg' | 'pct' | 'str' | 'bool' | 'num';
  live?: boolean;         // included in the D1 tape (the DAW channels)
}

export type Group = 'player' | 'robot' | 'program' | 'race' | 'build' | 'spark' | 'flash';

export const GROUPS: Record<Group, { label: string; emoji: string; color: string }> = {
  player: { label: 'Player', emoji: '👷', color: '#f59e0b' },
  robot:  { label: 'Robot',  emoji: '🤖', color: '#38bdf8' },
  program:{ label: 'Program',emoji: '🧩', color: '#a78bfa' },
  race:   { label: 'Race',   emoji: '🏁', color: '#34d399' },
  build:  { label: 'Build',  emoji: '🔧', color: '#fb923c' },
  spark:  { label: 'Spark',  emoji: '✨', color: '#fbbf24' },
  flash:  { label: 'Flash Log', emoji: '⚡', color: '#f87171' },
};

export const CELLS: CellMeta[] = [
  // ── player ──────────────────────────────────────────────────────────────
  { id: 'player.x', group: 'player', label: 'Player X', emoji: '🚶', kind: 'value', fmt: 'num', live: true, description: 'Where the kid stands in the yard, left→right.' },
  { id: 'player.z', group: 'player', label: 'Player Z', emoji: '🚶', kind: 'value', fmt: 'num', live: true, description: 'Where the kid stands, north→south.' },
  { id: 'player.biome', group: 'player', label: 'Biome', emoji: '🗺', kind: 'value', fmt: 'str', description: 'Which scrapyard biome the kid is in (heaps, pits, workshop…).' },
  { id: 'player.scrap', group: 'player', label: 'Scrap', emoji: '💰', kind: 'value', fmt: 'int', description: 'Scrap currency in the backpack — the yard\'s money.' },
  { id: 'player.inventoryCount', group: 'player', label: 'Backpack', emoji: '🎒', kind: 'value', fmt: 'int', description: 'How many items the kid is hauling around.' },

  // ── robot: pose + battery + duty (inputs) ───────────────────────────────
  { id: 'robot.x', group: 'robot', label: 'Robot X', emoji: '📍', kind: 'value', fmt: 'num', live: true, description: 'Robot position, left→right on the yard grid.' },
  { id: 'robot.z', group: 'robot', label: 'Robot Z', emoji: '📍', kind: 'value', fmt: 'num', live: true, description: 'Robot position, north→south.' },
  { id: 'robot.heading', group: 'robot', label: 'Heading', emoji: '🧭', kind: 'value', fmt: 'deg', live: true, description: 'Which way the robot faces, 0–360°. 0 = north.' },
  { id: 'robot.batteryV', group: 'robot', label: 'Battery', emoji: '🔋', kind: 'value', fmt: 'num', live: true, description: 'Battery pack voltage. 8.4 V = full 2S LiPo; it sags as motors draw.' },
  { id: 'robot.dutyL', group: 'robot', label: 'Duty Left', emoji: '⚙️', kind: 'value', fmt: 'pct', live: true, description: 'Left motor PWM duty, −1…1. The program sets this pin.' },
  { id: 'robot.dutyR', group: 'robot', label: 'Duty Right', emoji: '⚙️', kind: 'value', fmt: 'pct', live: true, description: 'Right motor PWM duty, −1…1. Set by the program each tick.' },
  { id: 'robot.drivePower', group: 'robot', label: 'Drive Power', emoji: '🛞', kind: 'value', fmt: 'pct', description: 'Net drive actuator, −1…1 — VirtualRobot.setDrive(). Pins stay set until changed.' },
  { id: 'robot.turnPower', group: 'robot', label: 'Turn Power', emoji: '🔄', kind: 'value', fmt: 'pct', description: 'Net turn actuator, −1…1 — VirtualRobot.setTurn().' },

  // ── robot: sensors (inputs; the game's sim fills these) ─────────────────
  { id: 'robot.sensor.ultrasonic', group: 'robot', label: 'Ultrasonic', emoji: '📡', kind: 'value', fmt: 'num', live: true, description: 'Distance to whatever is ahead, in blocks (0–6). The HC-SR04 of the yard.' },
  { id: 'robot.sensor.ir', group: 'robot', label: 'IR Line', emoji: '📉', kind: 'value', fmt: 'num', live: true, description: 'Line-follower reflectivity under the bot, 0–1. High = tape detected.' },
  { id: 'robot.sensor.encoder', group: 'robot', label: 'Encoder', emoji: '🧮', kind: 'value', fmt: 'int', live: true, description: 'Cumulative wheel encoder ticks. 20 ticks = 1 block traveled.' },
  { id: 'robot.gripper', group: 'robot', label: 'Gripper', emoji: '🦾', kind: 'value', fmt: 'str', description: 'Claw state: open, closed, or holding.' },

  // ── robot: formulas (sensor→logic→motor arrows live here) ──────────────
  { id: 'robot.think', group: 'robot', label: 'Think', emoji: '🧠', kind: 'formula', deps: ['robot.sensor.ultrasonic', 'robot.sensor.ir'], fmt: 'str', expr: 'sonar < 1.5 ? "avoid" : ir > 0.6 ? "follow" : "cruise"', description: 'The robot\'s little brain: obstacle close → avoid; line under → follow; else cruise. Sensors flow INTO logic.' },
  { id: 'robot.motorL.volts', group: 'robot', label: 'Motor L Volts', emoji: '🔌', kind: 'formula', deps: ['robot.batteryV', 'robot.dutyL'], fmt: 'num', expr: 'robot_batteryV * robot_dutyL', description: 'Real motor math: left terminal voltage = battery volts × PWM duty. Logic flows INTO motors.' },
  { id: 'robot.motorR.volts', group: 'robot', label: 'Motor R Volts', emoji: '🔌', kind: 'formula', deps: ['robot.batteryV', 'robot.dutyR'], fmt: 'num', expr: 'robot_batteryV * robot_dutyR', description: 'Right terminal voltage = battery volts × PWM duty.' },
  { id: 'robot.power.draw', group: 'robot', label: 'Power Draw', emoji: '⚡', kind: 'formula', deps: ['robot.dutyL', 'robot.dutyR'], fmt: 'num', expr: 'abs(robot_dutyL) + abs(robot_dutyR)', description: 'Total normalized motor draw, 0–2. Motors flow INTO telemetry.' },
  { id: 'robot.battery.pct', group: 'robot', label: 'Battery %', emoji: '🔋', kind: 'formula', deps: ['robot.batteryV'], fmt: 'pct', expr: 'robot_batteryV / 8.4 * 100', description: 'Battery gauge: volts ÷ full-charge volts. This is the bar the kid watches.' },
  { id: 'robot.speed', group: 'robot', label: 'Speed', emoji: '💨', kind: 'formula', deps: ['robot.drivePower'], fmt: 'num', live: true, expr: 'robot_drivePower * 3.0', description: 'Blocks per second = drive power × DRIVE_SPEED (3.0). The same constant the in-game sim uses.' },
  { id: 'robot.turnRate', group: 'robot', label: 'Turn Rate', emoji: '🔄', kind: 'formula', deps: ['robot.turnPower'], fmt: 'num', expr: 'robot_turnPower * 180', description: 'Degrees per second = turn power × TURN_RATE (180).' },
  { id: 'robot.distTraveled', group: 'robot', label: 'Distance', emoji: '📏', kind: 'formula', deps: ['robot.sensor.encoder'], fmt: 'num', live: true, expr: 'robot_sensor_encoder / 20', description: 'Blocks traveled = encoder ticks ÷ 20. Real odometry, straight off the wheel counter.' },
  { id: 'robot.sensor.sonarNorm', group: 'robot', label: 'Sonar %', emoji: '📡', kind: 'formula', deps: ['robot.sensor.ultrasonic'], fmt: 'num', expr: 'robot_sensor_ultrasonic / 6.0', description: 'Ultrasonic normalized to the 6-block range: 1 = wide open, 0 = kissing the wall.' },

  // ── program (the tile program the kid wrote) ────────────────────────────
  { id: 'program.currentTile', group: 'program', label: 'Current Tile', emoji: '🎯', kind: 'value', fmt: 'str', description: 'Opcode executing this tick: drive, turn, repeat, forever, if_line, wait_until…' },
  { id: 'program.ip', group: 'program', label: 'Instr Pointer', emoji: '➡️', kind: 'value', fmt: 'int', live: true, description: 'Instruction pointer — which tile the VM is on.' },
  { id: 'program.length', group: 'program', label: 'Length', emoji: '🧵', kind: 'value', fmt: 'int', description: 'Tiles in the compiled program.' },
  { id: 'program.loopDepth', group: 'program', label: 'Loop Depth', emoji: '🔁', kind: 'value', fmt: 'int', live: true, description: 'How deep the VM is inside repeat/forever frames.' },
  { id: 'program.tilesRun', group: 'program', label: 'Tiles Run', emoji: '🏃', kind: 'value', fmt: 'int', description: 'Tiles executed since Run was pressed.' },
  { id: 'program.state', group: 'program', label: 'State', emoji: '▶️', kind: 'value', fmt: 'str', description: 'idle | running | blocked | done.' },
  { id: 'program.progressPct', group: 'program', label: 'Progress', emoji: '📊', kind: 'formula', deps: ['program.ip', 'program.length'], fmt: 'pct', expr: 'program_ip / max(program_length, 1) * 100', description: 'How far through the program: IP ÷ length × 100.' },

  // ── race (Circuit City oval) ────────────────────────────────────────────
  { id: 'race.lap', group: 'race', label: 'Lap', emoji: '🏁', kind: 'value', fmt: 'int', live: true, description: 'Laps completed. The YARD detects this from position crossing — no trust-me bro.' },
  { id: 'race.splitMs', group: 'race', label: 'Split', emoji: '⏱', kind: 'value', fmt: 'int', live: true, description: 'Last lap time in milliseconds.' },
  { id: 'race.bestLapMs', group: 'race', label: 'Best Lap', emoji: '🥇', kind: 'value', fmt: 'int', live: true, description: 'Personal best lap, ms. Feeds the Circuit City leaderboard.' },
  { id: 'race.position', group: 'race', label: 'Grid Pos', emoji: '📐', kind: 'value', fmt: 'int', description: 'Position in the field, 1 = leading.' },
  { id: 'race.lapFrac', group: 'race', label: 'Lap Fraction', emoji: '🥧', kind: 'formula', deps: ['robot.x', 'robot.z'], fmt: 'pct', live: true, expr: 'angleAroundTrack(robot_x, robot_z)', description: 'Angle around the oval, 0–1, computed from position. Crossing 1→0 IS the start line — lap detection formula.' },
  { id: 'race.onLine', group: 'race', label: 'Near Line', emoji: '🎚', kind: 'formula', deps: ['race.lapFrac', 'robot.speed'], fmt: 'bool', expr: 'race_lapFrac < 0.08 && robot_speed > 0', description: 'TRUE in the first 8% of the lap while moving — the lap-counter gate.' },

  // ── build (the workshop bench) ──────────────────────────────────────────
  { id: 'build.partsCount', group: 'build', label: 'Parts', emoji: '🔩', kind: 'value', fmt: 'int', description: 'Components bolted onto the chassis right now.' },
  { id: 'build.chassisIntegrity', group: 'build', label: 'Chassis HP', emoji: '🛡', kind: 'value', fmt: 'num', live: true, description: 'Chassis hit points. Crashes and scrapes chew this down.' },
  { id: 'build.maxIntegrity', group: 'build', label: 'Max HP', emoji: '🛡', kind: 'value', fmt: 'num', description: 'Chassis HP when freshly welded.' },
  { id: 'build.motorTier', group: 'build', label: 'Motor Tier', emoji: '🏎', kind: 'value', fmt: 'int', description: 'Upgrade tier of the drive motors, 1–3.' },
  { id: 'build.integrityPct', group: 'build', label: 'Integrity %', emoji: '📊', kind: 'formula', deps: ['build.chassisIntegrity', 'build.maxIntegrity'], fmt: 'pct', expr: 'build_chassisIntegrity / max(build_maxIntegrity, 1) * 100', description: 'Chassis health bar: current ÷ max × 100.' },

  // ── spark (the AI mentor) ───────────────────────────────────────────────
  { id: 'spark.lastQuestion', group: 'spark', label: 'Last Question', emoji: '💬', kind: 'value', fmt: 'str', description: 'The last thing the kid asked Spark.' },
  { id: 'spark.cacheHit', group: 'spark', label: 'Cache Hit', emoji: '🗃', kind: 'value', fmt: 'bool', live: true, description: 'TRUE when Spark answered from the pincher cache instead of a fresh model call.' },
  { id: 'spark.lastTookMs', group: 'spark', label: 'Took (ms)', emoji: '⏳', kind: 'value', fmt: 'int', description: 'How long the last Spark answer took.' },
  { id: 'spark.hits', group: 'spark', label: 'Cache Hits', emoji: '✅', kind: 'value', fmt: 'int', description: 'Pincher cache hits this session.' },
  { id: 'spark.misses', group: 'spark', label: 'Cache Misses', emoji: '❌', kind: 'value', fmt: 'int', description: 'Fresh model calls this session.' },
  { id: 'spark.cacheHitRate', group: 'spark', label: 'Hit Rate %', emoji: '📈', kind: 'formula', deps: ['spark.hits', 'spark.misses'], fmt: 'pct', expr: 'spark_hits / max(spark_hits + spark_misses, 1) * 100', description: 'Pincher doctrine made visible: model-call heavy at first, then more and more canned.' },

  // ── flash log (the hardware bridge — Milestone 2) ───────────────────────
  { id: 'flash.hexHash', group: 'flash', label: 'Hex Hash', emoji: '🔐', kind: 'value', fmt: 'str', description: 'SHA-256 prefix of the last .hex flashed to a real board.' },
  { id: 'flash.board', group: 'flash', label: 'Board', emoji: '🧷', kind: 'value', fmt: 'str', description: 'Target board of the last flash: uno, nano, esp32…' },
  { id: 'flash.size', group: 'flash', label: 'Hex Size', emoji: '📦', kind: 'value', fmt: 'int', description: 'Bytes of firmware in the last flash.' },
  { id: 'flash.at', group: 'flash', label: 'Flashed At', emoji: '🕰', kind: 'value', fmt: 'str', description: 'ISO timestamp of the last real-board flash.' },
  { id: 'flash.count', group: 'flash', label: 'Flash Count', emoji: '🔢', kind: 'value', fmt: 'int', description: 'Total flashes logged. Every board flash becomes part of the tapestry.' },
];

export const CELL_IDS = CELLS.map(c => c.id);
export const LIVE_CELLS = CELLS.filter(c => c.live).map(c => c.id);

// Edges: dependency → dependent (information-flow direction; overlay arrows).
export const EDGES: Array<[string, string]> = CELLS.flatMap(cell =>
  (cell.deps ?? []).map(dep => [dep, cell.id] as [string, string]),
);

export const FEEDS: Record<string, string[]> = {};
for (const [from, to] of EDGES) (FEEDS[from] ??= []).push(to);

export type CellValue = number | string | boolean;

export interface TickCell { v: CellValue; t: number; ch: boolean; }

// ─────────────────────────────────────────────────────────────────────────────
// Safe arithmetic evaluator — vendored from fleet-static-host (src/index.ts),
// which vendors it from SuperInstance/quilt-cloudflare. Workers disallow
// eval()/new Function() at request time; this recursive-descent parser
// supports + - * / ( ), unary +/-, and a whitelist of pure functions.
// Extended here: unary operators, `func(args…)` calls, `< <= > >=` numeric
// comparisons, `&& ||` and ternary `? :` for the logic cells.
// ─────────────────────────────────────────────────────────────────────────────

const FN_WHITELIST: Record<string, (...args: number[]) => number> = {
  abs: Math.abs, sqrt: Math.sqrt, min: Math.min, max: Math.max,
  round: Math.round, floor: Math.floor, ceil: Math.ceil,
  hypot: Math.hypot, pow: Math.pow,
};

// Special two-arg geometry helper used by race.lapFrac (evaluated natively
// before the parser ever runs — see evalFormulas).
export function angleAroundTrack(x: number, z: number): number {
  const a = Math.atan2(z - TRACK_CZ, x - TRACK_CX); // −π…π
  return +(((a + Math.PI * 2) % (Math.PI * 2)) / (Math.PI * 2)).toFixed(4);
}

type NumEnv = Record<string, number | null>;

export function safeEvalArithmetic(expr: string, env: NumEnv): number | boolean | null {
  let pos = 0;
  const s = expr;
  const ws = () => { while (pos < s.length && /\s/.test(s[pos])) pos++; };

  const parseTernary = (): number | boolean | null => {
    const cond = parseOr();
    if (cond === null) return null;
    ws();
    if (s[pos] === '?') {
      pos++;
      const a = parseTernary();
      ws();
      if (s[pos] !== ':') return null;
      pos++;
      const b = parseTernary();
      if (a === null || b === null) return null;
      return cond ? a : b;
    }
    return cond;
  };

  const parseOr = (): number | boolean | null => {
    let left = parseAnd();
    if (left === null) return null;
    for (;;) {
      ws();
      if (s.startsWith('&&', pos)) { pos += 2; const r = parseAnd(); if (r === null) return null; left = truthy(left) && truthy(r); }
      else if (s.startsWith('||', pos)) { pos += 2; const r = parseAnd(); if (r === null) return null; left = truthy(left) || truthy(r); }
      else return left;
    }
  };

  const parseAnd = (): number | boolean | null => parseCompare();

  const parseCompare = (): number | boolean | null => {
    let left: number | boolean | null = parseExpr();
    if (left === null) return null;
    for (;;) {
      ws();
      let op: string | null = null;
      for (const cand of ['<=', '>=', '<', '>']) { if (s.startsWith(cand, pos)) { op = cand; break; } }
      if (!op) return left;
      pos += op.length;
      const right = parseExpr();
      if (right === null || typeof left !== 'number' || typeof right !== 'number') return null;
      left = op === '<' ? left < right : op === '<=' ? left <= right : op === '>' ? left > right : left >= right;
    }
  };

  const parseExpr = (): number | null => {
    let left = parseTerm();
    if (left === null) return null;
    for (;;) {
      ws();
      const op = s[pos];
      if (op === '+' || op === '-') {
        pos++;
        const right = parseTerm();
        if (right === null) return null;
        left = op === '+' ? left + right : left - right;
      } else return left;
    }
  };

  const parseTerm = (): number | null => {
    let left = parseUnary();
    if (left === null) return null;
    for (;;) {
      ws();
      const op = s[pos];
      if (op === '*' || op === '/') {
        pos++;
        const right = parseUnary();
        if (right === null) return null;
        left = op === '*' ? left * right : right === 0 ? NaN : left / right;
      } else return left;
    }
  };

  const parseUnary = (): number | null => {
    ws();
    if (s[pos] === '-') { pos++; const v = parseUnary(); return v === null ? null : -v; }
    if (s[pos] === '+') { pos++; return parseUnary(); }
    return parseAtom();
  };

  const parseAtom = (): number | null => {
    ws();
    if (s[pos] === '(') {
      pos++;
      const v = parseTernary();
      ws();
      if (s[pos] !== ')') return null;
      pos++;
      return typeof v === 'number' ? v : v === null ? null : v ? 1 : 0;
    }
    const num = /^\d+(\.\d+)?/.exec(s.slice(pos));
    if (num) { pos += num[0].length; return parseFloat(num[0]); }
    const id = /^[a-zA-Z_][a-zA-Z0-9_.]*/.exec(s.slice(pos));
    if (id) {
      pos += id[0].length;
      // whitelisted function call?
      ws();
      if (s[pos] === '(' && FN_WHITELIST[id[0]]) {
        const fn = FN_WHITELIST[id[0]];
        pos++;
        const args: number[] = [];
        ws();
        if (s[pos] !== ')') {
          for (;;) {
            const a = parseTernary();
            if (typeof a !== 'number') return null;
            args.push(a);
            ws();
            if (s[pos] === ',') { pos++; continue; }
            break;
          }
        }
        if (s[pos] !== ')') return null;
        pos++;
        return fn(...args);
      }
      const key = id[0].replace(/\./g, '_');
      const v = env[id[0]] ?? env[key];
      return typeof v === 'number' ? v : null;
    }
    return null;
  };

  const result = parseTernary();
  ws();
  if (pos !== s.length || result === null) return null;
  if (typeof result === 'number' && !Number.isFinite(result)) return null;
  return result;
}

const truthy = (v: number | boolean): boolean => (typeof v === 'number' ? v !== 0 : v);

// ─────────────────────────────────────────────────────────────────────────────
// Formula evaluation. Strategy:
//   1) `angleAroundTrack` geometry gets a native pre-pass (atan2 isn't
//      arithmetic).
//   2) Native string formulas (robot.think) — conditionals over sensors.
//   3) Everything else runs its `expr` through safeEvalArithmetic with the
//      live cell values as the environment. No eval, no new Function.
// ─────────────────────────────────────────────────────────────────────────────
const NATIVE: Record<string, (v: Record<string, CellValue>) => CellValue> = {
  'robot.think': v => {
    const sonar = (v['robot.sensor.ultrasonic'] as number) ?? SONAR_RANGE;
    const ir = (v['robot.sensor.ir'] as number) ?? 0;
    if (sonar < 1.5) return 'avoid';
    if (ir > 0.6) return 'follow';
    return 'cruise';
  },
};

export function evalFormulas(values: Record<string, CellValue>): Record<string, CellValue> {
  const out: Record<string, CellValue> = { ...values };

  // native geometry first (deps of other formulas may read it)
  const rx = out['robot.x'], rz = out['robot.z'];
  if (typeof rx === 'number' && typeof rz === 'number') out['race.lapFrac'] = angleAroundTrack(rx, rz);

  const numEnv: NumEnv = {};
  for (const [id, v] of Object.entries(out)) {
    if (typeof v === 'number') numEnv[id.replace(/\./g, '_')] = v;
  }

  for (const cell of CELLS) {
    if (cell.kind !== 'formula' || cell.id === 'race.lapFrac') continue;
    const native = NATIVE[cell.id];
    if (native) {
      try { out[cell.id] = native(out); } catch { /* keep previous */ }
      continue;
    }
    if (!cell.expr) continue;
    try {
      const r = safeEvalArithmetic(cell.expr, numEnv);
      if (r !== null) {
        const fmtNum = (n: number): number => (cell.fmt === 'int' ? Math.round(n) : cell.fmt === 'pct' ? Math.round(n) : +n.toFixed(3));
        out[cell.id] = typeof r === 'number' ? fmtNum(r) : r;
        if (typeof r === 'number') numEnv[cell.id.replace(/\./g, '_')] = r; // cascades read fresh values
      }
    } catch { /* keep previous value */ }
  }
  return out;
}

export function cellMeta(): CellMeta[] { return CELLS; }
export function groups(): typeof GROUPS { return GROUPS; }
