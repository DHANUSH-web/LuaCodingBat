local ltest = require("libs.lua_test")
local core = require("libs.core")

--- Optional filter: `./build test has77` runs only matching suite names.
local filter = arg and arg[1] or nil

local function should_run(name)
    return filter == nil or filter == name
end

--- Run table-driven cases: { actual, expected }.
--- Call the function inline so multi-arg APIs need no wrappers, e.g.:
---   { core.pow(2, 3), 8 }
---   { core.has77({1, 7, 7}), true }
--- Booleans use assert_true / assert_false; everything else uses assert_equals.
local function run_test(suite_name, cases)
    if not should_run(suite_name) then
        return
    end

    for i, case in ipairs(cases) do
        local actual, expected = case[1], case[2]
        local label = suite_name .. "#" .. i

        if type(expected) == "boolean" then
            if expected then
                ltest.assert_true(label, actual)
            else
                ltest.assert_false(label, actual)
            end
        else
            ltest.assert_equals(label, actual, expected)
        end
    end
end

-- pow(base, exp)
run_test("pow", {
    { core.pow(2, 3), 8 },
    { core.pow(2, 0), 1 },
    { core.pow(5, 1), 5 },
    { core.pow(10, 2), 100 },
    { core.pow(1, 5), 1 },
    { core.pow(3, 4), 81 },
    { core.pow(7, 0), 1 },
    { core.pow(4, 2), 16 },
    { core.pow(9, 3), 729 },
})

-- reverse_number(n)
run_test("reverse_number", {
    { core.reverse_number(123), 321 },
    { core.reverse_number(-45), -54 },
    { core.reverse_number(0), 0 },
    { core.reverse_number(7), 7 },
    { core.reverse_number(10), 1 },          -- trailing zeros drop when reversed
    { core.reverse_number(100), 1 },
    { core.reverse_number(120), 21 },
    { core.reverse_number(-100), -1 },
    { core.reverse_number(-123), -321 },
    { core.reverse_number(1001), 1001 },
})

-- CodingBat: has77
run_test("has77", {
    { core.has77({1, 7, 7}), true },
    { core.has77({1, 7, 1, 7}), true },
    { core.has77({1, 7, 1, 1, 7}), false },
    { core.has77({7, 7}), true },           -- adjacent pair at start / short array
    { core.has77({7, 1, 7}), true },         -- separated by one
    { core.has77({7}), false },
    { core.has77({}), false },
    { core.has77({2, 7, 2, 7}), true },
    { core.has77({2, 7, 2, 2, 7}), false },
    { core.has77({7, 2, 7, 2}), true },
})

-- CodingBat: has12
run_test("has12", {
    { core.has12({1, 3, 2}), true },
    { core.has12({1, 3, 2, 5}), true },
    { core.has12({1}), false },
    { core.has12({}), false },
    { core.has12({2}), false },
    { core.has12({2, 1}), false },           -- 2 before 1 does not count
    { core.has12({1, 1, 2}), true },
    { core.has12({3, 1, 4, 5, 2}), true },
    { core.has12({3, 2, 1}), false },
    { core.has12({1, 2}), true },
})

if ltest.meta.total == 0 then
    print("No tests matched filter: " .. tostring(filter))
    print("Usage: ./build test [suite_name]")
    os.exit(1)
end

ltest.finish()
