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

-- True if the array has two 7s next to each other, or separated by one element.
function core.has77(nums)
    for i = 1, #nums - 1 do
        if nums[i] == 7 then
            if nums[i + 1] == 7 then
                return true
            end
            if i + 2 <= #nums and nums[i + 2] == 7 then
                return true
            end
        end
    end

    return false
end

-- True if there is a 1 in the array with a 2 somewhere later in the array.
function core.has12(nums)
    local found_one = false

    for i = 1, #nums do
        if nums[i] == 1 then
            found_one = true
        elseif nums[i] == 2 and found_one then
            return true
        end
    end

    return false
end

function core.matchUp(nums1, nums2)
    local count = 0

    for i = 1, #nums1 do
        if not (nums1[i] == nums2[i]) and (math.abs(nums1[i] - nums2[i]) <= 2) then
            count = count + 1
        end
    end

    return count
end

-- CodingBat: END
return core
