"""
h4_learning_rate_experiment.py
==============================
The H4 experiment: does simulation-first coordination learn FASTER than
event-triggered coordination?

This is the most consequential claim in the documentation set (per
14_THE_VERIFICATION_ASYMMETRY.md Part 4). If confirmed, it connects quilt
to Wei's verifier's rule ("ease of training AI ∝ how verifiable the task is").

Setup:
  Two fleets of agents, identical except coordination mode:
    Fleet A: simulation-first (predict-and-confirm, sensors as confirmations)
    Fleet B: event-triggered (react on sensor events)

  Task: multi-agent coordination (timing alignment — agents must "play a note
  together" at a target time)

  Measure: convergence time, final accuracy, training episodes needed

  Theory: Fleet A should converge faster because each sensor read provides
  both (a) task feedback and (b) verification signal. Fleet B only gets
  feedback when events fire.
"""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import json
import os
import warnings
warnings.filterwarnings('ignore')

plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Noto Sans SC']
plt.rcParams['axes.unicode_minus'] = False

OUT_DIR = "/home/z/my-project/download/quilt-quantum-research/benchmark_results"
RNG = np.random.default_rng(42)


class Agent:
    """A simple agent that learns to play a note at the right time."""

    def __init__(self, agent_id, target_time=1.0, learning_rate=0.01):
        self.id = agent_id
        self.target_time = target_time  # the "right" time to play
        self.predicted_time = RNG.uniform(0, 2)  # initial guess
        self.last_action = self.predicted_time
        self.learning_rate = learning_rate
        self.history = [self.predicted_time]

    def predict_next(self, neighbors_last):
        """Predict what time to play next, based on own history + neighbors."""
        if len(neighbors_last) == 0:
            return self.predicted_time
        neighbor_avg = np.mean(neighbors_last)
        # Blend own prediction with neighbor average
        self.predicted_time = 0.7 * self.predicted_time + 0.3 * neighbor_avg
        return self.predicted_time

    def update_simulation_first(self, actual_time, error_signal):
        """Simulation-first: sensor CONFIRMS the prediction. Update based on
        the prediction error (the surprise)."""
        surprise = abs(self.predicted_time - actual_time)
        # Update toward the actual time, weighted by surprise
        self.predicted_time += self.learning_rate * surprise * np.sign(actual_time - self.predicted_time)
        # Also pull toward target (the "task feedback")
        self.predicted_time += self.learning_rate * (self.target_time - self.predicted_time)
        self.last_action = self.predicted_time
        self.history.append(self.predicted_time)

    def update_event_triggered(self, actual_time, event_fired):
        """Event-triggered: only update when an event fires (error exceeds threshold)."""
        if not event_fired:
            # No update — no learning signal
            self.history.append(self.predicted_time)
            return
        # Event fired — update toward actual
        self.predicted_time += self.learning_rate * (actual_time - self.predicted_time)
        # Also pull toward target
        self.predicted_time += self.learning_rate * (self.target_time - self.predicted_time)
        self.last_action = self.predicted_time
        self.history.append(self.predicted_time)


