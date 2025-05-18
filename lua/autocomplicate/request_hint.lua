local logger = require("autocomplicate.logger")

local curl_error_messages = {
    [0] = "Success (operation completed as planned)",
    [1] = "Unsupported protocol (curl lacks support for the protocol used in the URL)",
    [2] = "Failed to initialize (internal error or libcurl/system issue)",
    [3] = "URL malformed (syntax error in URL)",
    [5] = "Couldn't resolve proxy (failed to resolve the proxy hostname)",
    [6] = "Couldn't resolve host (failed to resolve the remote host)",
    [7] = "Failed to connect to host",
    [8] = "Weird server reply (unexpected response from server)",
    [9] = "Access denied (resource denied by server)",
    [10] = "FTP accept failed",
    [11] = "FTP weird PASS reply",
    [12] = "Error in user (FTP)",
    [13] = "FTP weird PASV reply",
    [14] = "FTP weird 227 format",
    [15] = "FTP can't get host",
    [16] = "FTP couldn't set binary",
    [17] = "Partial file (incomplete file transfer)",
    [18] = "FTP couldn't download/access the given file",
    [19] = "FTP couldn't retrieve (RETR command failed)",
    [20] = "FTP write error",
    [21] = "FTP quote error",
    [22] = "HTTP page not retrieved or other HTTP error",
    [23] = "Write error (could not write data to local filesystem or stdout)",
    [24] = "Malformed user (FTP)",
    [25] = "FTP couldn't STOR file",
    [26] = "Read error (could not read from local file or stdin)",
    [27] = "Out of memory",
    [28] = "Operation timeout",
    [29] = "FTP couldn't set ASCII",
    [30] = "FTP PORT failed",
    [31] = "FTP couldn't use REST",
    [32] = "FTP couldn't use SIZE",
    [33] = "HTTP range error",
    [34] = "HTTP post error",
    [35] = "SSL connect error",
    [36] = "FTP bad download resume",
    [37] = "File couldn't read file",
    [38] = "LDAP cannot bind",
    [39] = "LDAP search failed",
    [42] = "Aborted by callback (not usually visible to curl users)",
    [43] = "Bad function argument (should not be returned by curl tool)",
    [45] = "Interface error (specified network interface could not be used)",
    [47] = "Too many redirects",
    [48] = "Unknown option specified",
    [49] = "Setopt option syntax error",
    [51] = "SSL: certificate or fingerprint mismatch",
    [52] = "SSL crypto engine not found",
    [53] = "Cannot set SSL crypto engine as default",
    [55] = "Failed sending network data",
    [56] = "Failure in receiving network data",
    [58] = "Problem with the local certificate",
}

---@param code number
---@return string
local function get_curl_error_message(code)
    return curl_error_messages[code] or "Unknown"
end

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
                msg = "Hint retrieving closed with an error",
                code = code,
                signal = signal,
                common_cause = get_curl_error_message(code),
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
