local LuaTest = {}

LuaTest.meta = {
    total = 0,
    passed = 0,
    failed = 0,
}

local use_color = (os.getenv("NO_COLOR") == nil) and (os.getenv("TERM") ~= "dumb")

local function colorize(code, text)
    if not use_color then
        return text
    end
    return "\27[" .. code .. "m" .. text .. "\27[0m"
end

local function green(text)
    return colorize("32", text)
end

local function red(text)
    return colorize("31", text)
end

local function yellow(text)
    return colorize("33", text)
end

--- Pretty-print values for failure messages (tables shown structurally).
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

--- Structural equality for scalars and tables (arrays + maps).
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

local function record_pass(name)
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.passed = LuaTest.meta.passed + 1
    print(green("TEST::" .. name .. "::PASSED"))
end

local function record_fail(name, message)
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.failed = LuaTest.meta.failed + 1
    print(red("TEST::" .. name .. "::FAILED -> " .. message))
end

function LuaTest.reset()
    LuaTest.meta.total = 0
    LuaTest.meta.passed = 0
    LuaTest.meta.failed = 0
end

function LuaTest.assert_true(name, value)
    if value then
        record_pass(name)
    else
        record_fail(name, "Expected true but got " .. dump(value))
    end
end

function LuaTest.assert_false(name, value)
    if not value then
        record_pass(name)
    else
        record_fail(name, "Expected false but got " .. dump(value))
    end
end

function LuaTest.assert_equals(name, actual, expected)
    if deep_equal(actual, expected) then
        record_pass(name)
    else
        record_fail(name, "Expected " .. dump(expected) .. " but got " .. dump(actual))
    end
end

function LuaTest.assert_not_equals(name, actual, unexpected)
    if not deep_equal(actual, unexpected) then
        record_pass(name)
    else
        record_fail(name, "Expected value not equal to " .. dump(unexpected))
    end
end

--- Run a named case; failures and errors are caught so the suite continues.
function LuaTest.run_case(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        LuaTest.meta.total = LuaTest.meta.total + 1
        LuaTest.meta.failed = LuaTest.meta.failed + 1
        print(red("TEST::" .. name .. "::ERROR -> " .. tostring(err)))
    end
end

--- Suite filter from CLI: `lua tests.lua has77` or `./build test has77`.
function LuaTest.filter()
    return arg and arg[1] or nil
end

function LuaTest.should_run(name)
    local filter = LuaTest.filter()
    return filter == nil or filter == name
end

--- Table-driven cases: { actual, expected }.
--- Call the function inline, e.g. { core.pow(2, 3), 8 } or { core.has77({1,7,7}), true }.
--- Booleans use assert_true / assert_false; everything else uses assert_equals.
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

--- Print the report and exit with 0 on success, 1 on any failure.
--- If no cases ran (e.g. unknown filter), exit 1 with a usage hint.
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

-- Expose helpers for advanced tests / debugging.
LuaTest.dump = dump
LuaTest.deep_equal = deep_equal

return LuaTest
