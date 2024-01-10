local logger = require("css-utils.logger")

---@param client lsp.Client
---@param handler_name string
---@param custom_handler LspCustomHandler
local attach_custom_handler = function(client, handler_name, custom_handler)
    local client_id = client.id
    logger.trace(
        string.format(
            "attach_custom_handler for client=%d and handler=%s",
            client_id,
            handler_name
        )
    )
    local original_handler = vim.lsp.handlers[handler_name]
    -- Attaching to client.handlers[handler_name] also affects all clients
    vim.lsp.handlers[handler_name] = function(err, result, ctx, cfg)
        if ctx.client_id ~= client_id then
            return original_handler(err, result, ctx, cfg)
        end
        return custom_handler(original_handler, err, result, ctx, cfg)
    end
end

return {
    attach_custom_handler = attach_custom_handler,
}
