local core = {}

function core.pow(base, exp)
    local value = 1

    if base > 0 then
        for _ = 0, exp-1 do
            value = value * base
        end
    end

    return value
end

function core.reverse_number(number)
    if (number <= math.mininteger or number >= math.maxinteger) then
        error(number .. " should be >= " .. math.mininteger .. " and <= " .. math.maxinteger)
    end

    local rnumber = 0
    local n = number < 0 and math.abs(number) or number

    while n > 0 do
        rnumber = rnumber * 10 + (n % 10)
        n = n // 10
    end

    return number < 0 and -rnumber or rnumber
end

-- CodingBat: BEGIN

function core.has77(nums)
    for i = 1, #nums-2 do
        if (nums[i] == 7 and (nums[i+1] == 7 or nums[i+2] == 7)) or (nums[i+1] == 7 and nums[i+2] == 7) then
            return true
        end
    end

    return false
end

function core.has12(nums)
    local found = false

    for i = 0, #nums do
        if nums[i] == 1 and not found then
            found = true
        end

        if nums[i] == 2 and found then
            return true;
        end
    end

    return false
end

-- CodingBat: END
return core
