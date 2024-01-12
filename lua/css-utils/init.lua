local cmp = require("css-utils.cmp")
local logger = require("css-utils.logger")
local on_attach = require("css-utils.lsp.on_attach")

local M = {}

---@class CssUtilsConfig
---@field dev boolean?
---@field disabled boolean?

---@param config CssUtilsConfig
M.setup = function(config)
    config = config or {}
    local disabled = config.disabled or false
    if disabled then
        return
    end
    local dev_mode = config.dev or false
    if dev_mode then
        logger.level = "trace"
        logger.use_console = "async"
        vim.lsp.set_log_level("TRACE")
        vim.api.nvim_create_user_command("CssUtilsDebug", function()
            print(vim.inspect(require("css-utils.state")))
        end, {})
    end
    logger.trace("setup()")
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = on_attach,
    })
    cmp.register()
end

return M