def run_experiment(n_agents=20, n_episodes=200, n_repeats=20,
                   event_threshold=0.3, coupling=0.3):
    """
    Run the H4 experiment: compare simulation-first vs event-triggered
    learning rate on a coordination task.

    Coordination task: all agents must "play a note" at target_time=1.0.
    They can observe their neighbors' last action and their own error.
    The question: which mode converges faster?

    Returns convergence curves for both modes.
    """
    sim_first_curves = []  # average error per episode, simulation-first
    event_trig_curves = []  # average error per episode, event-triggered

    for repeat in range(n_repeats):
        # Initialize two identical fleets
        agents_sim = [Agent(i, target_time=1.0, learning_rate=0.05) for i in range(n_agents)]
        agents_evt = [Agent(i, target_time=1.0, learning_rate=0.05) for i in range(n_agents)]

        # Ring topology for neighbor observation
        def neighbors(i, n):
            return [(i-1) % n, (i+1) % n]

        sim_curve = []
        evt_curve = []

        for episode in range(n_episodes):
            # --- Simulation-first fleet ---
            # Each agent predicts, then a sensor "confirms" with the actual
            # (which is the agent's predicted_time + noise)
            sim_errors = []
            sim_events_fired = 0
            for i, agent in enumerate(agents_sim):
                neigh = neighbors(i, n_agents)
                neigh_last = [agents_sim[j].last_action for j in neigh]
                predicted = agent.predict_next(neigh_last)
                # Sensor confirms: actual = predicted + small noise
                actual = predicted + 0.01 * RNG.standard_normal()
                # The "surprise" is the prediction error
                error_signal = actual - predicted
                # ALWAYS update (simulation-first: sensor is a confirmation)
                agent.update_simulation_first(actual, error_signal)
                # Error from target
                err = abs(agent.predicted_time - agent.target_time)
                sim_errors.append(err)

            sim_curve.append(np.mean(sim_errors))

            # --- Event-triggered fleet ---
            evt_errors = []
            evt_events = 0
            for i, agent in enumerate(agents_evt):
                neigh = neighbors(i, n_agents)
                neigh_last = [agents_evt[j].last_action for j in neigh]
                predicted = agent.predict_next(neigh_last)
                # Sensor fires only if prediction is far from actual
                actual = predicted + 0.01 * RNG.standard_normal()
                error = abs(actual - predicted)
                event_fired = error > event_threshold
                if event_fired:
                    evt_events += 1
                agent.update_event_triggered(actual, event_fired)
                err = abs(agent.predicted_time - agent.target_time)
                evt_errors.append(err)

            evt_curve.append(np.mean(evt_errors))

        sim_first_curves.append(sim_curve)
        event_trig_curves.append(evt_curve)

    # Average over repeats
    sim_first_mean = np.mean(sim_first_curves, axis=0)
    sim_first_std = np.std(sim_first_curves, axis=0)
    event_trig_mean = np.mean(event_trig_curves, axis=0)
    event_trig_std = np.std(event_trig_curves, axis=0)

    return {
        'sim_first': {'mean': sim_first_mean, 'std': sim_first_std, 'curves': sim_first_curves},
        'event_trig': {'mean': event_trig_mean, 'std': event_trig_std, 'curves': event_trig_curves},
    }


def find_convergence_episode(curve, threshold=0.05):
    """Find the first episode where error drops below threshold."""
    for i, err in enumerate(curve):
        if err < threshold:
            return i
    return len(curve)  # never converged


def run_threshold_sweep():
    """Sweep the event-trigger threshold: does a lower threshold (more events)
    close the gap with simulation-first?"""
    thresholds = [0.01, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0]
    results = {}
    print("\nThreshold sweep (n_agents=20, n_episodes=200):")
    for thresh in thresholds:
        print(f"  threshold={thresh}:", end=" ", flush=True)
        r = run_experiment(n_agents=20, n_episodes=200, n_repeats=10, event_threshold=thresh)
        sim_conv = find_convergence_episode(r['sim_first']['mean'])
        evt_conv = find_convergence_episode(r['event_trig']['mean'])
        sim_final = r['sim_first']['mean'][-1]
        evt_final = r['event_trig']['mean'][-1]
        results[f'thresh_{thresh}'] = {
            'sim_first_convergence': int(sim_conv),
            'event_trig_convergence': int(evt_conv),
            'sim_first_final': float(sim_final),
            'event_trig_final': float(evt_final),
        }
        print(f"sim_conv={sim_conv} evt_conv={evt_conv} sim_final={sim_final:.4f} evt_final={evt_final:.4f}")
    return results


def plot_learning_curves(results, title_suffix=""):
    """Plot the learning curves: error vs. episode for both modes."""
    fig, ax = plt.subplots(figsize=(12, 7), constrained_layout=True)

    episodes = np.arange(len(results['sim_first']['mean']))
    sim_mean = results['sim_first']['mean']
    sim_std = results['sim_first']['std']
    evt_mean = results['event_trig']['mean']
    evt_std = results['event_trig']['std']

    ax.plot(episodes, sim_mean, color='#059669', linewidth=2.5, label='Simulation-first (sensors as confirmations)')
    ax.fill_between(episodes, sim_mean - sim_std, sim_mean + sim_std, color='#059669', alpha=0.2)

    ax.plot(episodes, evt_mean, color='#C2410C', linewidth=2.5, label='Event-triggered (react on events)')
    ax.fill_between(episodes, evt_mean - evt_std, evt_mean + evt_std, color='#C2410C', alpha=0.2)

    ax.axhline(y=0.05, color='gray', linestyle='--', alpha=0.5, label='Convergence threshold (0.05)')

    ax.set_xlabel('Episode')
    ax.set_ylabel('Mean absolute error from target')
    ax.set_title(f'H4 Experiment: Learning rate — simulation-first vs. event-triggered {title_suffix}')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.set_ylim(bottom=0)

    path = os.path.join(OUT_DIR, 'h4_learning_curves.png')
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Saved: {path}")


