local serializer = {}

local logging = require("../logging/logger.lua")

local flags = {
    boolean = "000",
    number = "001",
    string = "010",
    instruction = "011",
    upvalue = "100",
    proto = "101",
    userdata = "110",
    double = "111"
}

local a, b, c, bx, sbx = "a", "b", "c", "bx", "sbx"

local opcode_mappings = {
    iABC = {[0]=true,[2]=true,[3]=true,[4]=true,[6]=true,[8]=true,[9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true,[17]=true,[18]=true,[19]=true,[20]=true,[21]=true,[23]=true,[24]=true,[25]=true,[26]=true,[27]=true,[28]=true,[29]=true,[30]=true,[33]=true,[34]=true,[35]=true,[37]=true},
    iABx = {[1]=true,[5]=true,[7]=true,[36]=true},
    iAsBx = {[22]=true,[31]=true,[32]=true}
}

local function leftpad(str, count, char)
    char = char or "0"
    return char:rep(math.max(0, count - #str)) .. str
end

local function to_bits(num)
    if num == 0 then return "" end
    local bit_rep = ""
    while num > 0 do
        bit_rep = (num % 2) .. bit_rep
        num = bit.rshift(num, 1)
    end
    return bit_rep
end

function serializer.spread_chunk(chunk)
    local sorted_chunk = {}

    table.insert(sorted_chunk, chunk.upvalue_count)
    table.insert(sorted_chunk, chunk.instr_offset)

    for _, upvalue in pairs(chunk.upvalues) do
        table.insert(sorted_chunk, upvalue)
    end

    local total_count = #chunk.instructions + #chunk.constants + #chunk.protos

    while total_count > 0 do
        local valids = {}
        local proto_idx = 0

        if #chunk.instructions > 0 then
            table.insert(valids, chunk.instructions)
        end
        if #chunk.constants > 0 then
            table.insert(valids, chunk.constants)
        end
        if #chunk.protos > 0 then
            table.insert(valids, chunk.protos)
            proto_idx = #valids
        end

        if #valids == 0 then break end

        local selection = math.random(1, #valids)
        local item = table.remove(valids[selection], 1)

        if selection == proto_idx then
            item = serializer.spread_chunk(item)
        end

        table.insert(sorted_chunk, item)
        total_count = total_count - 1
    end

    return sorted_chunk
end

function serializer.chunk(sorted_chunk, top_level)
    top_level = top_level ~= false

    local pointer = 1
    local bytecode = top_level and flags.proto or ""

    local upvalue_count = sorted_chunk[pointer]
    bytecode = bytecode .. serializer.constant(upvalue_count)
    pointer = pointer + 1

    local instr_offset = sorted_chunk[pointer]
    bytecode = bytecode .. serializer.constant(instr_offset)

    for i = 1, upvalue_count do
        pointer = pointer + 1
        bytecode = bytecode .. serializer.upvalue(sorted_chunk[pointer])
    end

    while pointer < #sorted_chunk do
        pointer = pointer + 1

        local item = sorted_chunk[pointer]
        if type(item) == "table" then
            if type(item[1]) == "number" then
                bytecode = bytecode .. flags.proto .. serializer.chunk(item, false)
            else
                bytecode = bytecode .. serializer.instruction(item)
            end
        else
            bytecode = bytecode .. serializer.constant(item)
        end
    end

    if not top_level then
        bytecode = serializer.constant(#bytecode) .. bytecode
    end

    return bytecode
end

function serializer.constant(const)
    local typ = type(const)
    local bytecode = flags[typ]

    if typ == "boolean" then
        bytecode = bytecode .. (const and "1" or "0")
    elseif typ == "number" then
        if const == 0 or tostring(const) == "1.1125369292536e-308" then
            const = 0
        end

        local str_num = tostring(const)
        local dot_pos = str_num:find("%.")

        if dot_pos then
            bytecode = flags.double
            local int = str_num:sub(1, dot_pos - 1)
            local dec = str_num:sub(dot_pos + 1)
            bytecode = bytecode .. serializer.constant(tonumber(int)) .. serializer.constant(tonumber(dec))
        else
            if const > 2147483647 then
                logging.error("serializing number > 32 bits")
            end
            bytecode = bytecode .. leftpad(to_bits(const), 32)
        end
    elseif typ == "string" then
        bytecode = bytecode .. serializer.constant(#const)

        for c in const:gmatch(".") do
            bytecode = bytecode .. leftpad(to_bits(c:byte()), 8)
        end
    end

    return bytecode
end

function serializer.instruction(instr)
    local bytecode = flags.instruction
    bytecode = bytecode .. leftpad(to_bits(instr[a]), 8)

    if opcode_mappings.iABC[instr.opcode] then
        bytecode = bytecode .. leftpad(to_bits(instr[b]), 9) .. leftpad(to_bits(instr[c]), 9)
    elseif opcode_mappings.iABx[instr.opcode] then
        bytecode = bytecode .. leftpad(to_bits(instr[bx]), 18)
    elseif opcode_mappings.iAsBx[instr.opcode] then
        local val = instr[sbx]
        if val > 0 then
            bytecode = bytecode .. "0" .. leftpad(to_bits(val), 17)
        else
            bytecode = bytecode .. "1" .. leftpad(to_bits(math.abs(val)), 17)
        end
    end

    return bytecode
end

function serializer.upvalue(upvalue)
    return flags.upvalue .. serializer.constant(upvalue)
end

return serializer
