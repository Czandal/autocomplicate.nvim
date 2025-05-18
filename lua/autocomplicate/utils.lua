---@param buffernum integer 0 for current
---@param row integer
---@param col integer
local function read_to_end_of_line(buffernum, row, col)
    return vim.api.nvim_buf_get_text(buffernum, row, col, row, -1, {})[1]
end

---@param o any
---@return string
local function dump_to_string(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump_to_string(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

return {
    read_to_end_of_line = read_to_end_of_line,
    dump_to_string = dump_to_string,
}
