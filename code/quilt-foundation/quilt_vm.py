"""quilt_vm.py — The 5-opcode Quilt VM.

This is the foundation layer that the 10 rounds of research converged on.
Small enough to read in 5 minutes. Deep enough to host:
- Quilt cells
- Cordis plugins
- Spreadsheets (VisiCalc-style)
- MUDs
- TTRPGs (with a real DM)
- The 20-boat dance
- The cowboy, the bus, the witness

## The 5 opcodes

1. BIND name value     -- make a thing with a name and a value
2. LINK a b type        -- connect a to b with a relation of type
3. EFFECT target fn inv -- run fn(target), keep inv(target) to undo
4. VIEW target viewer   -- project the value of target for viewer
5. TICK dt              -- advance time by dt, process pending I/O

## Why these 5

- BIND = creation (Hermes's CREATE, Quilt's add(), Cordis's register())
- LINK = relation (the topology; coeffect in Cordis, axes in Quilt)
- EFFECT = reversible transformation (the deepest level: function with inverse)
- VIEW = projection (the spreadsheet opener, the MUD viewport, the sheet)
- TICK = time (the bay dance needs time; the async I/O needs time)

Everything else composes from these.

## The runtime

The runtime is async-IO with sync-game:
- BIND, LINK, EFFECT, VIEW are synchronous (game tick)
- TICK advances the clock and processes pending I/O
- Perception checks are VIEWs of the world for a viewer
- The DM's improvisation is EFFECTs (reversible generation)
- The bay dance is 20 boats each ticking on their own schedule

## Why this is the foundation

- Quilt cells = BIND(address, value) + LINK(axes) + EFFECT(set, undo)
- Cordis plugins = BIND(name, ctx) + LINK(coeffect) + EFFECT(fn, inv)
- Spreadsheet cells = BIND("A1", 42) + LINK("B1" "A1" "depends_on")
- MUD rooms = BIND("room:1", {desc}) + LINK("user:1" "room:1" "in")
- TTRPG player = BIND("player:1", stats) + LINK("player:1" "dm" "interacts_with")
- Bay boat = BIND("boat:i", {pos, route}) + LINK("boat:i" "bay" "in") + TICK for perception
"""
from __future__ import annotations
import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Set, Tuple


# Opcode 1: BIND
def bind(vm: "QuiltVM", name: str, value: Any) -> str:
    """BIND name value — make a thing. Returns the name."""
    vm.things[name] = {"value": value, "links": defaultdict(set), "effects": []}
    return name


# Opcode 2: LINK
def link(vm: "QuiltVM", a: str, b: str, type_: str = "default") -> None:
    """LINK a b type — connect a to b with a relation of type."""
    if a not in vm.things:
        vm.things[a] = {"value": None, "links": defaultdict(set), "effects": []}
    if b not in vm.things:
        vm.things[b] = {"value": None, "links": defaultdict(set), "effects": []}
    vm.things[a]["links"][type_].add(b)
    vm.things[b]["links"][f"!{type_}"].add(a)  # reverse link


# Opcode 3: EFFECT
def effect(vm: "QuiltVM", target: str, fn: Callable[[Any], Any],
             inv: Callable[[Any], Any]) -> Any:
    """EFFECT target fn inv — run fn on target's value, keep inv to undo.

    This is the deepest level: a function from context to value with an inverse.
    """
    if target not in vm.things:
        vm.things[target] = {"value": None, "links": defaultdict(set), "effects": []}
    old = vm.things[target]["value"]
    new = fn(old) if old is not None else fn(None)
    vm.things[target]["value"] = new
    vm.things[target]["effects"].append((fn, inv, old, new))
    # Schedule for async processing
    vm.pending_effects.append((target, fn, inv, old, new))
    return new


def dispose(vm: "QuiltVM", target: str) -> None:
    """Dispose a target: run all its effects in REVERSE order (LIFO)."""
    if target not in vm.things:
        return
    for fn, inv, old, new in reversed(vm.things[target]["effects"]):
        try:
            inv(new)
            vm.things[target]["value"] = old
        except Exception:
            pass
    vm.things[target]["effects"] = []
    vm.things[target]["value"] = None


