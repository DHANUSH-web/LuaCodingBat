--[[
  LuaTest — lightweight test harness for this project.

  Used by tests.lua to assert CodingBat / core helpers without aborting the
  whole suite on the first failure. Typical flow:

    local ltest = require("libs.lua_test")
    local core  = require("libs.core")

    ltest.run_test("pow", {
        { core.pow(2, 3), 8 },
        { core.pow(10, 2), 100 },
    })
    ltest.finish()   -- prints summary and exits 0 (ok) or 1 (failures)

  Soft asserts: failures increment counters and print, but do not raise.

  CLI (passed through ./build test ...):
    ./build test              run all suites (default verbose layout)
    ./build test has77        run one suite
    ./build test -q           quiet: failures only + summary
    ./build test -v has77     verbose (same as default; explicit)
    ./build test --help       show harness flags
]]

local LuaTest = {}

--- Running totals for the current process.
--- @class LuaTest
--- @field total  number  Assertions executed so far
--- @field passed number  Assertions that succeeded
--- @field failed number  Assertions that failed (or errored via run_case)
LuaTest.meta = {
    total = 0,
    passed = 0,
    failed = 0,
}

-- Per-suite counters while a run_test block is active (nil outside).
local current_suite = nil

-- Overall run timer (os.clock CPU seconds); set on first suite/assert activity.
local run_started_at = nil

