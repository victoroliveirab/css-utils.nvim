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
    local stylesheets_dict = state.html.stylesheets_by_file[filepath]

    if not stylesheets_dict then
        logger.debug(
            string.format(
                "definition: filepath=%s does not contain stylesheets. let original_handler handle",
                filepath
            )
        )
        return trigger_original_handler()
    end

    -- Traverse the stylesheets, giving priority to the imported later
    local stylesheets = stylesheets_dict.list
    local index = #stylesheets
    local qf_entries = {}
    while index > 0 do
        local stylesheet_info = stylesheets[index]
        local stylesheet_name = stylesheet_info.path
        local available_selectors =
            state.css.selectors_by_file[stylesheet_name].list
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

        local stylesheets_dict = state.html.stylesheets_by_file[filepath]
        if not stylesheets_dict then
            logger.debug(
                string.format(
                    "hover: filepath=%s does not contain stylesheets. let original_handler handle",
                    filepath
                )
            )
            return trigger_original_handler()
        end

        -- OPTIMIZE: if peek_prev and peek_next are disabled, no need to check all buffers, just the first

        logger.trace("html lsp hover")

        if not state.lsp.hover_cache[filepath] then
            state.lsp.hover_cache[filepath] = {}
        end

        local max_height = state.config.ui.hover.max_height
        local max_width = state.config.ui.hover.max_width
        local stylesheets = stylesheets_dict.list

        if not state.lsp.hover_cache[filepath][selector] then
            logger.debug(
                string.format(
                    "creating new hover cache entry for filepath=%s selector=%s",
                    filepath,
                    selector
                )
            )
            ---@type LspHoverCacheTableEntry[]
            local entries = {}
            local max_width_needed = 0
            local max_height_needed = 0

            local get_local_max_width = function(lines)
                local local_max_width = 0
                for _, line in ipairs(lines) do
                    local length = #line
                    if length > max_width then
                        return max_width
                    end
                    if length > local_max_width then
                        local_max_width = length
                    end
                end
                return local_max_width
            end

            for _, stylesheet in ipairs(stylesheets) do
                local stylesheet_name = stylesheet.path
                local definitions =
                    state.css.selectors_by_file[stylesheet_name].list[selector]
                logger.debug(
                    string.format(
                        "definitions for stylesheet=%s and selector=%s",
                        stylesheet_name,
                        selector
                    )
                )
                logger.debug(definitions or "nil")
                if definitions then
                    local css_bufnr = vim.fn.bufadd(stylesheet_name)
                    for _, entry in ipairs(definitions) do
                        local row_start = entry.selector_range[1]
                        local row_end = entry.selector_range[3] + 1
                        local lines = vim.api.nvim_buf_get_lines(
                            css_bufnr,
                            row_start,
                            row_end,
                            false
                        )
                        local width = get_local_max_width(lines)
                        local height = #lines
                        table.insert(entries, {
                            height = height,
                            lines = lines,
                            width = width,
                        })

                        if height > max_height_needed then
                            max_height_needed = height
                        end
                        if width > max_width_needed then
                            max_width_needed = width
                        end
                    end
                end
            end
            state.lsp.hover_cache[filepath][selector] = {
                entries = entries,
                max_height = max_height_needed > max_height and max_height
                    or max_height_needed,
                max_width = max_width_needed > max_width and max_width
                    or max_width_needed,
            }
        end
    end

    local is_fixed_height = state.config.ui.hover.fixed_height
    local is_fixed_width = state.config.ui.hover.fixed_width
    local options = state.lsp.hover_cache[filepath][selector]
    local number_of_options = #options.entries
    local current_option = options.entries[hover_state.hover_index]

    if number_of_options == 0 then
        logger.debug(
            string.format(
                "filepath=%s selector=%s currently has no option to show",
                filepath,
                selector
            )
        )
        return trigger_original_handler()
    end

    local float_bufnr, float_winnr =
        vim.lsp.util.open_floating_preview(current_option.lines, "css", {
            border = "solid",
            focusable = true,
            focus_id = ctx.method,
            height = is_fixed_height and options.max_height
                or current_option.height,
            title = string.format(
                "%d/%d",
                hover_state.hover_index,
                number_of_options
            ),
            title_pos = "right",
            width = is_fixed_width and options.max_width
                or current_option.width,
            wrap = false,
        })

    local peek_prev_keymap = state.config.keymaps.peek_previous
    local peek_next_keymap = state.config.keymaps.peek_next

    if peek_next_keymap then
        vim.keymap.set("n", peek_next_keymap, function()
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", true)
            local new_index = hover_state.hover_index + 1
            if new_index > number_of_options then
                new_index = 1
            end
            local new_option = options.entries[new_index]
            hover_state.hover_index = new_index
            vim.api.nvim_buf_set_lines(
                float_bufnr,
                0,
                -1,
                false,
                new_option.lines
            )
            vim.api.nvim_win_set_config(float_winnr, {
                height = is_fixed_height and options.max_height
                    or new_option.height,
                title = string.format("%d/%d", new_index, number_of_options),
                title_pos = "right",
                width = is_fixed_width and options.max_width
                    or new_option.width,
            })
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", false)
        end, { buffer = float_bufnr, remap = true })
    end

    if peek_prev_keymap then
        vim.keymap.set("n", peek_prev_keymap, function()
            vim.api.nvim_buf_set_option(float_bufnr, "modifiable", true)
            local new_index = hover_state.hover_index - 1
            if new_index < 1 then
                new_index = number_of_options
            end
            local new_option = options.entries[new_index]
            hover_state.hover_index = new_index
            vim.api.nvim_buf_set_lines(
                float_bufnr,
                0,
                -1,
                false,
                new_option.lines
            )
            vim.api.nvim_win_set_config(float_winnr, {
                height = is_fixed_height and options.max_height
                    or new_option.height,
                title = string.format("%d/%d", new_index, number_of_options),
                title_pos = "right",
                width = is_fixed_width and options.max_width
                    or new_option.width,
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
