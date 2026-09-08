CFLAGS ?= -std=c99 -Wall -Wextra -Werror -pedantic -O2
.PHONY: all clean
all:
	@$(CC) $(CFLAGS) study.c    -o /tmp/cg_study    && /tmp/cg_study
	@echo
	@$(CC) $(CFLAGS) diagnose.c -o /tmp/cg_diagnose && /tmp/cg_diagnose
	@echo
	@$(CC) $(CFLAGS) fix.c      -o /tmp/cg_fix      && /tmp/cg_fix
clean:
	rm -f /tmp/cg_study /tmp/cg_diagnose /tmp/cg_fix
