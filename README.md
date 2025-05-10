# autocomplicate.nvim
Simple plugin aiming to get LLM based short autocompletions, similar to the ones offered by copilot plugin, but using model, which can be self-hosted
# Motivation
After trying out all LLM plugins I could find on GitHub (March 2025), I was disappointed to find out that none of them suit my needs.
The best out of them all was copilot plugin, its main downside being locked to a single model, not being able to run it offline and being tied to solutions with dubious security practices. That is why I have decided to start working on my own plugin
# How to install
You can use lazy or any other plugin manager of choice, here is an example using Lazy:
```
return {
    "Czandal/autocomplicate.nvim",
    name = "autocomplicate",
    config = function()
        require("autocomplicate").setup({
            register_autocmd = true,
            default_keymaps = true,
            model = "qwen2.5-coder:1.5b",
            -- host= "http://localhost:11445",
            context_line_size = 5,
            llm_options = {
                num_predict = 10,
                temperature = 0.7,
                top_k = 30,
                top_p = 0.8,

            },
        })
    end
}
```
# Customization
You can use following parameters, when calling `require("autocomplicate").setup`:
| Param | Description | Default Value |
| register_autocmd | If set to true, registers autocmd launching plugin on InsertEnter and CursorMoved | false |
| host | Full URL to the endpoint for communication with LLM | http://localhost:11434/api/generate |
| context_line_size | How many lines above and under the cursor are sent to LLM as context of the code | 10 |
| allowed_file_types | Array of strings, if empty starts the plugin for all files. Can use patterns, but string.find is used under the hood so one needs to use `.*` | Empty array |
| blacklisted_file_types | Array of string, if emptt defaults to empty list. Can use patterns, but string.find is used under the hood so one needs to use `.*` | Empty array |
| default_keymaps | Should the plugin add default keymaps - `<C-S>` to accept hint, `<C-X>` to reject it and `<C-R>` to refresh it  false |
| model | Model used by the plugin, make sure that name matches one used by the LLM host | deepseek-coder-v2 |
| llm_options | All the options sent to LLM, see https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values | {} |

# Contributions

Any contributions are more then welcome, feel free to open issues and/or pull requests

