local LuaTest = {}

LuaTest.meta = {
    total = 0,
    passed = 0,
    failed = 0
}

function LuaTest.assert_true(name, callback)
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.failed = LuaTest.meta.failed + 1

    assert(callback, "TEST::" .. name .. "::FAILED -> Expected 'true' but got 'false'")
    print("TEST::" .. name .. "::PASSED")

    LuaTest.meta.passed = LuaTest.meta.passed + 1
    LuaTest.meta.failed = LuaTest.meta.failed - 1
end

function LuaTest.assert_false(name, callback)
    LuaTest.meta.total = LuaTest.meta.total + 1
    LuaTest.meta.failed = LuaTest.meta.failed + 1

    assert(not callback, "TEST::" .. name .. "::FAILED -> Expected 'false' but got 'true'");
    print("TEST::" .. name .. "::PASSED")

    LuaTest.meta.passed = LuaTest.meta.passed + 1
    LuaTest.meta.failed = LuaTest.meta.failed - 1
end

function LuaTest.assert_equals(name, actual, expected)
    LuaTest.meta.passed = LuaTest.meta.total + 1
    LuaTest.meta.failed = LuaTest.meta.failed + 1

    assert(actual == expected, "TEST::" .. name .. "::FAILED -> Expected '" .. expected .. "' but got '" .. actual .. "'")
    print("TEST::" .. name .. "::PASSED")

    LuaTest.meta.passed = LuaTest.meta.passed + 1
    LuaTest.meta.failed = LuaTest.meta.failed - 1
end

return LuaTest;
