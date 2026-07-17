local ltest = require("libs.lua_test")
local core = require("libs.core")

--- Optional filter: `./build test has77` runs only matching suite names.
local filter = arg and arg[1] or nil

local function should_run(name)
    return filter == nil or filter == name
end

--- Run table-driven cases: { input, expected }.
--- Booleans use assert_true / assert_false; everything else uses assert_equals.
local function run_test(suite_name, fn, cases)
    if not should_run(suite_name) then
        return
    end

    for i, case in ipairs(cases) do
        local input, expected = case[1], case[2]
        local label = suite_name .. "#" .. i
        local actual = fn(input)

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

-- Helpers (multi-arg functions): input is a list of arguments.
local function pow_args(args)
    return core.pow(args[1], args[2])
end

-- pow(base, exp) — cases: { {base, exp}, expected }
run_test("pow", pow_args, {
    { {2, 3}, 8 },
    { {2, 0}, 1 },
    { {5, 1}, 5 },
    { {10, 2}, 100 },
    { {1, 5}, 1 },
    { {3, 4}, 81 },
    { {7, 0}, 1 },
    { {4, 2}, 16 },
    { {9, 3}, 729 },
})

-- reverse_number(n) — cases: { n, expected }
run_test("reverse_number", core.reverse_number, {
    { 123, 321 },
    { -45, -54 },
    { 0, 0 },
    { 7, 7 },
    { 10, 1 },          -- trailing zeros drop when reversed
    { 100, 1 },
    { 120, 21 },
    { -100, -1 },
    { -123, -321 },
    { 1001, 1001 },
})

-- CodingBat: has77
run_test("has77", core.has77, {
    { {1, 7, 7}, true },
    { {1, 7, 1, 7}, true },
    { {1, 7, 1, 1, 7}, false },
    { {7, 7}, true },           -- adjacent pair at start / short array
    { {7, 1, 7}, true },         -- separated by one
    { {7}, false },
    { {}, false },
    { {2, 7, 2, 7}, true },
    { {2, 7, 2, 2, 7}, false },
    { {7, 2, 7, 2}, true },
})

-- CodingBat: has12
run_test("has12", core.has12, {
    { {1, 3, 2}, true },
    { {1, 3, 2, 5}, true },
    { {1}, false },
    { {}, false },
    { {2}, false },
    { {2, 1}, false },           -- 2 before 1 does not count
    { {1, 1, 2}, true },
    { {3, 1, 4, 5, 2}, true },
    { {3, 2, 1}, false },
    { {1, 2}, true },
})

if ltest.meta.total == 0 then
    print("No tests matched filter: " .. tostring(filter))
    print("Usage: ./build test [suite_name]")
    os.exit(1)
end

ltest.finish()
