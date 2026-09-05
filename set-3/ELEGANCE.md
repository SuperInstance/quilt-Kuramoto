# ELEGANCE — the five heaviest equations, reduced

**Lane:** rigor-auditor (Flash — elegance pass) · **Date:** 2026-08-29
**Rule:** the short form must be *derivable from the long form* — each reduction below carries its full derivation. Nothing is simplified by hand-waving; what cancels, cancels for a stated algebraic reason. Each entry ends with the one-line version a deck engineer can say at the bar.

---

## E1 — Ledger conservation induction

**Long form (FOUNDATION F-T1, full version in BRIDGES B1).** For any cut 𝒞 and commit-boundary time t:

```
K_𝒞(t) = K_𝒞(0) + Σ_{T : applied by t} v_T^𝒞 ,   v_T^𝒞 := Σ_{(a,v) ∈ T, owner(a) ∈ 𝒞} v
```

proved by induction over the (well-founded) global commit partial order, with three cases: internal / crossing / other.

**Derivation — what cancels.** Expand the induction step into one line:

```
ΔK_𝒞 = Σ_{(a,v) ∈ T} v · [owner(a) ∈ 𝒞]
```

- **Internal T:** every posting is owned in 𝒞, so the indicator is 1 everywhere: `ΔK_𝒞 = Σ_{(a,v) ∈ T} v = 0` — **balance kills it.** This is the entire cancellation: the cut's indicator function and the transaction's own sum collapse into the transaction's defining identity `Σvᵢ = 0`.
- **Crossing T:** only the 𝒞-side postings survive: `ΔK_𝒞 = v_T^𝒞`, and it accrues exactly once per nonce (idempotence kills the replay).
- **Everything else (tick, view):** no account touched, `ΔK_𝒞 = 0`.

Sum over transactions: the induction collapses to the closed form. The three-case induction in B1 is exactly this expansion, done carefully; the elegance is that the whole theorem is the identity `Σvᵢ = 0` wearing an indicator function.

**Shortest form:**

```
ΔK_𝒞 = Σ_T (Σ_{(a,v) ∈ T} v) · 𝟙[internal-or-𝒞-side] = Σ_{T crossing 𝒞} v_T^𝒞
```

**One line (bar):** *"Internal transactions can't move the cut; crossing ones move it exactly once, by exactly the side they land on — and in-flight is a count, not a surprise."*

---

## E2 — Freshness composition along a chain of views

**Long form (FOUNDATION F-D4 is single-view; the chain law is derived here).** Chain of k views: observer → C₁ → … → C_k = source, link i with bounds (Fᵢ, Lᵢ): response delivered at dᵢ within Lᵢ of issue at tᵢ; the value is the cell's state committed at cᵢ with dᵢ − Fᵢ ≤ cᵢ ≤ dᵢ. Content age = age, at the observer's delivery d₁, of the source state the value ultimately carries.

**Derivation — what cancels.** Telescoping is the whole trick. Let c_k be the source commit carried by the final response, and d_{i+1} the delivery of the next link's response (the one whose content the i-th response carries):

```
d₁ − c_k = (d₁ − d_k) + (d_k − c_k)
         ≤ Σ_{i=1..k−1} (dᵢ − d_{i+1}) + F_k      each hop: dᵢ ≤ tᵢ + Lᵢ and d_{i+1} ≥ tᵢ  ⟹  dᵢ − d_{i+1} ≤ Lᵢ
         ≤ Σ_{i=1..k−1} Lᵢ + F_k                   (d_k − c_k) ≤ F_k by the source link's staleness bound
```

