CC     ?= cc
CFLAGS += -std=c99 -Wall -Wextra -Werror -pedantic -O2

.PHONY: all check table json clean

all: check

build/study: study.c
	@mkdir -p build
	$(CC) $(CFLAGS) study.c -o $@

check: build/study
	./build/study --check

table: build/study
	./build/study

json: build/study
	./build/study --json > results.json
	@echo "wrote results.json"

clean:
	rm -rf build
