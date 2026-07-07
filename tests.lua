local ltest = require("libs.lua_test")
local core = require("libs.core")

local function test_has77()
  ltest.assert_true("has77", core.has77({1, 7, 7}))
  ltest.assert_true("has77", core.has77({1, 7, 1, 7}))
  ltest.assert_false("has77", core.has77({1, 7, 1, 1, 7}))
end

local function test_has12()
  ltest.assert_true("has12", core.has12({1, 3, 2}))
  ltest.assert_true("has12", core.has12({1, 3, 2, 5}))
  ltest.assert_false("has12", core.has12({1}))
end

-- Run test cases
test_has77()
test_has12()

print("======================= TEST RESULTS =======================")
print("Total\t:", ltest.meta.total)
print("Passed\t:", ltest.meta.passed)
print("Failed\t:", ltest.meta.failed)
print("============================================================")
