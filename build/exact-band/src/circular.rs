//! Exact phase on a discrete circle.
//!
//! A heading, a beat position, an oscillator phase — all live on a circle, and a
//! squared difference gets them wrong: it judges 359° and 1° to be 358 apart
//! rather than 2. Both `quilt-esp32` and `cocapn-marine` work around this by
//! hand today.
//!
//! [`Phase`] puts the phase on `ℤ/N` — `N` equally spaced slots — where the
//! distance is `min(d, N−d)`, exact in integers, and wraparound is arithmetic
//! rather than a special case.
//!
//! ## Why a discrete circle rather than a float angle
//!
//! Two oscillators **collide** when they occupy the same phase. In floating
//! point that is not a decidable question — you compare against an epsilon and
//! hope. On `ℤ/N` it is exact equality, so a collision is a fact, not a
//! judgement call. That matters because the phase-locking criterion for
//! discrete-time Kuramoto oscillators is stated in terms of *finitely many
//! collisions*, and a criterion you cannot decide is not a criterion.

/// A phase on the discrete circle `ℤ/N`.
///
/// `N` is the number of slots — 360 for whole degrees, 3_600_000 for
/// micro-degrees, 96 for a bar of 24 beats at 1/4-beat resolution.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash)]
pub struct Phase<const N: u32> {
    slot: u32,
}

impl<const N: u32> Phase<N> {
    /// The number of slots on this circle.
    pub const SLOTS: u32 = N;

    /// A phase, reduced into `[0, N)`.
    #[inline]
    pub const fn new(slot: i64) -> Self {
        let n = N as i64;
        let mut r = slot % n;
        if r < 0 { r += n; }
        Self { slot: r as u32 }
    }

    /// The slot index, always in `[0, N)`.
    #[inline]
    pub const fn slot(self) -> u32 { self.slot }

    /// Advance by a signed amount, wrapping exactly.
    #[inline]
    pub const fn advance(self, by: i64) -> Self {
        Self::new(self.slot as i64 + by)
    }

    /// Shortest distance around the circle: `min(d, N − d)`.
    ///
    /// Always in `[0, N/2]`. This is the metric a heading deadband actually
    /// wants, and the one a squared difference gets wrong at the wrap point.
    #[inline]
    // Clippy suggests `a.abs_diff(b)`, which is clearer -- but this is a `const
    // fn` and `u32::abs_diff` only became usable in const context in Rust 1.87,
    // well past this crate's declared MSRV of 1.70. The manual form stays until
    // the MSRV moves. Only one toolchain is installed here, so this is a reason
    // from the stabilisation record, not from a build that was run against 1.70.
    #[allow(clippy::manual_abs_diff)]
    pub const fn distance(self, other: Self) -> u32 {
        let a = self.slot;
        let b = other.slot;
        let d = if a > b { a - b } else { b - a };
        let around = N - d;
        if d < around { d } else { around }
    }

    /// Signed shortest offset from `self` to `other`.
    ///
    /// Positive means `other` is ahead. The magnitude always equals
    /// [`distance`](Self::distance). This is the exact analogue of the
    /// `sin(θ_j − θ_i)` term's *sign and magnitude* without any trigonometry.
    ///
    /// The range is `(−N/2, N/2]` for even `N` and `[−(N−1)/2, (N−1)/2]` for
    /// odd `N`.
    ///
    /// `d` is **normalised into `[0, N)` first**, and that normalisation is the
    /// whole correctness argument. An earlier version left `d` in `(−N, N)` and
    /// folded it with two truncating comparisons — and on an odd circle the
    /// second undid the first, returning the long way round:
    ///
    /// ```text
    ///     if d >  n / 2 { d -= n }    // N=7, d=4:   4 >  3  ⇒  d = −3
    ///     if d <= -n / 2 { d += n }   //            −3 ≤ −3  ⇒  d = +4
    /// ```
    ///
    /// Once `d` is in `[0, N)`, a single comparison suffices, and `2·d > n` and
    /// `d > n / 2` are equivalent for *every* `N` — for odd `N`,
    /// `d > (N−1)/2` ⟺ `2d ≥ N` ⟺ (`2d` even, `N` odd) `2d > N`. So the doubled
    /// form below is a clarity choice, not the fix; the C port's
    /// `test_phase_negative_control` asserts that equivalence over eleven rings
    /// rather than leaving it as a claim.
    #[inline]
    pub const fn offset_to(self, other: Self) -> i64 {
        let n = N as i64;
        // slots are already reduced into [0, N), so this difference is in (−N, N)
        let mut d = other.slot as i64 - self.slot as i64;
        if d < 0 { d += n; }
        if 2 * d > n { d -= n; }
        d
    }

    /// Do two phases occupy the same slot? Exact equality — a decidable
    /// collision, which is the point of a discrete circle.
    #[inline]
    pub const fn collides_with(self, other: Self) -> bool {
        self.slot == other.slot
    }

    /// Is `other` within `tolerance` slots, measured the short way round?
    #[inline]
    pub const fn within(self, other: Self, tolerance: u32) -> bool {
        self.distance(other) <= tolerance
    }
}

impl<const N: u32> Default for Phase<N> {
    fn default() -> Self { Self { slot: 0 } }
}

/// A whole-degree heading, `ℤ/360`.
pub type Heading = Phase<360>;
