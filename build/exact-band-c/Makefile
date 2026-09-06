# exact-band-c -- the third substrate.
#
# `make` builds and runs everything. There is no configure step, no dependency
# to fetch and nothing to install: the library is one .c file and one header.

CC      ?= cc
CSTD    ?= -std=c99
WARN     = -Wall -Wextra -Werror -pedantic -Wshadow -Wconversion -Wsign-conversion \
           -Wcast-qual -Wstrict-prototypes -Wmissing-prototypes -Wold-style-definition
OPT     ?= -O2
CFLAGS  += $(CSTD) $(WARN) $(OPT)

SRC      = src/exact_band.c
HDR      = src/exact_band.h
OBJ      = build/exact_band.o
LIB      = build/libexactband.a
VECTORS ?= tests/vectors.json

.PHONY: all test lib conformance unit clean nofloat

all: test

lib: $(LIB)

build:
	@mkdir -p build

$(OBJ): $(SRC) $(HDR) | build
	$(CC) $(CFLAGS) -c $(SRC) -o $@

$(LIB): $(OBJ)
	$(AR) rcs $@ $(OBJ)

build/unit: tests/test_exact_band.c $(SRC) $(HDR) | build
	$(CC) $(CFLAGS) tests/test_exact_band.c $(SRC) -o $@

build/conformance: tests/conformance.c tests/json.c tests/json.h $(SRC) $(HDR) | build
	$(CC) $(CFLAGS) tests/conformance.c tests/json.c $(SRC) -o $@

unit: build/unit
	./build/unit

conformance: build/conformance
	./build/conformance $(VECTORS)

# The central claim of this library is that it contains no floating point.
# A claim worth making is worth checking, so the build checks it: the compiled
# object must carry no reference to a float or double, and the sources must
# mention neither a floating type nor <math.h>.
nofloat: $(OBJ)
	@if grep -nE '(^|[^_[:alnum:]])(float|double)([^_[:alnum:]]|$$)|math\.h|[0-9]\.[0-9]' \
	        $(SRC) $(HDR) | grep -v '^\S*: *\*' | grep -v '\*/' ; then \
	  echo "nofloat: floating point appears in the sources"; exit 1; \
	else echo "nofloat: no floating-point type in $(SRC) $(HDR)"; fi

test: unit conformance nofloat
	@echo
	@echo "exact-band-c: all checks pass."

clean:
	rm -rf build
