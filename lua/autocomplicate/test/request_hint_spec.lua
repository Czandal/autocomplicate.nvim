local request_hint = require("autocomplicate.request_hint").request_hint
local utils = require("autocomplicate.utils")

local expected_full_response = {
    "You know ",
    "the day destroys",
    " the night\n",
    "Night",
    " divides t",
    "he day\n",
    "Tried",
    " to run\n",
    "Tried",
    " t",
    "o",
    " ",
    "h",
    "i",
    "de\n",
    "Break on through to",
    " the other side\n",
}

describe("request_hint function", function()
    it("retrieves the data from LLM server", function()
        local err_detected = false
        local data = ""
        local ack_called = false
        request_hint(
            "http://localhost:11445/api/generate",
            "Foo",
            "Bar",
            "model",
            {},
            function(err)
                err_detected = true
                error(utils.dump_to_string({ "Error received!!!", data, err }))
            end,
            function(chunk)
                data = data .. chunk
            end,
            function()
                ack_called = true
            end
        )
        vim.wait(1230)
        assert(err_detected == false)
        assert(ack_called == true)
        local parsed_data = {}
        for line in data:gmatch("([^\n]*)\n?") do
            if #line > 0 then
                local msg = vim.fn.json_decode(line).response
                table.insert(parsed_data, msg)
            end
        end
        assert(#parsed_data == #expected_full_response)
        for i = 1, #parsed_data do
            assert(expected_full_response[i] == parsed_data[i])
        end
    end)
    it(
        "if canceled at some point only partial of data will be downloaded",
        function()
            local err_detected = false
            local data = ""
            local ack_called = false
            local num_of_calls = 0
            local close = request_hint(
                "http://localhost:11445/api/generate",
                "Foo",
                "Bar",
                "model",
                {},
                function()
                    err_detected = true
                end,
                function(chunk)
                    data = data .. chunk
                    num_of_calls = num_of_calls + 1
                end,
                function()
                    ack_called = true
                end
            )
            vim.wait(810)
            close()
            assert(ack_called == true)
            vim.wait(420)
            assert(err_detected == false)
            local parsed_data = {}
            for line in data:gmatch("([^\n]*)\n?") do
                if #line > 0 and string.sub(line, -1) == "}" then
                    local msg = vim.fn.json_decode(line).response
                    table.insert(parsed_data, msg)
                end
            end
            assert(
                num_of_calls > 0,
                utils.dump_to_string({ "got", num_of_calls })
            )
            assert(
                #parsed_data < #expected_full_response,
                utils.dump_to_string({ "got", num_of_calls })
            )
            assert(#parsed_data > 0, utils.dump_to_string({ "received", data }))
            for i = 1, #parsed_data do
                assert(
                    expected_full_response[i] == parsed_data[i],
                    utils.dump_to_string({
                        received = parsed_data[i],
                        expected = expected_full_response[i],
                    })
                )
            end
        end
    )
end)
