// scrap-quilt — /predict ghost states.
// Forward-sims the robot N ticks with the SAME kinematics as the game's
// VirtualRobot (rotation first, then translation along heading; DRIVE_SPEED
// 3.0, TURN_RATE 180) plus battery sag, encoder accumulation, and lapFrac
// crossing — so ghost racers on the oval are honest extrapolations.

import {
  DRIVE_SPEED, TURN_RATE, SONAR_RANGE, TICKS_PER_BLOCK, TICK_MS,
  angleAroundTrack, evalFormulas, type CellValue,
} from './sheet';

interface TapePoint { t: number; v: CellValue; }

export interface Ghost { tick: number; dt_ms: number; lapCrossings: number; cells: Record<string, CellValue>; }

const num = (v: CellValue | undefined, d = 0): number => (typeof v === 'number' ? v : d);
const clamp = (v: number, lo: number, hi: number): number => Math.min(Math.max(v, lo), hi);
const DEG2RAD = Math.PI / 180;
const wrapDeg = (d: number): number => ((d % 360) + 360) % 360;
const wrapRad = (r: number): number => { if (r > Math.PI) r -= 2 * Math.PI; if (r < -Math.PI) r += 2 * Math.PI; return r; };

export function predictAhead(
  current: Record<string, CellValue>,
  tape: Map<string, TapePoint[]>,
  ticks: number,
): Ghost[] {
  const dt = TICK_MS / 1000;

  let x = num(current['robot.x']);
  let z = num(current['robot.z']);
  let headingDeg = num(current['robot.heading']);
  let batteryV = num(current['robot.batteryV'], 8.4);
  let encoder = num(current['robot.sensor.encoder']);
  let lap = num(current['race.lap']);
  let dutyL = num(current['robot.dutyL']);
  let dutyR = num(current['robot.dutyR']);
  const drivePower = num(current['robot.drivePower']);
  const turnPower = num(current['robot.turnPower']);
  const ir = num(current['robot.sensor.ir']);

  // Sensor trend from the tape: is the wall getting closer?
  const sonarTrend = trend(tape.get('robot.sensor.ultrasonic'));
  let sonar = clamp(num(current['robot.sensor.ultrasonic'], SONAR_RANGE) + sonarTrend, 0, SONAR_RANGE);

  let prevFrac = angleAroundTrack(x, z);
  let lapCrossings = 0;
  const ghosts: Ghost[] = [];

  for (let k = 1; k <= ticks; k++) {
    // ── physics: VirtualRobot.tick(), verbatim semantics ──
    if (turnPower !== 0) headingDeg = wrapDeg(headingDeg + turnPower * TURN_RATE * dt);
    const heading = wrapRad(headingDeg * DEG2RAD);

    // battery sag: volts drop with normalized draw; below ~6.0 V the brownout
    // guard cuts drive — the ghost visibly slows (real robot behavior)
    const draw = Math.abs(dutyL) + Math.abs(dutyR);
    batteryV = clamp(batteryV - draw * 0.006 * dt * 10, 0, 8.4);
    const powerScale = batteryV > 6.0 ? 1 : batteryV / 6.0;

    const speed = drivePower * DRIVE_SPEED * powerScale;
    if (drivePower !== 0) {
      const dist = speed * dt;
      x += Math.sin(heading) * dist;
      z += Math.cos(heading) * dist;
      encoder += Math.abs(dist) * TICKS_PER_BLOCK;
    }
    sonar = clamp(sonar + sonarTrend, 0, SONAR_RANGE);

    // ── lap detection: position crossing 1→0 around the oval ──
    const frac = angleAroundTrack(x, z);
    if (prevFrac > 0.9 && frac < 0.1 && speed > 0.05) { lap += 1; lapCrossings++; }
    prevFrac = frac;

    // ── cascade the sheet's own formulas over the ghost state ──
    const state: Record<string, CellValue> = {
      ...current,
      'robot.x': +x.toFixed(2), 'robot.z': +z.toFixed(2), 'robot.heading': +headingDeg.toFixed(1),
      'robot.batteryV': +batteryV.toFixed(2), 'robot.sensor.encoder': Math.round(encoder),
      'robot.sensor.ultrasonic': +sonar.toFixed(2), 'robot.sensor.ir': ir,
      'robot.drivePower': drivePower, 'robot.turnPower': turnPower,
      'robot.dutyL': dutyL, 'robot.dutyR': dutyR,
      'race.lap': Math.round(lap),
    };
    const cascaded = evalFormulas(state);
    ghosts.push({
      tick: k,
      dt_ms: TICK_MS,
      lapCrossings,
      cells: {
        'robot.x': cascaded['robot.x'], 'robot.z': cascaded['robot.z'],
        'robot.heading': cascaded['robot.heading'], 'robot.speed': cascaded['robot.speed'],
        'robot.batteryV': cascaded['robot.batteryV'], 'robot.battery.pct': cascaded['robot.battery.pct'],
        'robot.motorL.volts': cascaded['robot.motorL.volts'], 'robot.motorR.volts': cascaded['robot.motorR.volts'],
        'robot.distTraveled': cascaded['robot.distTraveled'],
        'robot.think': cascaded['robot.think'],
        'race.lapFrac': cascaded['race.lapFrac'], 'race.lap': cascaded['race.lap'],
      },
    });
  }
  return ghosts;
}

function trend(tape: TapePoint[] | undefined): number {
  const pts = (tape ?? []).slice(-8);
  if (pts.length < 2) return 0;
  const nums = pts.map(p => (typeof p.v === 'number' ? p.v : 0));
  let sum = 0;
  for (let i = 1; i < nums.length; i++) sum += nums[i] - nums[i - 1];
  return +(sum / (nums.length - 1)).toFixed(3);
}
