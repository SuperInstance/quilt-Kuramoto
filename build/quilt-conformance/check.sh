#!/bin/sh
# check.sh -- hold the Python, C and Rust references to the same corpus.
#
# Compares the HASHES, in order, and nothing else. An earlier version of this
# script diffed the whole output and reported a divergence that was really
# Python printing "65B" where C printed "65" -- a harness bug masquerading as a
# substrate disagreement, which is exactly the failure this directory exists to
# stop people making.
set -eu
cd "$(dirname "$0")"
mkdir -p build

hashes() { grep -oE '0x[0-9a-f]{16}' ; }

python3 reference.py > build/py.txt
cc -std=c99 -Wall -Wextra -Werror -pedantic -O2 reference.c -o build/ref_c
./build/ref_c > build/c.txt
rustc --edition 2021 -O -o build/ref_rs reference.rs 2>/dev/null
./build/ref_rs > build/rs.txt

hashes < build/py.txt > build/py.h
hashes < build/c.txt  > build/c.h
hashes < build/rs.txt > build/rs.h

n=$(wc -l < build/py.h)
if [ "$n" -lt 9 ]; then
    echo "FAIL: expected at least 9 hashes (8 cases + stream), got $n" >&2
    exit 1
fi

fail=0
if ! cmp -s build/py.h build/c.h; then
    echo "FAIL: C disagrees with Python" >&2; diff build/py.h build/c.h >&2 || true; fail=1
fi
if ! cmp -s build/py.h build/rs.h; then
    echo "FAIL: Rust disagrees with Python" >&2; diff build/py.h build/rs.h >&2 || true; fail=1
fi
[ "$fail" -eq 0 ] || exit 1

# The published badge value must be among them, or this corpus has drifted off
# the thing it exists to verify.
if ! grep -q '0xe435d91d6d92a1d8' build/py.h; then
    echo "FAIL: the published hash 0xe435d91d6d92a1d8 is not in the corpus" >&2
    exit 1
fi

echo "  ok  Python, C and Rust agree on $n hashes, published badge value included"
