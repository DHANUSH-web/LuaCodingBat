# LuaCodingBat

Practice CodingBat-style problems in **Lua**, with a small custom test harness and a simple CLI.

## Requirements

- **Lua 5.3+** (uses integer division `//`)
- **Bash** (for `./build`)

Check your version:

```bash
lua -v
```

## Quick start

```bash
./build test          # run all tests
./build test has77    # run one suite
./build list          # list suites
./build run           # show usage hints
./build help          # all commands
```

## Project layout

```text
.
├── build                 # CLI: run, test, new, list
├── main.lua              # entry stub
├── tests.lua             # table-driven test cases
├── libs/
│   ├── core.lua          # problem implementations
│   └── lua_test.lua      # assertions + report / exit codes
└── .github/workflows/
    └── test.yml          # CI
```

| Path | Role |
|------|------|
| `libs/core.lua` | Solutions (between `-- CodingBat: BEGIN/END`) |
| `libs/lua_test.lua` | Soft asserts, deep equality, summary, exit status |
| `tests.lua` | Suites and inputs/expected outputs |
| `build` | Local runner |

## Adding a problem

Scaffold a stub in `core` and a matching test suite:

```bash
./build new myProblem
```

Then:

1. Implement `core.myProblem` in `libs/core.lua`
2. Fill in cases in `tests.lua` with `run_test` (table-driven).
   Each case is `{ actual, expected }` — call the function inline with any arguments:

```lua
-- Boolean expected → assert_true / assert_false
run_test("myProblem", {
    { core.myProblem({1, 2, 3}), true },
    { core.myProblem({}), false },
})

-- Non-boolean expected → assert_equals (multi-arg is natural)
run_test("pow", {
    { core.pow(2, 3), 8 },
    { core.pow(10, 2), 100 },
})

run_test("reverse_number", {
    { core.reverse_number(123), 321 },
    { core.reverse_number(-45), -54 },
})
```

3. Run only that suite while iterating:

```bash
./build test myProblem
```

`run_test(name, cases)` picks the assert from `type(expected)`:

| Expected type | Assert used |
|---------------|-------------|
| `boolean` | `assert_true` / `assert_false` |
| anything else | `assert_equals` (tables supported) |

You can still call `assert_*` helpers directly when a case does not fit `{ actual, expected }`.
## Branch model

| Branch | Purpose |
|--------|---------|
| **`codingbat`** | Day-to-day work; push new problems and fixes here |
| **`main`** | Stable; only updated via PR after tests pass |

Typical flow:

```text
push to codingbat  →  CI tests
       ↓
PR codingbat → main  →  CI tests (merge gate)
       ↓
merge to main  →  CI tests again
```

```bash
git checkout codingbat
# ... edit, commit ...
git push origin codingbat

# when green and ready:
# open a PR: codingbat → main, merge after checks pass
```

## Continuous integration

GitHub Actions (`.github/workflows/test.yml`) runs `./build test` when:

- code is **pushed** to `codingbat` or `main`
- a **pull request** targets `main`

The job installs Lua 5.4 on Ubuntu and uses the same `./build test` path as local development. A non-zero exit from the suite fails the check.

## License

Use and modify freely for personal practice unless otherwise noted.
