local utils = require("autocomplicate.utils")

describe("utils", function()
    it("dump to string converts object to a string", function()
        local out = utils.dump_to_string({ a = 1, b = "foo", c = {} })
        assert(type(out) == "string")
    end)
end)
