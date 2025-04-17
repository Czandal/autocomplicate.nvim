---@param buffernum integer 0 for current
---@param row integer
---@param col integer
local function read_to_end_of_line (buffernum, row, col)
    return vim.api.nvim_buf_get_text(buffernum, row, col, row, -1, {})[1]
end

return {
    read_to_end_of_line = read_to_end_of_line,
}

