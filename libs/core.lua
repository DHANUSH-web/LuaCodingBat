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

-- Bubble Sort
function core.bubble_sort(nums)
    for i = 1, #nums do
        for j = 1, i do
            if nums[i] < nums[j] then
                nums[i], nums[j] = nums[j], nums[i]
            end
        end
    end

    return nums
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

function core.modThree(nums)
    for i = 1, #nums-2 do
        if (nums[i]   % 2 == 0 and
            nums[i+1] % 2 == 0 and
            nums[i+2] % 2 == 0
        ) or (
            nums[i]   % 2 == 1 and
            nums[i+1] % 2 == 1 and
            nums[i+2] % 2 == 1
        ) then
            return true
        end
    end

    return false
end

function core.haveThree(nums)
    local three_count = 0

    for i = 1, #nums - 1 do
        if nums[i] == 3 and nums[i + 1] ~= 3 then
            three_count = three_count + 1
        end

        if nums[i] == 3 and nums[i + 1] == 3 then
            return false
        end
    end

    if #nums > 2 and nums[#nums] == 3 and nums[#nums - 1] ~= 3 then
        three_count = three_count + 1
    end

    return three_count == 3
end

function core.twoTwo(nums)
    if #nums == 0 then
        return true
    elseif #nums == 1 then
        return nums[1] ~= 2
    end

    local count = 0
    local i = 1
    local couple = false
    local only, both

    while i < #nums do
        only = (nums[i] == 2 and nums[i+1] ~= 2) or (nums[i] ~= 2 and nums[i+1] == 2)
        both = nums[i] == 2 and nums[i+1] == 2

        if only then
            couple = false
            count = count + 1
        end

        if both then
            couple = true
            i = i + 1
        end

        i = i + 1
    end

    return couple or count == 0
end

-- CodingBat: END
return core
