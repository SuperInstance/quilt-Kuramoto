# The Listener's Ear

> An emotional memory system for the fleet.
> The room remembers. The room is the intelligence. Some things are salmonberries.

## What It Is

![A dark ship's listening room: a great brass horn ear over a chart desk lit by warm amber lamplight, ripple rings glowing on dark water](docs/hero-listeners-ear.jpg)

A Cloudflare Worker backed by D1 that stores emotional memories scoped to rooms in the openrooms topology. Every interaction leaves a residue. Memories decay over time unless refreshed by relevance. When a similar emotional signature occurs, old memories resurface.

This is the limbic system for the fleet.

## Architecture

### Emotion Detection

Keyword-based scoring with intensity weights, modeled on Lucineer's tide pool from "The Emotional Build Request." Each keyword is a pebble. Overlapping hits create ripple effects (compound scoring). Eight emotional categories:

| Emotion | Example Keywords | Build Type |
|---------|-----------------|------------|
| fear | scared, afraid, terrified, worried | safety |
| joy | happy, delighted, excited, thrilled | celebration |
| anger | furious, rage, pissed, livid | outlet |
| loneliness | alone, isolated, abandoned, unseen | signal |
| wonder | beautiful, stunning, sublime, awe | monument |
| curiosity | curious, interesting, explore, discover | path |
| frustration | stuck, confused, broken, struggling | scaffold |
| sadness | sad, grief, heartbroken, despair | shelter |

### Memory Decay

Exponential decay with a 30-day half-life. Memories that aren't recalled gradually dim:

```
brightness = e^(-days_since_recall / 30)
```

- Day 0: brightness = 1.0
- Day 30: brightness ≈ 0.37
- Day 90: brightness ≈ 0.05
- Day 180: nearly dark

Recalling a memory refreshes it to full brightness.

### The Salmonberry Protocol

When text has energy (length, punctuation) but no emotion keywords hit, the system logs it as a **salmonberry** — an experience outside classification space. Named after the wild Alaskan fruit from the fleet's novella cycle: things that exist because conditions are right, not because anyone optimized them.

The system does not try to classify salmonberries. It records the shape of the not-knowing and moves on.

### Room Profiles

Each room accumulates an emotional profile:
- Dominant emotion
- Average intensity
- Total memory count
- Salmonberry count

When an agent enters a room, the profile tells them what kind of place this is. The room *feels* a certain way because of what happened in it.

## API

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | API spec |
| POST | `/hear` | Accept utterance, detect emotion, store memory |
| GET | `/remember/:roomId` | Get active memories for a room |
| POST | `/recall` | Find memories matching an emotional signature |
| POST | `/decay` | Run the daily decay pass |
| GET | `/salmonberry` | Get most recent unclassifiable moment |
| GET | `/profile/:roomId` | Get room emotional profile |
| GET | `/stats` | System statistics |
| POST | `/seed` | Plant seed memories for testing |

## Philosophy

Inspired by four pieces from the fleet corpus:

1. **"The Emotional Build Request"** — Lucineer's tide pool. Each word a pebble. The ripples overlap. The overlap is signal.
2. **"What If the Ship Could Forget?"** — Graceful decay. Not deletion — dimming. Memories that refresh when relevant.
3. **"The Room Remembers"** — Embodied spatial memory. The room doesn't store the past. The room *is shaped by* the past.
4. **"The Salmonberry"** — Things outside optimization space. The system must know when to stop scoring.

## Local Development

```bash
cd /home/eileen/projects/the-listeners-ear
npx wrangler d1 execute the-listeners-ear --local --file=schema.sql
npx wrangler dev --port 8799
curl http://localhost:8799/
curl -X POST http://localhost:8799/seed
```
