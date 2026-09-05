# spline-instrument

**Sculpt waveforms with your mouse. The spline IS the sound.**

A zero-dependency browser instrument built in a single HTML file. Click and drag to place control points, hear the resulting waveform through Web Audio. Three modes: spline interpolation, Fourier harmonics, and Laplacian wave propagation.

## What This Gives You

- **Spline Sculpt mode** — Catmull-Rom interpolation through your control points. Draw the shape, hear the wave.
- **Fourier Paint mode** — Each point is a harmonic. X = frequency, Y = amplitude. Paint your spectrum.
- **Laplacian Wave mode** — Points are coupled oscillators on a 1D lattice. Watch waves propagate and settle.
- **Real-time audio** — Web Audio API with custom periodic waveforms built from your spline
- **CR readout** — Live conservation ratio of the current waveform shape
- **Zero dependencies** — one HTML file, open in any browser

## Quick Start

```bash
# Just open it
open index.html
# Or serve it
python3 -m http.server 8000
```

Click to place points. Drag to move them. Right-click to delete. The green line is your waveform. The scanning dot shows the current playback position.

## Controls

| Control | Action |
|---------|--------|
| Click | Place a control point |
| Drag | Move a point |
| Right-click | Delete nearest point |
| **Spline Sculpt** | Catmull-Rom through points |
| **Fourier Paint** | Points as harmonic amplitudes |
| **Laplacian Wave** | Coupled oscillator simulation |
| **Play Sound** | Generate audio from waveform |
| **Add Harmonic** | Random new point |
| **Toggle Trail** | Show/hide scanning dot trail |

## The Math

The audio engine builds a custom `PeriodicWave` from the spline: it samples the curve at 100 points, computes Fourier coefficients via DFT, and feeds them to an `OscillatorNode`. The conservation ratio displayed is the spectral flatness of the waveform — how evenly distributed the frequency content is.

## How It Fits

Part of the SuperInstance spectral ecosystem:

- **[spline-spectral](https://github.com/SuperInstance/spline-spectral)** — The Rust theory: B-splines as spectral objects
- **spline-instrument** — Hear the math (this repo)
- **[spectral-music-v2](https://github.com/SuperInstance/spectral-music-v2)** — Full spectral music theory in Rust

## License

MIT

Part of the [SuperInstance](https://github.com/SuperInstance) ecosystem.
