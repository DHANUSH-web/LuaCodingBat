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
  Suite filter: pass a name as the first CLI arg, e.g. ./build test has77
]]

local LuaTest = {}

--- Running totals for the current process.
--- @field total  number  Assertions executed so far
--- @field passed number  Assertions that succeeded
--- @field failed number  Assertions that failed (or errored via run_case)
LuaTest.meta = {
    total = 0,
    passed = 0,
    failed = 0,
}

-- Color output when stdout looks interactive and the user has not disabled it.
-- Respects NO_COLOR (https://no-color.org/) and dumb TERM.
local use_color = (os.getenv("NO_COLOR") == nil) and (os.getenv("TERM") ~= "dumb")

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
--- @return string  text in green (or plain)
local function green(text)
    return colorize("32", text)
end

--- @param text string
--- @return string  text in red (or plain)
local function red(text)
    return colorize("31", text)
end

--- @param text string
--- @return string  text in yellow (or plain)
local function yellow(text)
    return colorize("33", text)
end

--- Pretty-print any Lua value for failure messages and debugging.
---
--- Scalars are shown as readable literals (strings quoted with %q).
--- Tables are shown structurally:
---   - array-like tables → {1, 2, 3}
---   - map-like tables   → {[k]=v, ...} with keys sorted by tostring
--- Cycles are detected and rendered as "<cycle>" to avoid infinite recursion.
---
--- @param value any                 Value to format
--- @param seen  table|nil           Internal set of visited tables (recursion)
--- @return string                   Human-readable representation
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
--- Rules:
---   - Same reference or same primitive value → equal
---   - Different types → not equal
---   - Non-table values that are not identical → not equal
---   - Tables: every key in either table must deep-equal on both sides
---     (union of keys). Nested tables are compared recursively.
---   - Cycles: a pair already being compared is treated as equal to break
---     the loop (pair key is tostring(a)..":"..tostring(b)).
---
--- Used by assert_equals / assert_not_equals so array and map results compare
--- by content, not by table identity.
---
--- @param a    any
--- @param b    any
--- @param seen table|nil  Internal cycle map
--- @return boolean        true if a and b are structurally equal
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

--- Record a successful assertion: bump total + passed, print green PASSED line.
---
--- @param name string  Case label (e.g. "has77#1")
--- @return nil
local function record_pass(name)
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.passed = LuaTest.meta.passed + 1
    print(green("TEST::" .. name .. "::PASSED"))
end

--- Record a failed assertion: bump total + failed, print red FAILED line + reason.
--- Does not raise; the suite continues.
---
--- @param name    string  Case label
--- @param message string  Human-readable failure detail (no "FAILED ->" prefix)
--- @return nil
local function record_fail(name, message)
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.failed = LuaTest.meta.failed + 1
    print(red("TEST::" .. name .. "::FAILED -> " .. message))
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Reset counters to zero. Useful if multiple independent runs share one process.
---
--- @return nil
function LuaTest.reset()
    LuaTest.meta.total = 0
    LuaTest.meta.passed = 0
    LuaTest.meta.failed = 0
end

--- Assert that value is truthy (expected true for boolean predicates).
---
--- Passes when value is true (or any other truthy Lua value).
--- Fails when value is false or nil. Soft: never raises.
---
--- @param name  string  Label printed in the log and used for filtering context
--- @param value any     Result under test (typically a boolean)
--- @return nil
function LuaTest.assert_true(name, value)
    if value then
        record_pass(name)
    else
        record_fail(name, "Expected true but got " .. dump(value))
    end
end

--- Assert that value is falsy (expected false for boolean predicates).
---
--- Passes when value is false or nil.
--- Fails when value is truthy. Soft: never raises.
---
--- @param name  string  Label for the case
--- @param value any     Result under test (typically a boolean)
--- @return nil
function LuaTest.assert_false(name, value)
    if not value then
        record_pass(name)
    else
        record_fail(name, "Expected false but got " .. dump(value))
    end
end

--- Assert that actual equals expected using deep_equal.
---
--- Suitable for numbers, strings, booleans, and tables (arrays / maps).
--- Soft: never raises; prints Expected X but got Y on failure.
---
--- @param name     string  Label for the case
--- @param actual   any     Value produced by the code under test
--- @param expected any     Value that actual must deep-equal
--- @return nil
function LuaTest.assert_equals(name, actual, expected)
    if deep_equal(actual, expected) then
        record_pass(name)
    else
        record_fail(name, "Expected " .. dump(expected) .. " but got " .. dump(actual))
    end
end

--- Assert that actual is not deep-equal to unexpected.
---
--- Soft: never raises.
---
--- @param name       string  Label for the case
--- @param actual     any     Value produced by the code under test
--- @param unexpected any     Value that actual must not equal
--- @return nil
function LuaTest.assert_not_equals(name, actual, unexpected)
    if not deep_equal(actual, unexpected) then
        record_pass(name)
    else
        record_fail(name, "Expected value not equal to " .. dump(unexpected))
    end
end

--- Run a function as a named case, catching runtime errors with pcall.
---
--- If fn completes without error, nothing is counted here (fn itself should
--- call assert_* if it needs pass/fail). If fn raises, one failure is recorded
--- as ERROR so later cases still run.
---
--- @param name string     Label for the case
--- @param fn   function   Zero-arg function to execute (thunk)
--- @return nil
function LuaTest.run_case(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        LuaTest.meta.total = LuaTest.meta.total + 1
        LuaTest.meta.failed = LuaTest.meta.failed + 1
        print(red("TEST::" .. name .. "::ERROR -> " .. tostring(err)))
    end
end

--- Return the optional suite-name filter from the CLI.
---
--- Reads the first script argument (`arg[1]`), as set when running:
---   lua tests.lua has77
---   ./build test has77
---
--- @return string|nil  Suite name to run exclusively, or nil to run all suites
function LuaTest.filter()
    return arg and arg[1] or nil
end

--- Whether a suite with the given name should execute under the current filter.
---
--- @param name string  Suite name (e.g. "has77", "pow")
--- @return boolean     true if no filter is set, or filter equals name
function LuaTest.should_run(name)
    local filter = LuaTest.filter()
    return filter == nil or filter == name
end

--- Run a table-driven suite of cases: each entry is { actual, expected }.
---
--- Call the function under test inline so multi-arg APIs need no wrappers:
---
---   ltest.run_test("pow", {
---       { core.pow(2, 3), 8 },
---       { core.pow(10, 2), 100 },
---   })
---
---   ltest.run_test("has77", {
---       { core.has77({1, 7, 7}), true },
---   })
---
--- Assert selection by type(expected):
---   - boolean  → assert_true (if true) or assert_false (if false)
---   - anything else → assert_equals(actual, expected)
---
--- Labels are suite_name .. "#" .. index (1-based).
--- If should_run(suite_name) is false, returns immediately without counting.
---
--- @param suite_name string  Logical suite id (used for filter + labels)
--- @param cases      table   Array of { actual, expected } pairs
--- @return nil
function LuaTest.run_test(suite_name, cases)
    if not LuaTest.should_run(suite_name) then
        return
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
end

--- Print a summary of total / passed / failed to stdout.
---
--- Passed is green; failed is red when non-zero. Does not exit the process.
---
--- @return nil
function LuaTest.report()
    print("======================= TEST RESULTS =======================")
    print("Total\t:", LuaTest.meta.total)
    print("Passed\t:", green(tostring(LuaTest.meta.passed)))
    local failed_text = tostring(LuaTest.meta.failed)
    if LuaTest.meta.failed > 0 then
        failed_text = red(failed_text)
    end
    print("Failed\t:", failed_text)
    print("============================================================")
    if LuaTest.meta.failed > 0 then
        print(yellow("Some tests failed."))
    end
end

--- End the test run: report (if anything ran) and terminate the process.
---
--- Exit codes:
---   - 1 if no assertions ran (unknown filter or empty suite list), with a
---     short usage hint
---   - 1 if any assertion failed
---   - 0 if all assertions passed
---
--- This function does not return on success or failure (calls os.exit).
---
--- @return nil  (never returns)
function LuaTest.finish()
    if LuaTest.meta.total == 0 then
        print("No tests matched filter: " .. tostring(LuaTest.filter()))
        print("Usage: ./build test [suite_name]")
        os.exit(1)
    end

    LuaTest.report()
    if LuaTest.meta.failed > 0 then
        os.exit(1)
    end
    os.exit(0)
end

-- Re-export internal utilities for advanced tests or interactive debugging.
-- Prefer assert_* / run_test for normal suites.
LuaTest.dump = dump
LuaTest.deep_equal = deep_equal

return LuaTest
