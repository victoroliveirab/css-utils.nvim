local logger = require("css-utils.logger")
local on_attach = require("css-utils.lsp.on_attach")

local M = {}

M.setup = function(config)
    config = config or {}
    vim.g.css_utils_dev = config.dev or false
    logger.trace("setup()")
    if config.dev then
        vim.lsp.set_log_level("TRACE")
    end
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = on_attach,
    })
end

return M
