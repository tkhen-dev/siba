local rk_instrs = {
    rkc = {[6] = true, [11] = true},
    rkbc = {[9] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [23] = true, [24] = true, [25] = true}
}

local kst_instrs = {[1] = true, [5] = true, [7] = true}
local upvalue_instrs = {[4] = true, [8] = true}

local function handle_kst(instr)
    if kst_instrs[instr.opcode] then
        instr.bx = instr.bx + 1
    end
end

local function handle_upvalue(instr)
    if upvalue_instrs[instr.opcode] then
        instr.b = instr.b + 1
    end
end

local function handle_rk(instr, only_rk)
    if rk_instrs.rkc[instr.opcode] then
        -- handle rkc
    elseif rk_instrs.rkbc[instr.opcode] or only_rk then
        if instr.b > 255 then
            instr.kb = instr.b - 255
        end
    else
        return
    end

    if instr.c > 255 then
        instr.kc = instr.c - 255
    end
end

local function handle_proto(instr)
    if instr.opcode == 36 then
        instr.bx = instr.bx + 1
    end
end

local function rectify_instructions(chunk, only_rk)
    local instrs = chunk.instructions

    for _, instr in pairs(instrs) do
        handle_rk(instr, only_rk)
        if not only_rk then
            handle_kst(instr)
            handle_upvalue(instr)
            handle_proto(instr)
        end
    end
end

local function rectify(chunk, only_rk)
    only_rk = only_rk or false
    rectify_instructions(chunk, only_rk)

    for _, proto in pairs(chunk.protos) do
        rectify(proto, only_rk)
    end
end

return rectify