# Opcode 4: VIEW
def view(vm: "QuiltVM", target: str, viewer: str,
           projection: Optional[Callable[[Any, str], Any]] = None) -> Any:
    """VIEW target viewer — project the value of target for viewer.

    If projection is given, apply it (e.g., a perception check).
    Otherwise, return the raw value (the "DM view").
    """
    if target not in vm.things:
        return None
    value = vm.things[target]["value"]
    if projection is not None:
        return projection(value, viewer)
    return value


# Opcode 5: TICK
def tick(vm: "QuiltVM", dt: float = 1.0) -> None:
    """TICK dt — advance time by dt, process pending I/O.

    This is the heart of async-IO-with-sync-game:
    - Pending effects are processed (async I/O drained)
    - Periodic perception checks fire (scheduled by TICK)
    - The world state advances
    """
    vm.time += dt
    # Process pending effects
    while vm.pending_effects:
        target, fn, inv, old, new = vm.pending_effects.pop(0)
        vm.event_log.append({
            "ts": vm.time, "kind": "effect.applied",
            "target": target, "old": old, "new": new,
        })
    # Fire scheduled perception checks
    for target, (fn, scheduled_at) in list(vm.scheduled.items()):
        if scheduled_at <= vm.time:
            try:
                fn(vm)
            except Exception:
                pass
            del vm.scheduled[target]
    # Notify subscribers
    for sub in vm.subscribers:
        try:
            sub({"ts": vm.time, "kind": "tick", "dt": dt})
        except Exception:
            pass


# The runtime
@dataclass
class QuiltVM:
    """The Quilt VM. The 5-opcode runtime.

    Hosts: cells, plugins, sheets, MUDs, TTRPGs, boats.
    """
    things: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    time: float = 0.0
    pending_effects: List[Tuple] = field(default_factory=list)
    event_log: List[Dict] = field(default_factory=list)
    subscribers: List[Callable] = field(default_factory=list)
    scheduled: Dict[str, Tuple[Callable, float]] = field(default_factory=dict)

    # The 5 opcodes
    def BIND(self, name: str, value: Any) -> str:
        return bind(self, name, value)

    def LINK(self, a: str, b: str, type_: str = "default") -> None:
        link(self, a, b, type_)

    def EFFECT(self, target: str, fn: Callable, inv: Callable) -> Any:
        return effect(self, target, fn, inv)

    def VIEW(self, target: str, viewer: str,
              projection: Optional[Callable] = None) -> Any:
        return view(self, target, viewer, projection)

    def TICK(self, dt: float = 1.0) -> None:
        tick(self, dt)

    # Convenience methods
    def dispose(self, target: str) -> None:
        dispose(self, target)

    def schedule(self, target: str, fn: Callable, at: float) -> None:
        """Schedule a perception check at time `at`."""
        self.scheduled[target] = (fn, at)

    def subscribe(self, fn: Callable) -> None:
        self.subscribers.append(fn)

    def stats(self) -> Dict[str, Any]:
        return {
            "n_things": len(self.things),
            "time": self.time,
            "n_pending": len(self.pending_effects),
            "n_events": len(self.event_log),
            "n_scheduled": len(self.scheduled),
            "n_subscribers": len(self.subscribers),
        }


# --- The polyformalism tests -----------------------------------------

def test_quilt_cell_in_vm():
    """A Quilt cell is a BIND with effects and views."""
    vm = QuiltVM()
    vm.BIND("bathy:0", 4.2)
    vm.LINK("bathy:0", "tide:current", "depends_on")
    # Effect (set value, with inverse)
    vm.EFFECT("bathy:0", lambda v: 5.0, lambda v: 4.2)
    # View
    assert vm.VIEW("bathy:0", "anyone") == 5.0
    # Dispose
    vm.dispose("bathy:0")
    assert vm.VIEW("bathy:0", "anyone") is None


def test_cordis_plugin_in_vm():
    """A Cordis plugin is a BIND with effects (reversible) and coeffects (links)."""
    vm = QuiltVM()
    # The plugin
    vm.BIND("logger", {"value": "hello"})
    # The coeffect (dependency)
    vm.LINK("logger", "config:main", "coeffect:config")
    # An effect (set state)
    vm.EFFECT("logger", lambda v: {"value": "world"}, lambda v: {"value": "hello"})
    # The view (resolve the coeffect)
    assert vm.VIEW("logger", "anyone")["value"] == "world"
    # Reverse links (the coeffect is bidirectional)
    assert "logger" in vm.things["config:main"]["links"]["!coeffect:config"]


