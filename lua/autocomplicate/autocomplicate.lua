local StaggeredTask = require('autocomplicate.staggered_task')
local logger = require('autocomplicate.logger')
local utils = require('autocomplicate.utils')
-- TODO: Handle cursor being at the end of buffer
-- TODO: Setup config
-- host
-- enable/disable
-- add commands
-- clean up the files
-- separate extra variables
local plugin_name = "autocomplicate"
local autocomplicate = {
    namespace = nil,
    hint_id = nil,
    disabled = false,
    deepseek_host = 'http://127.0.0.1:11434/api/generate',
    raw_hint_output_jsons = '',
    hint_complete = true,
    accumulated_hint = '',
    on_close = nil,
    move_trigger = nil,
    lines_in_context = 10,
    allowed_file_types = {},
    blacklisted_file_types = {},
    max_tokens = 32,
}

--- @return integer
function autocomplicate:get_namespace()
    if not self.namespace then
        self.namespace = vim.api.nvim_create_namespace(plugin_name)
    end
    return self.namespace
end

---@return string[]
function autocomplicate:get_current_hint_lines()
    if self.raw_hint_output_jsons ~= nil and #self.raw_hint_output_jsons > 0 then
        local remaining_lines = {}
        local decoded_hint_parts = {}
        for line in self.raw_hint_output_jsons:gmatch("([^\n]*)\n?") do
            -- Ignore lines which do not end with "}" and consider them "incomplete"
            if string.sub(line, -1) == "}" then
                -- TODO: Fix this error, debug why it happens in the first place
                xpcall(function() table.insert(decoded_hint_parts, vim.fn.json_decode(line).response) end, function(err)
                    logger:error({ err, line })
                end)
            else
                table.insert(remaining_lines, line)
            end
        end

        self.raw_hint_output_jsons = table.concat(remaining_lines, "\n")
        self.accumulated_hint = self.accumulated_hint .. table.concat(decoded_hint_parts, '')
    end
    if #self.accumulated_hint > 0 then
        local out = {}
        for line in self.accumulated_hint:gmatch("([^\n]*)\n?") do
            table.insert(out, line)
        end
        if #out > 0 then
            -- remove dangling new line if present
            local last_line = out[#out]
            if string.sub(last_line, -1) == "\n" then
                out[#out] = string.sub(last_line, 0, #last_line - 1)
            end
            -- remove empty line if it is the last one
            last_line = out[#out]
            if last_line == "" then
                table.remove(out)
            end
        end
        if self.hint_complete == false then
            table.insert(out, "(Generating ⏳)")
        end
        return out
    end
    return {}
end


function autocomplicate:clear_hint()
    if self.on_close ~= nil then
        self.on_close()
        self.on_close = nil
    end
    if self.hint_id == nil then
        return
    end
    vim.api.nvim_buf_del_extmark(0, self.get_namespace(self), self.hint_id)
    self.hint_id = nil
end

function autocomplicate:stop()
    self.disabled = true
    self.clear_hint(self)
end

---@return boolean
function autocomplicate:should_run()
    local full_path = vim.api.nvim_buf_get_name(0)
    for filetype in self.blacklisted_file_types do
        if string.find(full_path, filetype) ~= nil then
            return false
        end
    end
    for filetype in self.allowed_file_types do
        if string.find(full_path, filetype) ~= nil then
            return true
        end
    end
    if #self.allowed_file_types < 1 then
        return true
    end
    return false
end

function autocomplicate:start()
    if autocomplicate:should_run() == false then
        return
    end
    self.disabled = false
    self.clear_hint(self)
    self.on_close = self.request_new_hint(self)
end

function autocomplicate:cursor_moved()
    -- stop current generation
    self.clear_hint(self)
    if self.disabled then
        return
    end
    if self.move_trigger and not self.move_trigger.ran then
        self.move_trigger:run_with_stagger(50)
        return
    end
    self.move_trigger = StaggeredTask:new(function()
        self.on_close = self.request_new_hint(self)
    end)
    self.move_trigger:run_with_stagger(50)
end

function autocomplicate:update_hint()
    if self.disabled then
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local hint_lines = self.get_current_hint_lines(self)
    -- nothing to do
    if #hint_lines == 0 then
        return
    elseif #hint_lines == 1 then
        self.hint_id = vim.api.nvim_buf_set_extmark(0, autocomplicate:get_namespace(), row - 1, col, {
            id = self.hint_id,
            hl_group = 'Comment',
            virt_text_pos = 'inline',
            hl_eol = false,
            strict = false,
            virt_text = { { hint_lines[1], 'Comment' } },
        })
        return
    end
    local remnant = utils.read_to_end_of_line(0, row - 1, col)
    local start_of_hint = { { hint_lines[1] .. string.rep(' ', #remnant), 'Comment' } }
    local hint_tail = {}
    for i = 2, #hint_lines - 1 do
        table.insert(hint_tail, { { hint_lines[i], 'Comment' } })
    end
    local last_line = hint_lines[#hint_lines]
    table.insert(hint_tail, { { last_line .. remnant, 'Comment' } })
    self.hint_id = vim.api.nvim_buf_set_extmark(0, autocomplicate:get_namespace(), row - 1, col, {
        id = self.hint_id,
        hl_group = 'Comment',
        virt_text_pos = 'overlay',
        hl_eol = false,
        strict = false,
        virt_text = start_of_hint,
        virt_lines = hint_tail
    })
end

function autocomplicate:accept_hint()
    if self.hint_id == nil then
        return
    end

    local hint_lines = self.get_current_hint_lines(self)
    if #hint_lines == 0 then
        return
    end

    local hint_data =
        vim.api.nvim_buf_get_extmark_by_id(0, self.get_namespace(self), self.hint_id, {})
    local row = hint_data[1]
    local col = hint_data[2]
    -- Add new lines to the buffer
    vim.api.nvim_buf_set_text(0, row, col, row, col, hint_lines)
    -- Move the cursor to the end of the added text
    local row_offset = row + #hint_lines
    local col_offset = col + #hint_lines[1]
    vim.api.nvim_win_set_cursor(0, { row_offset, col_offset })
end

function autocomplicate:get_prefix()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local start_line = row - self.lines_in_context
    -- No need to check boundary, function does it for us
    local lines = vim.api.nvim_buf_get_lines(0, start_line, row, false)
    if #lines < 1 then
        return ""
    end
    local last_line = table.remove(lines):sub(1, col)
    table.insert(lines, last_line)
    return table.concat(lines, "\n")
end

function autocomplicate:get_suffix()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local end_line = row + self.lines_in_context
    -- No need to check boundary, function does it for us
    local lines = vim.api.nvim_buf_get_lines(0, row - 1, end_line, false)
    if #lines < 1 then
        return ""
    end
    local first_line = string.sub(lines[1], col + 1)
    lines[1] = first_line
    return table.concat(lines, "\n")
end

function autocomplicate:request_new_hint()
    local closed = false
    self.hint_complete = false
    self.raw_hint_output_jsons = ""
    self.accumulated_hint = ''
    local handle
    local update_hint_with_stagger = StaggeredTask:new(function()
        self.update_hint(self)
    end)
    local payload = {
        model = 'deepseek-coder-v2',
        prompt = self.get_prefix(self),
        suffix = self.get_suffix(self),
        max_tokens = self.max_tokens
    }
    logger:echo("requesting")
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    ---@diagnostic disable-next-line: missing-fields
    handle = vim.uv.spawn("curl", {
        hide = true,
        detached = true,
        args = {
            "--silent", "--location", self.deepseek_host,
            "-X", "POST",
            "--data", vim.fn.json_encode(payload),
            "--header", "Content-Type: application/json"
        }, -- Replace with your URL
        stdio = { nil, stdout, stderr }
    }, function(code, signal)
        if code ~= 0 then
            logger:error({ "Failed to retrieve autosuggestion, process exited", code, signal })
        end
        logger:info("Finished retrieving data from autosuggestion server")
        self.hint_complete = true
        handle:close()
    end)
    if stdout then
        vim.uv.read_start(stdout, function(err, data)
            if self.disabled or closed then
                return
            end
            if err then
                logger:error({"Failure", err})
                return
            end
            if data and #data > 0 then
                self.raw_hint_output_jsons = self.raw_hint_output_jsons .. data
                update_hint_with_stagger:run_with_stagger(15)
            end
        end)
    end
    if stderr then
        vim.uv.read_start(stderr, function(err, data)
            if self.disabled or closed then
                return
            end
            if err then
                logger:error({"Failure", err})
                return
            end
            if data then
                self.raw_hint_output_jsons = self.raw_hint_output_jsons .. data
                update_hint_with_stagger:run_with_stagger(15)
            end
        end)
    end
    return function()
        logger:info("On Close called")
        closed = true
        self.hint_complete = true
        update_hint_with_stagger:stop()
    end
end

--#region Globals

function AutocomplicateDebug()
    autocomplicate:cursor_moved()
end

function AutocomplicateDebug2()
    autocomplicate:stop()
end

function AutocomplicateStart()
    autocomplicate:start()
end

function AutocomplicateCursorMoved()
    autocomplicate:cursor_moved()
end

function AutocomplicateStop()
    autocomplicate:stop()
end

function AutocomplicateAcceptHint()
    autocomplicate:accept_hint()
    autocomplicate:clear_hint()
end

function AutocomplicateRejectHint()
    autocomplicate:clear_hint()
end

function AutocomplicateRefreshHint()
    autocomplicate:cursor_moved()
end

---@class AutocomplicateConfig
---@field register_autocmd? boolean defaults to false
---@field host? string defaults to http://localhost:11434/api/generate
---@field context_line_size? integer defaults to 10
---@field max_tokens? integer defaults to 32
---@field allowed_file_types? string[] if empty starts the autocomplicate for all kind of files
---can use patterns, but string.find is used under the hood so one needs to use ".*"
---@field blacklisted_file_types? string[] if empty defaults to empty list
---can use patterns, but string.find is used under the hood so one needs to use ".*" instead of "*" to match any string
---@field default_keymaps? boolean defaults to false

---@param config AutocomplicateConfig
function autocomplicate.setup(config)
    autocomplicate.lines_in_context = config.context_line_size or 10
    autocomplicate.deepseek_host = config.host or "http://localhost:11434/api/generate"
    autocomplicate.allowed_file_types = config.allowed_file_types or {}
    autocomplicate.blacklisted_file_types = config.blacklisted_file_types or {}
    autocomplicate.max_tokens = config.max_tokens or 32
    --#region autocmd
    if config.register_autocmd then
        vim.api.nvim_command('autocmd InsertEnter * lua AutocomplicateStart()')
        vim.api.nvim_command('autocmd CursorMovedI * lua AutocomplicateCursorMoved()')
        vim.api.nvim_command('autocmd InsertLeave * lua AutocomplicateStop()')
    end
    --#endregion autocmd
    --#region register nvim commands
    vim.api.nvim_create_user_command("AutocomplicateStart", function()
        AutocomplicateStart()
    end, { desc = "Start pulling autosuggestions from LLM server" })
    vim.api.nvim_create_user_command("AutocomplicateStop", function ()
        AutocomplicateStop()
    end, { desc = "Stop autocomplicate" })
    vim.api.nvim_create_user_command("AutocomplicateAcceptHint", function()
        AutocomplicateAcceptHint()
    end, { desc = "Accept autocomplicate complete autosuggestion" })
    vim.api.nvim_create_user_command("AutocomplicateRejectHint", function ()
        AutocomplicateRejectHint()
    end, { desc = "Reject autocomplicate complete autosuggestion" })
    vim.api.nvim_create_user_command("AutocomplicateRefreshHint", function ()
        AutocomplicateRefreshHint()
    end, { desc = "Refresh autocomplicate autosuggestion" })
    --#endregion register nvim commands
    --#region keymaps
    if config.default_keymaps then
        vim.keymap.set("i", "<C-S>", "<CMD>AutocomplicateAcceptHint<CR>", { desc = "Accept autocomplicate autosuggestion" })
        vim.keymap.set("i", "<C-R>", "<CMD>AutocomplicateRejectHint<CR>", { desc = "Reject autocomplicate autosuggestion" })
        vim.keymap.set("i", "<C-X>", "<CMD>AutocomplicateRefreshHint<CR>", { desc = "Refresh autocomplicate autosuggestion" })
    end
    --#endregion keymaps
end
return autocomplicate

