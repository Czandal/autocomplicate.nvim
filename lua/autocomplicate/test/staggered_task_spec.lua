local StaggeredTask = require("autocomplicate.staggered_task")

describe("staggered_task", function()
    it("run_with_stagger can be canceled", function()
        local called_time = nil
        local task = function()
            called_time = vim.uv.hrtime()
        end
        local test_entity = StaggeredTask:new(task)
        test_entity:run_with_stagger(1)
        test_entity:stop()
        vim.wait(2)
        assert(test_entity.ran == false)
        assert(called_time == nil)
    end)
    it("run_with_stagger runs task in at least N ms", function()
        local called_time = nil
        local task = function()
            called_time = vim.uv.hrtime()
        end
        local test_entity = StaggeredTask:new(task)
        local start_time = vim.uv.hrtime()
        test_entity:run_with_stagger(4)
        vim.wait(5)
        assert(called_time ~= nil)
        assert(test_entity.ran == true)
        assert(called_time - start_time >= 4 * 1000 * 1000)
    end)
    it(
        "run_with_stagger can be called_multiple times to stagger the task further",
        function()
            local called_time = nil
            local num_of_calls = 0
            local task = function()
                called_time = vim.uv.hrtime()
                num_of_calls = num_of_calls + 1
            end
            local test_entity = StaggeredTask:new(task)
            local start_time = vim.uv.hrtime()
            test_entity:run_with_stagger(5)
            vim.wait(2)
            test_entity:run_with_stagger(5)
            vim.wait(10)
            assert(num_of_calls, 1)
            assert(called_time ~= nil)
            assert(test_entity.ran == true)
            assert(
                called_time - start_time >= 7 * 1000 * 1000,
                "Stagger is shorter than it should be: "
                    .. (called_time - start_time) / 1000000.0
            )
            assert(called_time - start_time <= 10 * 1000 * 1000)
        end
    )
end)
