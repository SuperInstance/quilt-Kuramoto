"""A countdown that fires on **knowledge**, not on a head-count.

`swarm-tminus`'s `CountdownEvent` fires when `confirmed_count() >=
quorum_required` — a count. That treats three vague confirmations as better than
one precise one, which is backwards.

`BandedCountdown` fires when the accumulated band has narrowed past a target
width. Each confirmation carries an actual observation, and observations
intersect: agreement tightens the band, and disagreement is recorded with its
magnitude rather than being silently dropped.

Composition, not inheritance: this **wraps** a real `CountdownEvent` and leaves
it untouched, so existing `.swarm/*.json` files stay loadable and existing code
keeps working. The band lives in the event's own free-form `payload` dict, which
the upstream schema already provides.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from .band import IBox

__all__ = ["BandedCountdown", "Report", "FireReason"]


@dataclass(frozen=True)
class Report:
    """What one subscriber actually claimed, and what it did to the band."""

    subscriber_id: str
    observation: IBox
    accepted: bool
    """False when the observation contradicted the band (disjoint)."""
    disagreement: Optional[tuple[int, int]] = None
    """`(axis, gap)` when it contradicted — where, and by how much."""


class FireReason:
    """Why an event is or is not ready."""

    KNOWN_ENOUGH = "known_enough"
    TOO_WIDE = "band_too_wide"
    TOO_FEW_REPORTERS = "too_few_reporters"
    CONTRADICTED = "contradicted"


@dataclass
class BandedCountdown:
    """A countdown gated on how much is known, with a floor on who said so.

    Firing requires **both**:

    1. the band is at least as tight as `target_width`, and
    2. at least `min_reporters` distinct subscribers have been accepted.

    Condition (2) is a Byzantine floor, not the primary gate. Without it a single
    subscriber reporting an implausibly narrow band could fire the event alone —
    knowledge is the gate, reporter count is the guard rail. It is quorum
    returning through the back door, and that is deliberate: quorum was never
    wrong about *that* job, only about being the whole rule.
    """

    name: str
    band: IBox
    target_width: int
    min_reporters: int = 2
    stale_widen_per_tick: int = 0
    """How much the band relaxes on a tick with no accepted report.

    Intersection only ever narrows, so a long-running event will converge to a
    point and then reject a later, correct observation — the over-confidence
    trap. A positive value here is the least-machinery cure: the band forgets at
    a fixed integer rate, which keeps every operation exact. Zero disables it.
    """

    reports: list[Report] = field(default_factory=list)
    contradicted: bool = False

    # ---- reporting ------------------------------------------------------

    def confirm(self, subscriber_id: str, observation: IBox) -> Report:
        """Fold one subscriber's observation into the band.

        Agreement narrows. Disagreement is **not** folded in — intersecting a
        disjoint box would empty the band and destroy what we already knew — but
        it is recorded, and it blocks firing until the band widens enough to
        accommodate it or the subscriber reports again.
        """
        narrowed = self.band.narrow(observation)
        if narrowed is None:
            rep = Report(subscriber_id, observation, accepted=False,
                         disagreement=self.band.disagreement(observation))
            self.contradicted = True
        else:
            self.band = narrowed
            rep = Report(subscriber_id, observation, accepted=True)
            # A fresh agreeing report clears a prior contradiction only if the
            # band can now accommodate every previously contradicting claim.
            if self.contradicted and self._all_contradictions_resolved():
                self.contradicted = False
        self.reports.append(rep)
        return rep

    def _all_contradictions_resolved(self) -> bool:
        return all(self.band.narrow(r.observation) is not None
                   for r in self.reports if not r.accepted)

    def tick(self) -> None:
        """Advance one tick with no new information: the band forgets a little."""
        if self.stale_widen_per_tick:
            self.band = self.band.widen(self.stale_widen_per_tick)
            if self.contradicted and self._all_contradictions_resolved():
                self.contradicted = False

    # ---- interrogation ---------------------------------------------------

    def accepted_reporters(self) -> set[str]:
        return {r.subscriber_id for r in self.reports if r.accepted}

    def ready(self) -> tuple[bool, str]:
        """Is the event ready to fire, and if not, why not?"""
        if self.contradicted:
            return False, FireReason.CONTRADICTED
        width = self.band.max_width()
        if width is None:
            return False, FireReason.CONTRADICTED
        if len(self.accepted_reporters()) < self.min_reporters:
            return False, FireReason.TOO_FEW_REPORTERS
        if width > self.target_width:
            return False, FireReason.TOO_WIDE
        return True, FireReason.KNOWN_ENOUGH

    def contradictions(self) -> list[Report]:
        """Every report that disagreed, with where and by how much."""
        return [r for r in self.reports if not r.accepted]

    # ---- swarm-tminus interop -------------------------------------------

    def to_payload(self) -> dict:
        """Serialise into a `CountdownEvent.payload` dict.

        Uses the upstream schema's existing free-form `payload` field, so no
        change to `.swarm/*.event.json` is needed and old readers ignore it.
        """
        return {
            "band": {"lo": list(self.band.lo), "hi": list(self.band.hi)},
            "target_width": self.target_width,
            "min_reporters": self.min_reporters,
            "stale_widen_per_tick": self.stale_widen_per_tick,
            "contradicted": self.contradicted,
            "reports": [
                {"subscriber_id": r.subscriber_id,
                 "lo": list(r.observation.lo), "hi": list(r.observation.hi),
                 "accepted": r.accepted,
                 "disagreement": list(r.disagreement) if r.disagreement else None}
                for r in self.reports
            ],
        }

    @classmethod
    def from_payload(cls, name: str, payload: dict) -> "BandedCountdown":
        """Rebuild from a `CountdownEvent.payload` dict."""
        b = payload["band"]
        ev = cls(
            name=name,
            band=IBox(tuple(b["lo"]), tuple(b["hi"])),
            target_width=payload["target_width"],
            min_reporters=payload.get("min_reporters", 2),
            stale_widen_per_tick=payload.get("stale_widen_per_tick", 0),
            contradicted=payload.get("contradicted", False),
        )
        for r in payload.get("reports", []):
            ev.reports.append(Report(
                subscriber_id=r["subscriber_id"],
                observation=IBox(tuple(r["lo"]), tuple(r["hi"])),
                accepted=r["accepted"],
                disagreement=tuple(r["disagreement"]) if r.get("disagreement") else None,
            ))
        return ev

    def attach_to(self, event) -> None:
        """Write this band into a live `swarm_tminus.events.CountdownEvent`.

        Also mirrors the band verdict onto the upstream event so existing
        count-based tooling still sees something sensible: each accepted
        reporter is confirmed upstream, each contradicting one is marked
        `DEFERRED` — the upstream status that holds an event open.
        """
        from swarm_tminus.events import SubscriberStatus

        event.payload["banded"] = self.to_payload()
        for r in self.reports:
            event.add_subscriber(r.subscriber_id)
            event.confirm(r.subscriber_id,
                          SubscriberStatus.CONFIRMED if r.accepted
                          else SubscriberStatus.DEFERRED)