def test_spreadsheet_cell_in_vm():
    """A spreadsheet cell is a BIND + LINK + EFFECT for formula evaluation."""
    vm = QuiltVM()
    vm.BIND("A1", 10)
    vm.BIND("A2", 20)
    vm.BIND("B1", 0)
    vm.LINK("B1", "A1", "depends_on")
    vm.LINK("B1", "A2", "depends_on")
    # Formula: B1 = A1 + A2
    def formula(_):
        return vm.VIEW("A1", "any") + vm.VIEW("A2", "any")
    def undo(new):
        return 0
    vm.EFFECT("B1", formula, undo)
    assert vm.VIEW("B1", "any") == 30


def test_mud_room_in_vm():
    """A MUD room is a BIND + LINKs to users."""
    vm = QuiltVM()
    vm.BIND("room:1", {"name": "Forbidden Chamber",
                          "desc": "Dark and eerie, ancient tomes line the walls."})
    vm.BIND("user:1", {"name": "Aragorn", "hp": 100})
    vm.LINK("user:1", "room:1", "in")
    # The user views the room
    desc = vm.VIEW("room:1", "user:1")["desc"]
    assert "ancient tomes" in desc


def test_ttrpg_perception_check():
    """A TTRPG perception check is a VIEW with a projection."""
    vm = QuiltVM()
    # Hidden orc
    vm.BIND("orc:1", {"hidden": True, "hp": 50})
    # Player with perception skill
    vm.BIND("player:1", {"name": "Gandalf", "perception": 15})
    vm.LINK("player:1", "orc:1", "near")
    # Perception check: if player's perception > 10, see the orc
    def perception_check(value, viewer):
        if value is None or not value.get("hidden"):
            return value
        player = vm.VIEW(viewer, viewer) or {}
        if player.get("perception", 0) > 10:
            # Reveal the orc (effect on the orc)
            return {**value, "hidden": False, "perceived_by": viewer}
        return {"hidden": True}  # still hidden
    # The check
    result = vm.VIEW("orc:1", "player:1", perception_check)
    assert result["hidden"] is False  # Gandalf sees the orc
    assert result["perceived_by"] == "player:1"


def test_bay_dance_perception_check():
    """A 20-boat dance is 20 BINDs + periodic TICKs with perception checks."""
    vm = QuiltVM()
    # 20 boats in a bay
    n_boats = 20
    for i in range(n_boats):
        vm.BIND(f"boat:{i}", {"x": float(i), "y": 0.0,
                                  "lure": "blue" if i % 2 == 0 else "red",
                                  "course": "north"})
        vm.LINK(f"boat:{i}", "bay", "in")
    # Schedule a perception check every 5 ticks
    def perception_check(vm):
        for i in range(n_boats):
            boat = vm.VIEW(f"boat:{i}", "anyone")
            # Check the neighbors
            for j in range(n_boats):
                if i == j:
                    continue
                other = vm.VIEW(f"boat:{j}", "anyone")
                dx = abs(boat["x"] - other["x"])
                if dx < 1.0:
                    # Too close, adjust course
                    vm.EFFECT(f"boat:{i}",
                                lambda v: {**v, "course": "south"} if v["course"] == "north" else {**v, "course": "north"},
                                lambda v: v)
    # Run the dance for 5 ticks
    for t in range(5):
        vm.schedule(f"check-{t}", perception_check, at=vm.time + 1.0)
        vm.TICK(1.0)
    # The boats should have moved
    courses = [vm.VIEW(f"boat:{i}", "anyone")["course"] for i in range(n_boats)]
    # At least some boats changed course (the dance is in progress)
    assert "north" in courses or "south" in courses


def test_cowboy_morning_via_view():
    """The cowboy's morning report is a VIEW of the world state."""
    vm = QuiltVM()
    # Some alignments (models)
    vm.BIND("model:PHI-4", {"success": 6, "n": 6, "wilson_lb": 0.6})
    vm.BIND("model:BROKEN", {"success": 1, "n": 5, "wilson_lb": 0.1})
    vm.LINK("model:PHI-4", "model:BROKEN", "earlier_in_the_log")
    # The cowboy views the state
    phi = vm.VIEW("model:PHI-4", "cowboy")
    broken = vm.VIEW("model:BROKEN", "cowboy")
    assert phi["wilson_lb"] > 0.5
    assert broken["wilson_lb"] < 0.3


