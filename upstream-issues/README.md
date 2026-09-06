# Ready-to-file upstream issues

Two verified issues, written to be pasted into their repos. This session could
not file them itself: GitHub API access here is scoped to `quilt-Kuramoto`, and
issue creation on the other repos returns *"repository not configured for this
session"*.

Each claim below was reproduced before being written down.

## One claim that did NOT survive checking

An earlier draft included a third issue against `quilt-verilog`, arguing its
"6/6 PASS" formal-verification headline was unsupported by its own committed
audit snapshot. **That was wrong and has been withdrawn.**

The README states the caveat in the same sentence as the claim — the depths the
run used, the later raise to 105/130, that no completed run at the new depth is
on record, that the snapshot shows `fair INCOMPLETE@85`, and that the re-run
stalled at 18 minutes. The snapshot agrees with the caveat rather than
contradicting it. See `docs/MISSING.md`.

A second draft claim — that `eisenstein`'s `std` feature does not compile — also
failed to reproduce against the **published** crate, which contains only
`src/lib.rs` and builds cleanly with `std` and `--all-features`. That error lives
in the GitHub HEAD, which carries files the published crate does not.
