local logger = require("css-utils.logger")
local state = require("css-utils.state")
local utils = require("css-utils.utils")

local hover_state = {
    hover_index = 1,
    selector = "",
}

---Performs various checks and returns, if node is valid, the attribute name and the selectior name
---@param ctx LspContext
---@return string?, string?
local get_node_text_by_ctx = function(ctx)
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
        return
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
        return
    end

    local node_text = utils.get_ts_node_text(bufnr, node)

    if utils.has_whitespace(node_text) then
        -- TODO: test if this works under multiple windows/tabs setup
        node_text = vim.fn.expand("<cword>")
    end

    return attr_name, node_text
end

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

    local attr_name, node_text = get_node_text_by_ctx(ctx)

    if not attr_name or not node_text then
        -- Logging already done at `get_node_text_by_ctx`
        return trigger_original_handler()
    end

    local selector = attr_name == "class" and "." .. node_text
        or "#" .. node_text
    local filepath = vim.api.nvim_buf_get_name(ctx.bufnr)
    local stylesheets = state.html.stylesheets_by_file[filepath]

    if not stylesheets then
        logger.debug(
            string.format(
                "definition: filepath=%s does not contain stylesheets. let original_handler handle",
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
        local available_selectors = state.css.selectors_by_file[stylesheet_name]
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

---@param original_handler lsp-handler
---@param err lsp.ResponseError?
---@param result LspResult
---@param ctx LspContext
---@param cfg table?
local hover = function(original_handler, err, result, ctx, cfg)
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

    local attr_name, node_text = get_node_text_by_ctx(ctx)

    if not attr_name or not node_text then
        -- Logging already done at `get_node_text_by_ctx`
        return trigger_original_handler()
    end

    local selector = (attr_name == "id" and "#" or ".") .. node_text
    local filepath = vim.api.nvim_buf_get_name(ctx.bufnr)

    -- Reset state to new selector
    if
        hover_state.selector ~= selector or not state.lsp.hover_cache[filepath]
    then
        logger.debug({
            old_selector = hover_state.selector,
            new_selector = selector,
        })
        hover_state.selector = selector
        hover_state.hover_index = 1

        local stylesheets = state.html.stylesheets_by_file[filepath]
        if not stylesheets then
            logger.debug(
                string.format(
                    "hover: filepath=%s does not contain stylesheets. let original_handler handle",
                    filepath
                )
            )
            return trigger_original_handler()
        end

        -- OPTIMIZE: if peek_prev and peek_next are disabled, no need to check all buffers, just the first

        if not state.lsp.hover_cache[filepath] then
            state.lsp.hover_cache[filepath] = {}
        end

        if not state.lsp.hover_cache[filepath][selector] then
            local entries = {}
            for _, stylesheet in ipairs(stylesheets) do
                local stylesheet_name = stylesheet.path
                local definitions =
                    state.css.selectors_by_file[stylesheet_name][selector]
                if state.css.selectors_by_file[stylesheet_name][selector] then
                    local css_bufnr = vim.fn.bufadd(stylesheet_name)
                    for _, entry in ipairs(definitions) do
                        local row_start = entry.selector_range[1]
                        local row_end = entry.selector_range[3] + 1
                        table.insert(
                            entries,
                            vim.api.nvim_buf_get_lines(
                                css_bufnr,
                                row_start,
                                row_end,
                                false
                            )
                        )
                    end
                end
            end
            state.lsp.hover_cache[filepath][selector] = entries
        end
    end
    local all_entries = state.lsp.hover_cache[filepath][selector]
    local entry = all_entries[hover_state.hover_index]

    local float_bufnr, float_winnr =
        vim.lsp.util.open_floating_preview(entry, "css", {
            border = "solid",
            focusable = true,
            focus_id = ctx.method,
            title = string.format(
                "%d/%d",
                hover_state.hover_index,
                #all_entries
            ),
            title_pos = "right",
            wrap = false,
        })

    local peek_prev_keymap = state.config.keymaps.peek_previous
    local peek_next_keymap = state.config.keymaps.peek_next

    if peek_next_keymap then
        vim.keymap.set("n", peek_next_keymap, function()
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", true)
            local new_index = hover_state.hover_index + 1
            if new_index > #all_entries then
                new_index = 1
            end
            hover_state.hover_index = new_index
            vim.api.nvim_buf_set_lines(
                float_bufnr,
                0,
                -1,
                false,
                state.lsp.hover_cache[filepath][selector][new_index]
            )
            vim.api.nvim_win_set_config(float_winnr, {
                title = string.format("%d/%d", new_index, #all_entries),
                title_pos = "right",
            })
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", false)
        end, { buffer = float_bufnr, remap = true })
    end

    if peek_prev_keymap then
        vim.keymap.set("n", peek_prev_keymap, function()
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", true)
            local new_index = hover_state.hover_index - 1
            if new_index < 1 then
                new_index = #all_entries
            end
            hover_state.hover_index = new_index
            vim.api.nvim_buf_set_lines(
                float_bufnr,
                0,
                -1,
                false,
                state.lsp.hover_cache[filepath][selector][new_index]
            )
            vim.api.nvim_win_set_config(float_winnr, {
                title = string.format("%d/%d", new_index, #all_entries),
                title_pos = "right",
            })
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", false)
        end, { buffer = float_bufnr, remap = true })
    end

    -- TODO: add <CR> keymap to open file in current window in the correct cursor position
    -- vim.keymap.set(
    --     "n",
    --     "<CR>",
    --     function() end,
    --     { buffer = float_bufnr, remap = true }
    -- )

    logger.debug(state.lsp.hover_cache)
end

return {
    go_to_definition = go_to_definition,
    hover = hover,
}
