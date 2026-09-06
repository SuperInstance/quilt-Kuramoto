//! Exact integer square root.
//!
//! Nothing in this crate's own algebra needs a square root — that is the whole
//! point of comparing in squared form. But callers reporting a *magnitude* to a
//! human or a log do need one, and reaching for `f64::sqrt` at that moment
//! silently reintroduces the floating point the rest of the design removed.
//!
//! A survey of this ecosystem found no integer square root anywhere: every crate
//! advertising exact arithmetic falls back to `f64::sqrt()` when it needs a
//! magnitude, including at least one function named `is_pythagorean`. So this
//! module exists to remove the excuse.
//!
//! [`isqrt`] returns `⌊√n⌋` exactly, by Newton's method in integers. It is
//! `const`, allocation-free, and works on the full `u128` range.

/// Exact floor of the square root: the unique `r` with `r² ≤ n < (r+1)²`.
///
/// Newton's method on integers. Converges monotonically from above, so the loop
/// terminates for every input.
///
/// ```
/// # use exact_band::isqrt::isqrt;
/// assert_eq!(isqrt(0), 0);
/// assert_eq!(isqrt(24), 4);   // 4² = 16 ≤ 24 < 25 = 5²
/// assert_eq!(isqrt(25), 5);   // exact squares are exact
/// assert_eq!(isqrt(u128::MAX), (1u128 << 64) - 1);
/// ```
pub const fn isqrt(n: u128) -> u128 {
    if n < 2 { return n; }
    // Start at 2^⌈bits(n)/2⌉, which is ≥ √n, so the iteration descends.
    let bits = 128 - n.leading_zeros();
    let mut x = 1u128 << ((bits + 1) / 2);
    loop {
        let y = (x + n / x) / 2;
        if y >= x { return x; }
        x = y;
    }
}

/// Exact ceiling of the square root: the unique `r` with `(r-1)² < n ≤ r²`.
///
/// Useful for sizing a band soundly — you want to round *up*, never down, or the
/// band would understate the uncertainty.
///
/// ```
/// # use exact_band::isqrt::isqrt_ceil;
/// assert_eq!(isqrt_ceil(24), 5);   // 24 is not a square, so round up
/// assert_eq!(isqrt_ceil(25), 5);   // 25 is, so stay
/// ```
pub const fn isqrt_ceil(n: u128) -> u128 {
    let r = isqrt(n);
    if r * r == n { r } else { r + 1 }
}
