#!/bin/sh
# check-substrates.sh -- one command that holds all four projects to the same
# arithmetic, and holds the golden file to its own generator.
#
# The conformance discipline here is "one vector set, every substrate reads it".
# That only means anything if two things stay true, and neither is self-evident:
#
#   1. every copy of vectors.json is byte-identical -- otherwise each substrate
#      is quietly conforming to its own private fixture;
#   2. the committed vectors.json still matches what emit_vectors produces --
#      otherwise the golden file has drifted from the code it was meant to pin,
#      and all four substrates agree on a stale answer.
#
# Nothing checked (2) before this script existed.

set -eu
cd "$(dirname "$0")"

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
FRESH=$(mktemp)
trap 'rm -f "$FRESH"' EXIT

say "Rust: exact-band"
( cd exact-band && cargo test --quiet && cargo test --quiet --all-features \
  && cargo clippy --quiet --all-targets -- -D warnings )

say "golden vectors: still what the generator produces?"
( cd exact-band && cargo run --quiet --release --example emit_vectors ) > "$FRESH"
for copy in exact-band-c/tests/vectors.json \
            tminus-band/tests/vectors.json \
            phase-lock/tests/vectors.json; do
    if ! cmp -s "$FRESH" "$copy"; then
        echo "FAIL: $copy differs from a fresh emit_vectors run." >&2
        echo "      Either the emitter changed and the copies were not"        >&2
        echo "      regenerated, or a copy was edited by hand. Both are bugs." >&2
        exit 1
    fi
    echo "  ok  $copy"
done

say "C: exact-band-c"
( cd exact-band-c && make --no-print-directory )

say "Python: tminus-band"
( cd tminus-band && python3 -m pytest -q )

say "Python: tower"
( cd tower && python3 -m pytest -q )

say "Python: phase-lock"
( cd phase-lock && python3 -m pytest -q )

printf '\n\033[1mAll four substrates agree, and the golden file matches its generator.\033[0m\n'
