local deserialize = require("./bytecode/deserialize.lua")
local rectify = require("./bytecode/rectify.lua")
local logging = require("./logging/logger.lua")

local a, b, c, bx, sbx = "a", "b", "c", "bx", "sbx"
local kb, kc = "kb", "kc"

local debug_mode = false

local function get_value(instr, field, chunk, stack)
    local k_field = field == "b" and kb or field == "c" and kc
    if k_field and instr[k_field] then
        return chunk.constants[instr[k_field]]
    end
    return stack[instr[field]]
end

local function compile(chunk)
    local function runner(...)
        local instructions = chunk.instructions
        local constants = chunk.constants
        local protos = chunk.protos
        local upvalues = chunk.upvalues
        local top = 1
        
        local stack = setmetatable({}, {
            __newindex = function(t, k, v)
                if k > top then top = k end
                rawset(t, k, v)
            end
        })

        local args = {...}
        for i = 0, #args - 1 do
            stack[i] = args[i + 1]
        end

        local instruction_pointer = 1
        
        while true do
            local instr = instructions[instruction_pointer]
            local opcode = instr.opcode

            if debug_mode then
                p(instruction_pointer, stack)
            end

            if opcode == 0 then
                stack[instr[a]] = stack[instr[b]]
            elseif opcode == 1 then
                stack[instr[a]] = constants[instr[bx]]
            elseif opcode == 2 then
                stack[instr[a]] = instr[b] ~= 0
                if instr[c] ~= 0 then
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 4 then
                stack[instr[a]] = upvalues[instr[b]]
            elseif opcode == 5 then
                stack[instr[a]] = getfenv()[constants[instr[bx]]]
            elseif opcode == 6 then
                stack[instr[a]] = stack[instr[b]][get_value(instr, "c", chunk, stack)]
            elseif opcode == 7 then
                getfenv()[constants[instr[bx]]] = stack[instr[a]]
            elseif opcode == 8 then
                upvalues[instr[b]] = stack[instr[a]]
            elseif opcode == 9 then
                stack[instr[a]][get_value(instr, "b", chunk, stack)] = get_value(instr, "c", chunk, stack)
            elseif opcode == 10 then
                stack[instr[a]] = {}
            elseif opcode == 11 then
                stack[instr[a] + 1] = stack[instr[b]]
                stack[instr[a]] = stack[instr[b]][get_value(instr, "c", chunk, stack)]
            elseif opcode == 12 then
                stack[instr[a]] = get_value(instr, "b", chunk, stack) + get_value(instr, "c", chunk, stack)
            elseif opcode == 13 then
                stack[instr[a]] = get_value(instr, "b", chunk, stack) - get_value(instr, "c", chunk, stack)
            elseif opcode == 14 then
                stack[instr[a]] = get_value(instr, "b", chunk, stack) * get_value(instr, "c", chunk, stack)
            elseif opcode == 15 then
                stack[instr[a]] = get_value(instr, "b", chunk, stack) / get_value(instr, "c", chunk, stack)
            elseif opcode == 16 then
                stack[instr[a]] = get_value(instr, "b", chunk, stack) % get_value(instr, "c", chunk, stack)
            elseif opcode == 17 then
                stack[instr[a]] = get_value(instr, "b", chunk, stack) ^ get_value(instr, "c", chunk, stack)
            elseif opcode == 18 then
                stack[instr[a]] = -stack[instr[b]]
            elseif opcode == 19 then
                stack[instr[a]] = not stack[instr[b]]
            elseif opcode == 20 then
                stack[instr[a]] = #stack[instr[b]]
            elseif opcode == 21 then
                local result = {}
                for i = instr[b], instr[c] do
                    table.insert(result, stack[i])
                end
                stack[instr[a]] = table.concat(result)
            elseif opcode == 22 then
                instruction_pointer = instruction_pointer + instr[sbx]
            elseif opcode == 23 then
                if (get_value(instr, "b", chunk, stack) == get_value(instr, "c", chunk, stack)) ~= (instr[a] ~= 0) then
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 24 then
                if (get_value(instr, "b", chunk, stack) < get_value(instr, "c", chunk, stack)) ~= (instr[a] ~= 0) then
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 25 then
                if (get_value(instr, "b", chunk, stack) <= get_value(instr, "c", chunk, stack)) ~= (instr[a] ~= 0) then
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 26 then
                if not (stack[instr[a]] == (instr[c] ~= 0)) then
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 27 then
                if stack[instr[b]] == (instr[c] ~= 0) then
                    stack[instr[a]] = stack[instr[b]]
                else
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 28 then
                local func = stack[instr[a]]
                local call_args = {}

                local lim = instr[b] == 0 and top + 1 or instr[a] + instr[b] - 1
                for i = instr[a] + 1, lim do
                    table.insert(call_args, stack[i])
                end

                top = instr[a] - 1
                local results = {func(unpack(call_args))}

                if instr[c] == 0 then
                    for i = 0, #results - 1 do
                        stack[instr[a] + i] = results[i + 1]
                    end
                elseif instr[c] > 1 then
                    for i = 0, instr[c] - 2 do
                        stack[instr[a] + i] = results[i + 1]
                    end
                end
            elseif opcode == 29 then
                local func = stack[instr[a]]
                local call_args = {}

                local lim = instr[b] == 0 and top + 1 or instr[a] + instr[b] - 1
                for i = instr[a] + 1, lim do
                    table.insert(call_args, stack[i])
                end

                return func(unpack(call_args))
            elseif opcode == 30 then
                local results = {}

                if instr[b] == 0 then
                    for i = instr[a], top do
                        table.insert(results, stack[i])
                    end
                elseif instr[b] > 1 then
                    for i = 0, instr[b] - 2 do
                        table.insert(results, stack[instr[a] + i])
                    end
                end

                return unpack(results)
            elseif opcode == 31 then
                stack[instr[a]] = stack[instr[a]] + stack[instr[a] + 2]

                if stack[instr[a] + 2] > 0 then
                    if stack[instr[a]] <= stack[instr[a] + 1] then
                        instruction_pointer = instruction_pointer + instr[sbx]
                        stack[instr[a] + 3] = stack[instr[a]]
                    end
                else
                    if stack[instr[a]] >= stack[instr[a] + 1] then
                        instruction_pointer = instruction_pointer + instr[sbx]
                        stack[instr[a] + 3] = stack[instr[a]]
                    end
                end
            elseif opcode == 32 then
                stack[instr[a]] = stack[instr[a]] - stack[instr[a] + 2]
                instruction_pointer = instruction_pointer + instr[sbx]
            elseif opcode == 33 then
                local results = {stack[instr[a]](stack[instr[a] + 1], stack[instr[a] + 2])}

                for i = 1, instr[c] do
                    stack[instr[a] + 2 + i] = results[i]
                end

                if stack[instr[a] + 3] then
                    stack[instr[a] + 2] = stack[instr[a] + 3]
                else
                    instruction_pointer = instruction_pointer + 1
                end
            elseif opcode == 34 then
                if instr[c] == 0 then
                    logging.error("fuck this")
                end

                local lim = instr[b] == 0 and top - instr[a] + 1 or instr[b]
                for i = 1, lim do
                    stack[instr[a]][(instr[c] - 1) * 50 + i] = stack[instr[a] + i]
                end
            elseif opcode == 36 then
                local proto = protos[instr[bx]]
                
                if proto.upvalue_count == 0 then
                    stack[instr[a]] = compile(proto)
                else
                    local tkpairs = {}
                    local upvalue_indexing = setmetatable({}, {
                        __index = function(_, key)
                            local pair = tkpairs[key]
                            return pair[1][pair[2]]
                        end,
                        __newindex = function(_, key, value)
                            local pair = tkpairs[key]
                            pair[1][pair[2]] = value
                        end
                    })

                    for i = 1, proto.upvalue_count do
                        instruction_pointer = instruction_pointer + 1
                        local pseudo = instructions[instruction_pointer]

                        if pseudo.opcode == 0 then
                            tkpairs[i] = {stack, pseudo[b]}
                        elseif pseudo.opcode == 4 then
                            logging.error("nyi")
                        end
                    end

                    proto.upvalues = upvalue_indexing
                    stack[instr[a]] = compile(proto)
                end
            elseif opcode == 37 then
                top = instr[a] - 1
                for i = 0, instr[b] - 1 do
                    stack[instr[a] + i] = args[i + 1]
                end
            end

            instruction_pointer = instruction_pointer + 1
        end
    end

    return runner
end

local function main(bytecode)
    local output = deserialize(bytecode)
    rectify(output)
    compile(output)()
end

local function no_parse(chunk)
    compile(chunk)()
end

return {
    run = main,
    interpret = no_parse
}
