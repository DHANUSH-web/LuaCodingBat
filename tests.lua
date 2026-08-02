local ltest = require("libs.lua_test")
local core = require("libs.core")

-- pow(base, exp)
ltest.run_test("pow", {
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
ltest.run_test("reverse_number", {
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
ltest.run_test("has77", {
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

-- Bubble Sort
ltest.run_test("bubble_sort", {
    { core.bubble_sort({5, 2, -1, 0, 6}), {-1, 0, 2, 5, 6} },
    { core.bubble_sort({1, 2, 0, -1, -2}), {-2, -1, 0, 1, 2} },
    { core.bubble_sort({200, -2, 1, 0, 3}), {-2, 0, 1, 3, 200} },
    { core.bubble_sort({5}), {5} },
    { core.bubble_sort({}), {} },
    { core.bubble_sort({-1, -2, -3, -4, -5}), {-5, -4, -3, -2, -1} },
})

-- CodingBat: has12
ltest.run_test("has12", {
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

-- CodingBat: matchUp
ltest.run_test("matchUp", {
    { core.matchUp({1, 2, 3}, {2, 3, 10}), 2 },
    { core.matchUp({1, 2, 3}, {2, 3, 5}), 3 },
    { core.matchUp({1, 2, 3}, {2, 3, 3}), 2 },
})

-- CodingBat: modThree
ltest.run_test("modThree", {
    { core.modThree({2, 1, 3, 5}), true },
    { core.modThree({2, 1, 2, 5}), false },
    { core.modThree({2, 4, 2, 5}), true },
})

-- CodingBat: haveThree
ltest.run_test("haveThree", {
    { core.haveThree({3, 1, 3, 1, 3}), true },
    { core.haveThree({3, 1, 3, 3}), false },
    { core.haveThree({3, 4, 3, 3, 4}), false },
})

-- CodingBat: twoTwo
ltest.run_test("twoTwo", {
    { core.twoTwo({4, 2, 2, 3}), true },
    { core.twoTwo({2, 2, 5}), true },
    { core.twoTwo({2, 2, 4, 2}), false },
})

ltest.finish()
