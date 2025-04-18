---All the options sent to LLM
---See https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values
---@class AutocomplicateLlmOptions
---@field mirostat? integer defaults to 0
---@field mirostat_eta? number defaults to 0.1
---@field mirostat_tau? number default to 5.0
---@field num_ctx integer? defaults to 1024
---@field repeat_last_n? integer defaults to 64
---@field repeat_penalty? number defaults to 1.1
---@field temperature? number defaults to 0.8
---@field seed integer?
---@field stop string?
---@field num_predict? integer defaults to 32
---@field top_k? integer defaults to 40
---@field top_p? number defaults to 0.9
---@field min_p? number defaults to 0.0

---@param input AutocomplicateLlmOptions
---@return AutocomplicateLlmOptions
local function parse_llm_options(input)
    input.mirostat = input.mirostat or 0
    input.mirostat_eta = input.mirostat_eta or 0.1
    input.mirostat_tau = input.mirostat_tau or 5.0
    input.num_ctx = input.num_ctx or 1024
    input.repeat_last_n = input.repeat_last_n or 64
    input.repeat_penalty = input.repeat_penalty or 1.1
    input.temperature = input.temperature or 0.8
    input.num_predict = input.num_predict or 32
    input.top_k = input.top_k or 40
    input.top_p = input.top_p or 0.9
    input.min_p = input.min_p or 0.0
    return input
end

return { parse_llm_options = parse_llm_options }
