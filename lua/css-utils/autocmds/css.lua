local LocalCssParser = require("css-utils.parsers.css.local")
local state = require("css-utils.state")

local register = function()
    -- TODO: add parse file to opened CSS file if not cached
    -- On save, reparse css file
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function(params)
            local bufnr = params.buf
            local filename = vim.api.nvim_buf_get_name(bufnr)
            state.css.selectors_by_file[filename] = nil
            local parser = LocalCssParser:new(filename)
            parser:parse(function(selectors)
                state.css.selectors_by_file[filename] = {
                    list = selectors,
                    timestamp = os.time(),
                }
            end)
        end,
        pattern = { "*.css" },
    })
end

return register