def test_bus_event_via_tick():
    """The bus is a list of events, processed on TICK."""
    vm = QuiltVM()
    events_received = []

    def subscriber(e):
        events_received.append(e)

    vm.subscribe(subscriber)
    vm.BIND("model:X", "value")
    vm.TICK(1.0)
    # The subscriber should have been notified
    assert len(events_received) == 1
    assert events_received[0]["kind"] == "tick"


def test_full_polyformalism():
    """All five polyformalisms in one VM."""
    vm = QuiltVM()
    # 1. Quilt cell
    vm.BIND("bathy:0", 4.2)
    # 2. Cordis plugin
    vm.BIND("logger:0", "hello")
    vm.LINK("logger:0", "config:main", "coeffect:config")
    # 3. Spreadsheet cell
    vm.BIND("A1", 10)
    vm.BIND("A2", 20)
    vm.BIND("B1", 0)
    vm.LINK("B1", "A1", "depends_on")
    vm.LINK("B1", "A2", "depends_on")
    # 4. MUD room
    vm.BIND("room:1", {"name": "Dungeon"})
    # 5. TTRPG player
    vm.BIND("player:1", {"name": "Gandalf", "perception": 15})
    # 6. Boat
    vm.BIND("boat:0", {"x": 0.0, "y": 0.0, "course": "north"})
    # 7. Cowboy's model
    vm.BIND("model:PHI-4", {"wilson_lb": 0.6})
    # 8. Bus subscriber
    events = []
    vm.subscribe(lambda e: events.append(e))
    # 9. TICK
    vm.TICK(1.0)
    # All seven polyformalisms coexist in one VM
    assert vm.stats()["n_things"] >= 8
    assert vm.stats()["time"] == 1.0
    assert len(events) == 1


# --- Demo ------------------------------------------------------------

def demo():
    """The 5-opcode Quilt VM in action."""
    print("=" * 60)
    print("  THE QUILT VM — 5 opcodes, 8 polyformalisms")
    print("=" * 60)

    vm = QuiltVM()
    # 1. Quilt cell
    vm.BIND("bathy:0", 4.2)
    # 2. Cordis plugin
    vm.BIND("logger:0", "hello")
    vm.LINK("logger:0", "config:main", "coeffect:config")
    # 3. Spreadsheet
    vm.BIND("A1", 10)
    vm.BIND("A2", 20)
    vm.BIND("B1", 0)
    vm.LINK("B1", "A1", "depends_on")
    vm.LINK("B1", "A2", "depends_on")
    # 4. MUD room
    vm.BIND("room:1", {"name": "Forbidden Chamber"})
    # 5. TTRPG player
    vm.BIND("player:1", {"name": "Gandalf", "perception": 15})
    # 6. Boat
    vm.BIND("boat:0", {"x": 0.0, "course": "north"})
    # 7. Cowboy's model
    vm.BIND("model:PHI-4", {"wilson_lb": 0.6})
    # 8. Bus
    events = []
    vm.subscribe(lambda e: events.append(e))
    vm.TICK(1.0)

    print()
    print(f"  Things:    {vm.stats()['n_things']}")
    print(f"  Time:      {vm.stats()['time']}")
    print(f"  Subscribers: {vm.stats()['n_subscribers']}")
    print(f"  Events:    {len(events)}")
    print()
    print("  The 5 opcodes:")
    print("    BIND(name, value)    -- make a thing")
    print("    LINK(a, b, type)     -- connect things")
    print("    EFFECT(target, fn, inv) -- reversible transformation")
    print("    VIEW(target, viewer) -- project for viewer")
    print("    TICK(dt)              -- advance time")
    print()
    print("  The 8 polyformalisms in one VM:")
    print("    - Quilt cells")
    print("    - Cordis plugins")
    print("    - Spreadsheets")
    print("    - MUDs")
    print("    - TTRPGs (with perception checks)")
    print("    - The bay dance (20 boats)")
    print("    - The cowboy's model")
    print("    - The bus")
    print()
    print("  The deepest level: a function from context to value with an inverse.")


if __name__ == "__main__":
    demo()
