local function ascii_encrypt(text, num)
    local result = {}
    for c in text:gmatch(".") do
        table.insert(result, string.char((c:byte() + num) % 256))
    end
    return table.concat(result)
end

local bx = {[1] = true, [5] = true, [7] = true}
local rk = {[6] = true, [9] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [11] = true, [23] = true, [24] = true, [25] = true}

local function encrypt_constants(chunk)
    local keys = {}

    for i, v in pairs(chunk.constants) do
        if type(v) == "string" then
            local key = math.random(1, 1000)
            keys[i] = key
            chunk.constants[i] = ascii_encrypt(v, key)
        end
    end

    for i, v in pairs(chunk.instructions) do
        if bx[v.opcode] then
            local constant = chunk.constants[v.bx]
            if type(constant) == "string" then
                v.bxkey = keys[v.bx]
            end
        end

        if rk[v.opcode] then
            if v.c > 255 then
                local constant = chunk.constants[v.c - 255]
                if type(constant) == "string" then
                    v.ckey = keys[v.c - 255]
                end
            end

            if v.b > 255 then
                local constant = chunk.constants[v.b - 255]
                if type(constant) == "string" then
                    v.bkey = keys[v.b - 255]
                end
            end
        end
    end

    for _, proto in pairs(chunk.protos) do
        encrypt_constants(proto)
    end
end

return encrypt_constants