**What cancels (the surprise):** the *intermediate* staleness allowances F₁ … F_{k−1} vanish from the content-age bound. Each intermediate's Fᵢ bounds the age of its *own served state*; but the content the observer sees is anchored at the *source's* commit c_k, and the delivery chain telescopes through the latencies alone. A chain of cells that re-commits on receipt pays only the source's F plus the sum of the L's. (If an intermediate serves stale cached content, the honest general bound is `Σ_{i≤k} Fᵢ + Σ_{i<k} Lᵢ` — every F adds; the designed-in refresh discipline is exactly what buys the cancellation, and it is what the fabric's run-to-completion, re-render-per-event core does.)

**Shortest form:**

```
age ≤ F_source + Σ hops L ,   spacing_illusion > F_source + Σ L + L₁
```

(k = 1 recovers D4 exactly: age ≤ F, spacing > F + L.)

**One line (bar):** *"Staleness doesn't compound down a chain of fresh eyes: only the source's F and the sum of the hop latencies survive."*

---

## E3 — The covering inequality b√n/2 ≤ ε

**Long form (SEMANTIC-TOWER S-T3, proof in BRIDGES B7).** Integer representation in basis b suffices for tolerance ε iff every reachable true value lies within ε of the lattice b·ℤⁿ; the covering radius of b·ℤⁿ is b√n/2; the design condition is b ≤ 2ε/√n.

**Derivation — what cancels.** Place x in the fundamental cell `[0,b)ⁿ` (translation mod b·ℤⁿ doesn't change the distance to the lattice). The nearest lattice point is a cube corner; the farthest point from the corner set is the cell center `(b/2, …, b/2)`:

```
dist(x, b·ℤⁿ) ≤ ‖(b/2,…,b/2) − 0‖ = √(n · (b/2)²) = (b/2)·√n = b√n/2
```

What cancels: the **2** (half a cube edge — the corner is b/2 from the center along each axis) and the **√n** (the cube diagonal, Pythagoras in n dimensions). Nothing else is in the formula; the entire inequality is one Pythagorean step plus the observation that the center is the worst point. Demanding `b√n/2 ≤ ε` and rearranging:

```
b√n/2 ≤ ε  ⟺  b ≤ 2ε/√n
```

(1-D: b ≤ 2ε — half the spacing inside the tolerance. Necessity: the center is exactly b√n/2 from every lattice point, so a larger b leaves some reachable value farther than ε — the condition is tight.)

**Shortest form:**

```
covering radius(b·ℤⁿ) = b√n/2   ⇒   b ≤ 2ε/√n
```

**One line (bar):** *"The worst a lattice lies is half its cube's diagonal — set ε there and integers suffice, and can't do better."*

---

## E4 — The ladder 2× bound

**Long form (ABSTRACTION-MATH §5.1 staircase envelope theorem, base b = 2).** Cofire ages bucketed at `[2^i·H, 2^{i+1}·H)`, bucket i carries implied weight 2^{−i}; readout Ŵ = Σᵢ Cᵢ·2^{−i}; true weight W = Σ w(age) for the exponential law w(a) = 2^{−a/H}:

```
W ≤ Ŵ < 2W
```

**Derivation — what cancels.** One line: a cofire of age in bucket i has true weight w(a) with a ∈ [2^i H, 2^{i+1} H), so `w(a) ∈ (2^{−(i+1)}, 2^{−i}]` — the assigned weight 2^{−i} overstates the true weight by a factor in [1, 2). Summing over cofires: the overstatement factors add (they all overstate in the same direction), giving Ŵ ∈ [W, 2W). What cancels: the *boundary ambiguity* — a cofire sitting exactly at a bucket boundary (age = 2^{i+1}H) is in the higher bucket with weight 2^{−i}, overstating by exactly the factor 2; every other position overstates by less. The factor-2 envelope *is* the coarseness of one bucket of age, nothing more. (Power laws w(a) = (H/a)^k are exact on shift ladders — bucket weights b^{−ik} remain shifts — which is why the hyperbola and the ladder are one engine with a dial.)

**The SYNTHESIS Q3 integer form, tightened.** SYNTHESIS asserts `W_exact/2 − 1 ≤ Ŵ ≤ 2·W_exact + 1`. From the envelope `W ≤ Ŵ ≤ 2W` (real), integer Ŵ satisfies `ceil(W) ≤ Ŵ ≤ floor(2W)`… and the asserted bounds follow trivially: `W/2 − 1 ≤ W ≤ Ŵ` and `Ŵ ≤ 2W ≤ 2W + 1`. **The ±1 is pure integer slack, and the /2 on the lower side is fourfold looseness — the testbench assertion can be tightened to `W − 1 ≤ Ŵ ≤ 2W + 1` without touching a line of RTL**, because the envelope theorem says Ŵ ≥ W, not Ŵ ≥ W/2.

**Shortest form:**

```
W ≤ Ŵ < 2W   —   the envelope is exactly one bucket of age
```

**One line (bar):** *"A cofire is never more than one bucket of age from its weight: the ladder reads between the truth and twice the truth."*

---

## E5 — Snap-debt accounting

**Long form (the leap L1, as written in SEMANTIC-TOWER §5.4):**

```
T_snap(n): {(G:authority-on-x, −1), (T:authority-on-x, +1), (G:snap-debt, +|g−s|)}   Σ = |g−s| ≠ 0  ✗
```

unbalanced — it breaks F-D3's `Σvᵢ = 0` and every cut invariant it powers. **Fixed form (BRIDGES B9):**

```
T_snap(n): {(G:authority-on-x, −1), (T:authority-on-x, +1), (G:snap-debt, +|g−s|), (T:ground-truth, −|g−s|)}   Σ = 0  ✓
```

**Derivation — what cancels.** Balance is a hard constraint; the drift magnitude |g−s| is real value that must be booked. Split the transaction into its two natural pairs:

```
authority swap:  (G −1, T +1)          nets to 0 by itself
drift booking:   (G:snap-debt +|g−s|, T:ground-truth −|g−s|)   nets to 0 by itself
```

Each pair already sums to zero; the transaction is **two balanced sub-pairs under one nonce**. The cancellation is exact and *forced*: the twin is the only party whose account can honestly fund the correction (reality is where the correction comes from), so ground-truth carries the mirror image of snap-debt. From the two pairs, the invariants are immediate (both accounts start at 0):

```
bal(G:snap-debt) = Σ |gᵢ − sᵢ| = −bal(T:ground-truth)      (debt mirrors truth, always)
bal(G:authority-on-x) + bal(T:authority-on-x) = 1           (authority conserved)
```

Nothing cancels *between* pairs — the elegance is that the pairs are already zero, so the transaction inherits balance without any cross-pair bookkeeping. The unbalanced 3-posting original fails exactly at the spot the doctrine says it must: an unbalanced transaction is arithmetically loud (§3.1.3, tamper-evidence), and the audit replay would flag its own flagship event.

**Shortest form:**

```
T_snap = (authority swap) ⊕ (drift booking)   —  both balanced, one nonce
snap-debt = −ground-truth, forever
```

**One line (bar):** *"A snap is two balanced pairs under one nonce: authority swaps, drift is booked against reality — and the debt column is always the exact negative of the truth column."*

---

## The five, at the bar

| # | One line |
|---|---|
| E1 | *Internal transactions can't move the cut; crossing ones move it exactly once, by exactly the side they land on — and in-flight is a count, not a surprise.* |
| E2 | *Staleness doesn't compound down a chain of fresh eyes: only the source's F and the sum of the hop latencies survive.* |
| E3 | *The worst a lattice lies is half its cube's diagonal — set ε there and integers suffice, and can't do better.* |
| E4 | *A cofire is never more than one bucket of age from its weight: the ladder reads between the truth and twice the truth.* |
| E5 | *A snap is two balanced pairs under one nonce: authority swaps, drift is booked against reality — and the debt column is always the exact negative of the truth column.* |

*Rigor-auditor lane, 2026-08-29. Every line above is derivable from the long forms in FOUNDATION, SEMANTIC-TOWER, ABSTRACTION-MATH §5, and BRIDGES B1/B7/B9 — the derivations are in this document, nothing was dropped.*
