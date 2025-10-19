local function equal(t1, t2)
    if type(t1) ~= type(t2) then
        return false
    end

    if type(t1) ~= "table" then
        return t1 == t2
    end

    for i, v in pairs(t1) do
        if type(v) == "table" then
            if not equal(v, t2[i]) then
                return false
            end
        elseif v ~= t2[i] then
            return false
        end
    end

    for i in pairs(t2) do
        if t1[i] == nil then
            return false
        end
    end

    return true
end

local function find(t, val)
    for i, v in pairs(t) do
        if equal(v, val) then
            return i
        end
    end
end

local function bfs(chunk)
    local visited = {}
    local queue = {}
    local order = {}

    visited[chunk] = true
    table.insert(queue, chunk)

    while #queue > 0 do
        local element = table.remove(queue, 1)
        table.insert(order, element)

        for _, v in pairs(element.protos or {}) do
            if not visited[v] then
                visited[v] = true
                table.insert(queue, v)
            end
        end
    end

    return order
end

local function offset(chunk)
    local order = bfs(chunk)
    local instr_offset = 1

    for _, v in pairs(order) do
        v.instr_offset = instr_offset
        local count = #v.instructions
        instr_offset = instr_offset + count
    end

    return order
end

return offset
