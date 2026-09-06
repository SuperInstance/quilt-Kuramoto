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

say "conformance stream: do all three substrates fold to the same checksum?"
# The golden file pins cases someone chose. The stream covers the ones nobody
# did: each substrate walks the same pseudo-random sequence and folds every
# answer into one 64-bit number. See CONFORMANCE-STREAM.md.
STREAM_RS_ITERS=${STREAM_RS_ITERS:-1000000}
STREAM_C_ITERS=${STREAM_C_ITERS:-1000000}
# Python is capped lower only because it is ~1000x slower per case; its answer at
# the full count is recorded in stream.json and matches.
STREAM_PY_ITERS=${STREAM_PY_ITERS:-100000}

want() {
    python3 -c "import json,sys;print(json.load(open('stream.json'))['checksums'][sys.argv[1]])" "$1"
}
got() { printf '%s' "${1##*checksum=}"; }

check_stream() {
    name=$1; iters=$2; line=$3
    expected=$(want "$iters") || {
        echo "FAIL: stream.json has no checksum recorded for $iters iterations" >&2
        exit 1
    }
    actual=$(got "$line")
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: $name stream at $iters iterations" >&2
        echo "      got      $actual"                  >&2
        echo "      expected $expected"                >&2
        echo "      A substrate disagrees on a case the fixture does not cover." >&2
        echo "      Bisect by lowering the iteration count until it passes."     >&2
        exit 1
    fi
    echo "  ok  $name at $iters iterations: $actual"
}

check_stream "Rust" "$STREAM_RS_ITERS" \
    "$(cd exact-band && cargo run --quiet --release --example stream -- "$STREAM_RS_ITERS")"
check_stream "C" "$STREAM_C_ITERS" \
    "$(cd exact-band-c && make --no-print-directory build/stream >/dev/null && ./build/stream "$STREAM_C_ITERS")"
check_stream "Python" "$STREAM_PY_ITERS" \
    "$(python3 stream_py.py "$STREAM_PY_ITERS")"

printf '\n\033[1mAll four substrates agree, the golden file matches its generator,\n'
printf 'and the three implementations fold identical checksums.\033[0m\n'
