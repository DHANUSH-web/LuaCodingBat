local ltest = require("libs.lua_test")
local core = require("libs.core")

--- Optional filter: `./build test has77` runs only matching suite names.
local filter = arg and arg[1] or nil

local function should_run(name)
    return filter == nil or filter == name
end

local function run_boolean_cases(suite_name, fn, cases)
    if not should_run(suite_name) then
        return
    end

    for i, case in ipairs(cases) do
        local input, expected = case[1], case[2]
        local label = suite_name .. "#" .. i
        if expected then
            ltest.assert_true(label, fn(input))
        else
            ltest.assert_false(label, fn(input))
        end
    end
end

-- CodingBat: has77
run_boolean_cases("has77", core.has77, {
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
run_boolean_cases("has12", core.has12, {
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
