local logger = require("autocomplicate.logger")

---@param url string
---@param prefix string
---@param suffix string
---@param llm_model string
---@param options AutocomplicateLlmOptions
---@param error_handler function takes error
---@param data_consumer function takes data
---@param ack_cb function called when request is closed/done
---@return function
local function request_hint(
    url,
    prefix,
    suffix,
    llm_model,
    options,
    error_handler,
    data_consumer,
    ack_cb
)
    local closed = false
    local handle
    local payload = {
        model = llm_model,
        prompt = prefix,
        suffix = suffix,
        options = options,
        stream = false,
    }
    logger:info({ "requesting", time = vim.uv.hrtime() })
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    ---@diagnostic disable-next-line: missing-fields
    handle = vim.uv.spawn("curl", {
        hide = true,
        detached = true,
        args = {
            "--silent",
            "--no-buffer",
            "--location",
            url,
            "-X",
            "POST",
            "--data",
            vim.fn.json_encode(payload),
            "--header",
            "Content-Type: application/json",
        },
        stdio = { nil, stdout, stderr },
    }, function(code, signal)
        if code ~= 0 then
            logger:error({
                "Failed to retrieve autosuggestion, process exited",
                code,
                signal,
            })
            error_handler(code)
        end
        logger:info("Finished retrieving data from autosuggestion server")
        if closed ~= true then
            closed = true
            ack_cb()
            handle:close()
        end
    end)
    if stdout then
        vim.uv.read_start(stdout, function(err, data)
            if closed then
                return
            end
            if err then
                logger:error({ "Failure", err })
                error_handler(err)
                return
            end
            if data and #data > 0 then
                data_consumer(data)
            end
        end)
    end
    if stderr then
        vim.uv.read_start(stderr, function(err, data)
            if closed then
                return
            end
            if err then
                logger:error({ "Failure", err })
                error_handler(err)
                return
            end
            if data then
                data_consumer(data)
            end
        end)
    end
    return function()
        if closed ~= true then
            logger:info("On Close called")
            closed = true
            ack_cb()
            if handle then
                handle:close()
            end
        end
    end
end

return { request_hint = request_hint }
