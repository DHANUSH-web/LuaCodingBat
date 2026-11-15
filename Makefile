.DEFAULT_GOAL := help
.PHONY: help run test list new

LUA ?= lua
NAME ?=
SUITE ?=
OPTS ?=

help:
	@printf '%s\n' \
	  'Usage: make <target> [NAME=problem] [SUITE=suite] [OPTS="flags"]' \
	  '' \
	  'Targets:' \
	  '  run                 Run main.lua' \
	  '  test                Run tests (optionally SUITE=has77, OPTS="-q")' \
	  '  new NAME=myProblem  Scaffold a problem in core and tests' \
	  '  list                List test suites' \
	  '  help                Show this help'

run:
	$(LUA) main.lua

test:
	$(LUA) tests.lua $(OPTS) $(SUITE)

list:
	@grep -oE 'ltest\.run_test\("[^"]+"' tests.lua | sed 's/ltest\.run_test("//;s/"$$//' | sort -u

new:
	@set -eu; \
	name='$(NAME)'; \
	if ! printf '%s\n' "$$name" | grep -Eq '^[a-zA-Z_][a-zA-Z0-9_]*$$'; then \
	  echo 'Usage: make new NAME=problem_name (use a Lua identifier)' >&2; exit 1; \
	fi; \
	if grep -q "function core.$$name" libs/core.lua; then \
	  echo "core.$$name already exists in libs/core.lua" >&2; exit 1; \
	fi; \
	if grep -Fq "ltest.run_test(\"$$name\"" tests.lua; then \
	  echo "Test suite $$name already exists in tests.lua" >&2; exit 1; \
	fi; \
	tmp=$$(mktemp); \
	awk -v name="$$name" '/^-- CodingBat: END$$/ && !done { \
	  print ""; print "-- TODO: implement " name; \
	  print "function core." name "(nums)"; print "    return false"; print "end"; done=1 \
	} { print } END { if (!done) exit 1 }' libs/core.lua > "$$tmp" || { rm -f "$$tmp"; echo 'Could not find CodingBat end marker in libs/core.lua' >&2; exit 1; }; \
	mv "$$tmp" libs/core.lua; \
	tmp=$$(mktemp); \
	awk -v name="$$name" '/^if ltest\.meta\.total == 0 then$$/ && !done { \
	  print ""; print "-- CodingBat: " name; \
	  print "ltest.run_test(\"" name "\", {"; \
	  print "    -- { actual, expected }"; \
	  print "    { core." name "({}), false },"; print "})"; done=1 \
	} { print } END { if (!done) exit 1 }' tests.lua > "$$tmp" || { rm -f "$$tmp"; echo 'Could not find test insertion marker in tests.lua' >&2; exit 1; }; \
	mv "$$tmp" tests.lua; \
	echo "Scaffolded core.$$name and test suite '$$name'."; \
	echo "Edit libs/core.lua and tests.lua, then run: make test SUITE=$$name"
