local logger = require("css-utils.logger")
local state = require("css-utils.state")
local utils = require("css-utils.utils")

---@param original_handler lsp-handler
---@param err lsp.ResponseError?
---@param result LspResult
---@param ctx LspContext
---@param cfg table?
local go_to_definition = function(original_handler, err, result, ctx, cfg)
    local trigger_original_handler = function()
        return original_handler(err, result, ctx, cfg)
    end

    if err then
        logger.error(
            "go_to_definition received an error. letting original handler handle"
        )
        logger.trace({ err = err, result = result, ctx = ctx, cfg = cfg })
        return trigger_original_handler()
    end

    local bufnr = ctx.bufnr
    local pos = ctx.params.position.start

    local node = vim.treesitter.get_node({
        bufnr = bufnr,
        pos = pos,
    })

    if not node or node:type() ~= "attribute_value" then
        logger.debug(
            string.format(
                "node_type=%s is not of type attribute_value. let original_handler handle",
                node and node:type() or "null"
            )
        )
        return trigger_original_handler()
    end

    local ok, attr_name = pcall(function()
        local parent = node:parent()
        local grandfather = parent:parent()
        local attribute = grandfather:child()
        if attribute:type() ~= "attribute_name" then
            return ""
        end
        return utils.get_ts_node_text(bufnr, attribute)
    end)

    local is_class_or_id_attr = ok
        and (attr_name == "class" or attr_name == "id")

    if not is_class_or_id_attr then
        logger.debug(
            string.format(
                "attr_name=%s is not class nor id. let original_handler handle",
                attr_name
            )
        )
        return trigger_original_handler()
    end

    local node_text = utils.get_ts_node_text(bufnr, node)

    if utils.has_whitespace(node_text) then
        -- TODO: test if this works under multiple windows/tabs setup
        node_text = vim.fn.expand("<cword>")
    end

    local selector = attr_name == "class" and "." .. node_text
        or "#" .. node_text
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local stylesheets = state.stylesheets_by_html_file[filepath]

    if not stylesheets then
        logger.debug(
            string.format(
                "filepath=%s does not contain stylesheets. let original_handler handle",
                filepath
            )
        )
        return trigger_original_handler()
    end

    -- Traverse the stylesheets, giving priority to the imported later
    local index = #stylesheets
    local qf_entries = {}
    while index > 0 do
        local stylesheet_name = stylesheets[index]
        local available_selectors = state.selectors_by_css_file[stylesheet_name]
        if available_selectors then
            local entries = available_selectors[selector]
            if entries then
                for _, entry in ipairs(entries) do
                    table.insert(qf_entries, {
                        filename = stylesheet_name,
                        lnum = entry.selector_range[1] + 1,
                        col = entry.selector_range[2] + 1,
                        text = entry.preview_text,
                    })
                end
            end
        end
        index = index - 1
    end

    if #qf_entries == 0 then
        logger.debug(
            string.format(
                "selector=%s was not found in any imported stylesheet. let original_handler handle",
                selector
            )
        )
        return trigger_original_handler()
    end

    logger.debug(
        string.format(
            "showing the qf list for selector=%s with the following entries:",
            selector
        )
    )
    logger.debug(qf_entries)

    vim.fn.setqflist({}, " ", {
        title = "Occurances of " .. selector,
        items = qf_entries,
    })
    vim.cmd("copen")
end

return {
    go_to_definition = go_to_definition,
}