-- Color output when stdout looks interactive and the user has not disabled it.
-- Respects NO_COLOR (https://no-color.org/) and dumb TERM.
local use_color = (os.getenv("NO_COLOR") == nil) and (os.getenv("TERM") ~= "dumb")

--- Mark the start of the overall run (once).
local function mark_run_start()
    if not run_started_at then
        run_started_at = os.clock()
    end
end

--- Format a duration in seconds for display (µs / ms / s).
--- @param seconds number
--- @return string
local function format_duration(seconds)
    if seconds < 0 then
        seconds = 0
    end
    local ms = seconds * 1000
    if ms < 1 then
        return string.format("%.0fµs", ms * 1000)
    elseif ms < 1000 then
        return string.format("%.2fms", ms)
    else
        return string.format("%.2fs", seconds)
    end
end

---------------------------------------------------------------------------
-- CLI options (parsed once from arg)
---------------------------------------------------------------------------

local cli = {
    filter = nil,   -- suite name, or nil for all
    quiet = false,  -- only print failures + summary
    verbose = true, -- print each case (default on; -q turns off)
    help = false,
}

local function parse_cli()
    if not arg then
        return
    end
    for _, a in ipairs(arg) do
        if a == "-q" or a == "--quiet" then
            cli.quiet = true
            cli.verbose = false
        elseif a == "-v" or a == "--verbose" then
            cli.verbose = true
            cli.quiet = false
        elseif a == "-h" or a == "--help" then
            cli.help = true
        elseif a:sub(1, 1) == "-" then
            -- unknown flag: ignore for forward-compat
        elseif not cli.filter then
            cli.filter = a
        end
    end
    -- Env override: LTEST_QUIET=1 forces quiet mode
    if os.getenv("LTEST_QUIET") == "1" then
        cli.quiet = true
        cli.verbose = false
    end
end

parse_cli()

---------------------------------------------------------------------------
-- Internal helpers (not part of the public API unless re-exported below)
---------------------------------------------------------------------------

--- Wrap text in an ANSI SGR escape sequence when color is enabled.
---
--- @param code string  ANSI color/style code, e.g. "32" (green), "31" (red)
--- @param text string  Plain text to wrap
--- @return string      Colored text, or the original text when color is off
local function colorize(code, text)
    if not use_color then
        return text
    end
    return "\27[" .. code .. "m" .. text .. "\27[0m"
end

--- @param text string
--- @return string
local function green(text)
    return colorize("32", text)
end

--- @param text string
--- @return string
local function red(text)
    return colorize("31", text)
end

--- @param text string
--- @return string
local function yellow(text)
    return colorize("33", text)
end

--- @param text string
--- @return string
local function cyan(text)
    return colorize("36", text)
end

--- @param text string
--- @return string
local function bold(text)
    return colorize("1", text)
end

--- @param text string
--- @return string
local function dim(text)
    return colorize("2", text)
end

local SYMBOL_PASS = "✓"
local SYMBOL_FAIL = "✗"
local SYMBOL_SUITE = "▶"

--- Pretty-print any Lua value for failure messages and debugging.
---
--- @param value any
--- @param seen  table|nil
--- @return string
local function dump(value, seen)
    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "string" then
        return string.format("%q", value)
    elseif t == "boolean" or t == "number" then
        return tostring(value)
    elseif t ~= "table" then
        return tostring(value)
    end

    seen = seen or {}
    if seen[value] then
        return "<cycle>"
    end
    seen[value] = true

    local parts = {}
    local n = #value
    local is_array = true
    local count = 0
    for k in pairs(value) do
        count = count + 1
        if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
            is_array = false
        end
    end
    if count ~= n then
        is_array = false
    end

    if is_array then
        for i = 1, n do
            parts[#parts + 1] = dump(value[i], seen)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end

    local keys = {}
    for k in pairs(value) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for _, k in ipairs(keys) do
        parts[#parts + 1] = "[" .. dump(k, seen) .. "]=" .. dump(value[k], seen)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

--- Structural (deep) equality for any two values.
---
--- @param a    any
--- @param b    any
--- @param seen table|nil
--- @return boolean
local function deep_equal(a, b, seen)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return false
    end

    seen = seen or {}
    local key = tostring(a) .. ":" .. tostring(b)
    if seen[key] then
        return true
    end
    seen[key] = true

    local keys = {}
    for k in pairs(a) do
        keys[k] = true
    end
    for k in pairs(b) do
        keys[k] = true
    end
    for k in pairs(keys) do
        if not deep_equal(a[k], b[k], seen) then
            return false
        end
    end
    return true
end

--- Format a one-line "expect X, got Y" style message.
--- @param expected any
--- @param actual   any
--- @return string
local function expect_got(expected, actual)
    return "expect " .. dump(expected) .. ", got " .. dump(actual)
end

--- ASCII progress bar for pass rate (e.g. ████████████░░░░░░░░  60%).
--- @param passed number
--- @param total  number
--- @param width  number|nil  bar width in characters (default 20)
--- @return string
local function progress_bar(passed, total, width)
    width = width or 20
    if total <= 0 then
        return dim(string.rep("░", width)) .. "  0%"
    end
    local ratio = passed / total
    local filled = math.floor(ratio * width + 0.5)
    if filled > width then
        filled = width
    end
    local pct = math.floor(ratio * 100 + 0.5)
    local bar = green(string.rep("█", filled)) .. dim(string.rep("░", width - filled))
    return bar .. "  " .. tostring(pct) .. "%"
end

--- Record a successful assertion.
--- Prints:  ✓ suite#n  → <value>   (returned / expected value when they match)
---
--- @param name     string
--- @param actual   any|nil  returned value under test
--- @param expected any|nil  expected value (optional; shown if different presentation needed)
--- @return nil
local function record_pass(name, actual, expected)
    mark_run_start()
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.passed = LuaTest.meta.passed + 1
    if current_suite then
        current_suite.passed = current_suite.passed + 1
    end

    if cli.verbose and not cli.quiet then
        -- Prefer showing the returned value; fall back to expected.
        local value = actual
        if value == nil and expected ~= nil then
            value = expected
        end
        local value_part = ""
        if value ~= nil or expected ~= nil then
            -- When both present and equal, one arrow is enough.
            value_part = "  " .. dim("→") .. " " .. dump(value)
        end
        print("  " .. green(SYMBOL_PASS) .. " " .. name .. value_part)
    end
end

--- Record a failed assertion. Soft: does not raise.
--- Prints:  ✗ suite#n  expect 5, got 4
---
--- @param name    string
--- @param detail  table|string|nil  { expected, actual } or { message } or plain string
--- @return nil
local function record_fail(name, detail)
    mark_run_start()
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.failed = LuaTest.meta.failed + 1
    if current_suite then
        current_suite.failed = current_suite.failed + 1
    end

    local d = detail
    if type(detail) == "string" then
        d = { message = detail }
    end
    d = d or {}

    -- Always show failures (even in quiet mode).
    if current_suite and not current_suite.header_printed then
        print("")
        print(bold(cyan(SYMBOL_SUITE .. " " .. current_suite.name)))
        current_suite.header_printed = true
    end

    local msg
    if d.expected ~= nil or d.actual ~= nil then
        msg = expect_got(d.expected, d.actual)
    else
        msg = d.message or "failed"
    end
    print("  " .. red(SYMBOL_FAIL) .. " " .. bold(name) .. "  " .. red(msg))
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Reset counters to zero.
--- @return nil
function LuaTest.reset()
    LuaTest.meta.total = 0
    LuaTest.meta.passed = 0
    LuaTest.meta.failed = 0
    current_suite = nil
    run_started_at = nil
end

--- Assert that value is truthy.
--- @param name  string
--- @param value any
--- @return nil
function LuaTest.assert_true(name, value)
    if value then
        record_pass(name, value, true)
    else
        record_fail(name, { expected = true, actual = value })
    end
end

--- Assert that value is falsy.
--- @param name  string
--- @param value any
--- @return nil
function LuaTest.assert_false(name, value)
    if not value then
        record_pass(name, value, false)
    else
        record_fail(name, { expected = false, actual = value })
    end
end

--- Assert that actual equals expected using deep_equal.
--- @param name     string
--- @param actual   any
--- @param expected any
--- @return nil
function LuaTest.assert_equals(name, actual, expected)
    if deep_equal(actual, expected) then
        record_pass(name, actual, expected)
    else
        record_fail(name, { expected = expected, actual = actual })
    end
end

--- Assert that actual is not deep-equal to unexpected.
--- @param name       string
--- @param actual     any
--- @param unexpected any
--- @return nil
function LuaTest.assert_not_equals(name, actual, unexpected)
    if not deep_equal(actual, unexpected) then
        record_pass(name, actual, unexpected)
    else
        record_fail(name, {
            message = "expect not " .. dump(unexpected) .. ", got " .. dump(actual),
        })
    end
end

--- Run a function as a named case, catching runtime errors with pcall.
--- @param name string
--- @param fn   function
--- @return nil
function LuaTest.run_case(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        record_fail(name, { message = "error: " .. tostring(err) })
    end
end

--- Return the optional suite-name filter from the CLI.
--- @return string|nil
function LuaTest.filter()
    return cli.filter
end

--- Whether a suite with the given name should execute under the current filter.
--- @param name string
--- @return boolean
function LuaTest.should_run(name)
    if cli.help then
        return false
    end
    local filter = LuaTest.filter()
    return filter == nil or filter == name
end

--- Run a table-driven suite of cases: each entry is { actual, expected }.
---
--- Prints a suite header, per-case ✓/✗ lines (unless quiet), and a one-line
--- suite footer. Failures always show expected/actual blocks.
---
--- @param suite_name string
--- @param cases      table
--- @return nil
function LuaTest.run_test(suite_name, cases)
    if not LuaTest.should_run(suite_name) then
        return
    end

    mark_run_start()
    local suite_started_at = os.clock()

    local n = #cases
    current_suite = {
        name = suite_name,
        passed = 0,
        failed = 0,
        header_printed = false,
    }

    if not cli.quiet then
        print("")
        print(bold(cyan(SYMBOL_SUITE .. " " .. suite_name)) .. dim("  (" .. n .. " cases)"))
        current_suite.header_printed = true
    end

    for i, case in ipairs(cases) do
        local actual, expected = case[1], case[2]
        local label = suite_name .. "#" .. i

        if type(expected) == "boolean" then
            if expected then
                LuaTest.assert_true(label, actual)
            else
                LuaTest.assert_false(label, actual)
            end
        else
            LuaTest.assert_equals(label, actual, expected)
        end
    end

    local suite_elapsed = os.clock() - suite_started_at

    -- Suite footer (skip in quiet when suite was fully green — no header printed)
    if current_suite.header_printed then
        local p, f = current_suite.passed, current_suite.failed
        local summary
        if f > 0 then
            summary = green(tostring(p) .. " passed") .. ", " .. red(tostring(f) .. " failed")
        else
            summary = green(tostring(p) .. " passed")
        end
        print(dim("  · " .. summary .. "  ·  " .. format_duration(suite_elapsed)))
    end

    current_suite = nil
end

--- Print a summary of total / passed / failed to stdout (with pass-rate bar + time).
--- @return nil
function LuaTest.report()
    local m = LuaTest.meta
    local ok = m.failed == 0
    local status = ok and green(bold("PASSED")) or red(bold("FAILED"))
    local rule = string.rep("═", 42)
    local elapsed = 0
    if run_started_at then
        elapsed = os.clock() - run_started_at
    end

    print("")
    print(dim(rule))
    print("  Total    " .. tostring(m.total))
    print("  Passed   " .. green(tostring(m.passed)))
    print("  Failed   " .. (m.failed > 0 and red(tostring(m.failed)) or tostring(m.failed)))
    print("  Progress " .. progress_bar(m.passed, m.total, 20))
    print("  Time     " .. format_duration(elapsed))
    print("  Status   " .. status)
    print(dim(rule))
end

local function print_help()
    print([[
LuaTest options (./build test [options] [suite]):

  -q, --quiet     Only print failures and the final summary
  -v, --verbose   Print every case (default)
  -h, --help      Show this help
  <suite>         Run only that suite (e.g. has77, pow)

Environment:
  LTEST_QUIET=1   Same as --quiet
  NO_COLOR=1      Disable ANSI colors
]])
end

--- End the test run: report (if anything ran) and terminate the process.
---
--- Exit codes: 0 all passed; 1 failures or no matching tests / help only.
--- @return nil  (never returns on normal paths)
function LuaTest.finish()
    if cli.help then
        print_help()
        os.exit(0)
    end

    if LuaTest.meta.total == 0 then
        print(yellow("No tests matched filter: " .. tostring(LuaTest.filter())))
        print("Usage: ./build test [options] [suite_name]")
        print("       ./build test --help")
        os.exit(1)
    end

    LuaTest.report()
    if LuaTest.meta.failed > 0 then
        os.exit(1)
    end
    os.exit(0)
end

-- Expose mode helpers / utilities
LuaTest.dump = dump
LuaTest.deep_equal = deep_equal
LuaTest.cli = cli

return LuaTest
