local M = {}

---@param opts? AutocomplicateConfig
function M.setup(opts)
    require("autocomplicate.autocomplicate").setup(opts or {})
end

return M
