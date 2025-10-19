local log_level = 0
local message = "%s | [%s] | %s"
local auto_reset = true

local colours = {
    grey = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    reset = 37
}

local log_levels = {
    info = 1,
    debug = 2,
    warning = 3,
    error = 4
}

local log_functions = {
    info = {level = 1, colour = "green"},
    debug = {level = 2, colour = "blue"},
    warning = {level = 3, colour = "yellow"},
    error = {level = 4, colour = "red"}
}

local function colourise(message, colour)
    return string.format("\27[%sm%s", colours[colour], message)
end

local function reset()
    return io.write(colourise("", "reset"))
end

local function get_log_level()
    return log_level
end

local function set_log_level(level)
    log_level = level
end

local function log(name, msg, colour)
    if log_level > log_levels[name] then return end

    print(colourise(string.format(message, os.date("%F %T"), name:upper(), msg), colour))

    if auto_reset then
        reset()
    end
end

local function info(msg)
    log("info", msg, "green")
end

local function debug(msg)
    log("debug", msg, "blue")
end

local function warning(msg)
    log("warning", msg, "yellow")
end

local function error(msg)
    log("error", msg, "red")
end

return {
    log_level = log_levels,
    get_log_level = get_log_level,
    set_log_level = set_log_level,
    info = info,
    debug = debug,
    warning = warning,
    error = error
}
