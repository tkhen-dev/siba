local function cp(t)
    local t2 = {}
    for i, v in pairs(t) do
        t2[i] = type(v) == "table" and cp(v) or v
    end
    return t2
end

local iAsBx = {[22] = true, [31] = true, [32] = true}

local function find(t, val)
    for i, v in pairs(t) do
        if v == val then
            return i
        end
    end
end

local function breakdown(chunk, max_stack_size)
    local inst_map = {}

    for i, v in pairs(chunk.instructions) do
        if iAsBx[v.opcode] then
            local referenced_inst = chunk.instructions[v.sbx + 1 + i]

            if referenced_inst then
                local key = tostring(referenced_inst)
                if inst_map[key] then
                    table.insert(inst_map[key], v)
                else
                    inst_map[key] = {v}
                end
            end
        end
    end
    
    local new_instructions = {}

    for i, v in pairs(chunk.instructions) do
        local t = tostring(v)
        local instrs = inst_map[t]
        if instrs then
            for _, instr in pairs(instrs) do
                instr.point_to = #new_instructions + 1
            end
        end

        if v.opcode == 3 then
            local new_instr = {opcode = 1, bx = #chunk.constants + 1}
            local initial, limit = v.a, v.b

            if initial == limit then
                new_instr.a = initial
                table.insert(new_instructions, new_instr)
            else
                for j = initial, limit do
                    local copy = cp(new_instr)
                    copy.a = j
                    table.insert(new_instructions, copy)
                end
            end 
        elseif v.opcode == 2 then
            local new_instr = {opcode = 2, a = v.a, b = v.b, c = 0}
            table.insert(new_instructions, new_instr)
            
            if v.c ~= 0 then
                table.insert(new_instructions, {opcode = 22, a = 0, sbx = 1, correct = true})
            end
        elseif v.opcode == 5 then
            if v.bx < 255 and max_stack_size < 510 then
                table.insert(new_instructions, {opcode = 6, a = v.a, b = max_stack_size + 1, c = v.bx + 255})
            else
                table.insert(new_instructions, v)
            end
        elseif v.opcode == 7 then
            if v.bx < 255 and max_stack_size < 510 then
                table.insert(new_instructions, {opcode = 9, a = max_stack_size + 1, b = v.bx + 255, c = v.a})
            else
                table.insert(new_instructions, v)
            end
        elseif v.opcode == 11 then
            table.insert(new_instructions, {opcode = 0, a = v.a + 1, b = v.b, c = 256})
            table.insert(new_instructions, {opcode = 6, a = v.a, b = v.b, c = v.c})
        elseif v.opcode == 29 then
            table.insert(new_instructions, {opcode = 28, a = v.a, b = v.b, c = 0})
            table.insert(new_instructions, {opcode = 30, a = v.a, b = 0, c = 0})
        else
            table.insert(new_instructions, v)
        end
    end

    for i, v in pairs(new_instructions) do
        if iAsBx[v.opcode] then
            if not v.correct then
                local pcpp = i + 1
                v.sbx = v.point_to - pcpp
                v.point_to = nil
            else
                v.correct = nil
            end
        end
    end

    for _, proto in pairs(chunk.protos) do
        breakdown(proto, max_stack_size)
    end

    chunk.instructions = new_instructions
end

return breakdown
