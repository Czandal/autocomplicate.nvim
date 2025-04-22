---@class StaggeredTask
---@field task function
---@field timer uv.uv_timer_t
---@field ran boolean
local StaggeredTask = {}
StaggeredTask.__index = StaggeredTask
---comment
---@param task function
function StaggeredTask:new(task)
    local obj = setmetatable({}, self)
    obj.task = task
    local new_timer = vim.uv.new_timer()
    if new_timer == nil then
        error("Failed to initialize timer")
    end
    obj.timer = new_timer
    obj.ran = false
    return obj
end

---Resets the stagger on the task run,
---if there is none it starts the timer to run it within the time defined by the param
---@param stagger_ms number
function StaggeredTask:run_with_stagger(stagger_ms)
    self.ran = false
    if self.timer ~= nil then
        self.timer.stop(self.timer)
    end
    self.timer:start(stagger_ms, 0, function()
        self.ran = true
        self.task()
    end)
end

---Stops the task from running
function StaggeredTask:stop()
    if self.timer ~= nil then
        self.timer.stop(self.timer)
    end
end

--- closes the timer handle and frees the memory
function StaggeredTask:close()
    if self.timer ~= nil and not self.timer:is_closing() then
        self.timer:close()
    end
end
return StaggeredTask
