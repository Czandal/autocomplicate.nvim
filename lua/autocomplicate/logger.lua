local dump_to_string = require("autocomplicate.utils").dump_to_string
-- hardcoded, change if you want to see the debug logs from autocomplicate
local log_enabled = false
-- set to file path if you want the logs to be printed
local log_path = nil

---@class logger
---Highly inefficient logger implementation, which should be used only for dev purposes
---@field enabled boolean
---@field log_to_file boolean
---@field log_path string | nil
local logger = {}
logger.__index = logger
function logger:new()
    local obj = setmetatable({}, self)
    obj.enabled = log_enabled
    obj.log_to_file = log_path ~= nil and log_enabled
    obj.log_path = log_path
    return obj
end

function logger:disable()
    self.enabled = false
end
function logger:enable()
    self.enabled = true
end

---@param input any
function logger:echo(input)
    if not self.enabled then
        return
    end
    local time_str = os.date("%Y-%m-%d %H:%M:%", os.time())
    input = string.format("[%s] [ECHO] %s", time_str, dump_to_string(input))
    vim.api.nvim_echo({ { input } }, true, { verbose = true })
end

---@param input any
function logger:info(input)
    if not self.enabled then
        return
    end
    local time_str = os.date("%Y-%m-%d %H:%M:%", os.time())
    input = string.format("[%s] [INFO] %s", time_str, dump_to_string(input))
    print(input)
    if self.log_to_file then
        local f = io.open(self.log_path, "a")
        assert(f, "Can't open log file for append!")
        f:write(input .. "\n")
        f:close()
    end
end

---@param input any
function logger:warn(input)
    if not self.enabled then
        return
    end
    local time_str = os.date("%Y-%m-%d %H:%M:%S", os.time())
    input = string.format("[%s] [WARN] %s", time_str, dump_to_string(input))
    print(input)
    if self.log_to_file then
        local f = io.open(self.log_path, "a")
        assert(f, "Can't open log file for appending!")
        f:write(input .. "\n")
        f:close()
    end
end

---@param input any
function logger:error(input)
    if not self.enabled then
        return
    end
    local time_str = os.date("%Y-%m-%d %H:%M:%S", os.time())
    input = string.format("[%s] [ERROR] %s", time_str, dump_to_string(input))
    print(input)
    if self.log_to_file then
        local f = io.open(self.log_path, "a")
        assert(f, "Can't open log file for appending!")
        f:write(input .. "\n")
        f:close()
    end
end

return logger:new()