def plot_threshold_sweep(sweep_results):
    """Plot convergence episode vs. threshold."""
    thresholds = [float(k.split('_')[1]) for k in sweep_results.keys()]
    sim_conv = [sweep_results[k]['sim_first_convergence'] for k in sweep_results]
    evt_conv = [sweep_results[k]['event_trig_convergence'] for k in sweep_results]

    fig, ax = plt.subplots(figsize=(12, 7), constrained_layout=True)
    ax.plot(thresholds, sim_conv, 'o-', color='#059669', linewidth=2.5, markersize=8,
            label='Simulation-first (independent of threshold)')
    ax.plot(thresholds, evt_conv, 's-', color='#C2410C', linewidth=2.5, markersize=8,
            label='Event-triggered')

    ax.set_xlabel('Event-trigger threshold (lower = more events fired)')
    ax.set_ylabel('Episodes to convergence (error < 0.05)')
    ax.set_title('H4: Does lowering the event threshold close the gap?\n(If event-triggered catches up, the advantage is about event FREQUENCY, not mode)')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.set_xscale('log')

    path = os.path.join(OUT_DIR, 'h4_threshold_sweep.png')
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Saved: {path}")


if __name__ == '__main__':
    print("=" * 70)
    print("H4 Experiment: Learning rate — simulation-first vs. event-triggered")
    print("=" * 70)
    print("Task: N agents must 'play a note' at target_time=1.0")
    print("Measure: episodes to convergence (error < 0.05)")
    print("Hypothesis: simulation-first converges faster (verifier's rule)")
    print()

    # Main experiment
    print("Running main experiment (n_agents=20, n_episodes=200, n_repeats=20)...")
    results = run_experiment(n_agents=20, n_episodes=200, n_repeats=20, event_threshold=0.1)

    sim_conv = find_convergence_episode(results['sim_first']['mean'])
    evt_conv = find_convergence_episode(results['event_trig']['mean'])

    print(f"\nResults:")
    print(f"  Simulation-first convergence: episode {sim_conv}")
    print(f"  Event-triggered convergence: episode {evt_conv}")
    print(f"  Speedup: {evt_conv / max(sim_conv, 1):.2f}×")
    print(f"  Simulation-first final error: {results['sim_first']['mean'][-1]:.4f}")
    print(f"  Event-triggered final error: {results['event_trig']['mean'][-1]:.4f}")

    plot_learning_curves(results, title_suffix="(n_agents=20, threshold=0.1)")

    # Threshold sweep
    sweep = run_threshold_sweep()

    plot_threshold_sweep(sweep)

    # Save results
    def to_ser(obj):
        if isinstance(obj, (np.floating, np.integer)): return float(obj)
        if isinstance(obj, np.ndarray): return obj.tolist()
        return obj

    serializable = {
        'main_experiment': {
            'sim_first_mean': to_ser(results['sim_first']['mean']),
            'sim_first_std': to_ser(results['sim_first']['std']),
            'event_trig_mean': to_ser(results['event_trig']['mean']),
            'event_trig_std': to_ser(results['event_trig']['std']),
            'sim_first_convergence': int(sim_conv),
            'event_trig_convergence': int(evt_conv),
            'speedup': float(evt_conv / max(sim_conv, 1)),
        },
        'threshold_sweep': sweep,
    }

    with open(os.path.join(OUT_DIR, 'h4_results.json'), 'w') as f:
        json.dump(serializable, f, indent=2)
    print(f"\nSaved: {os.path.join(OUT_DIR, 'h4_results.json')}")

    print("\n" + "=" * 70)
    print("H4 SUMMARY")
    print("=" * 70)
    if sim_conv < evt_conv:
        print(f"✓ CONFIRMED: Simulation-first converges {evt_conv/max(sim_conv,1):.1f}× faster")
        print(f"  (episode {sim_conv} vs {evt_conv})")
        print(f"  This is evidence FOR Wei's verifier's rule in distributed systems.")
    else:
        print(f"✗ NOT CONFIRMED: Event-triggered converges faster or equally")
        print(f"  (sim={sim_conv}, evt={evt_conv})")
    print()
    print("Note: verifier's rule is a heuristic (Wei, July 2025), not a theorem.")
    print("This experiment tests whether the heuristic holds in this regime.")
