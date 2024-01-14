local logger = require("css-utils.logger")
local state = require("css-utils.state")
local utils = require("css-utils.utils")

local ok, cmp = pcall(require, "cmp")
if not ok then
    logger.warn("cmp not found. skipping completion configuration.")
    return
end

local class_regex = "class=[\"'].*"
local id_regex = "id=[\"'].*"

---@type CmpSourceInstance
local M = {
    name = "css-utils",
}

---The method cmp calls when css-utils is registered to ask for suggestions
---@param cmp_content CmpContent
---@param cb CmpCallback
function M:complete(cmp_content, cb)
    local ctx = cmp_content.context
    if ctx.filetype ~= "html" then
        return cb()
    end

    local html_file = vim.api.nvim_buf_get_name(ctx.bufnr)
    local stylesheets = state.html.stylesheets_by_file[html_file]
    if not stylesheets or #stylesheets == 0 then
        return cb()
    end

    logger.trace(cmp_content)

    local before_cursor_content = cmp_content.context.cursor_before_line
    local is_class_cmp =
        utils.ends_with_pattern(before_cursor_content, class_regex)
    local is_id_cmp = utils.ends_with_pattern(before_cursor_content, id_regex)

    if is_class_cmp and is_id_cmp then
        local line = cmp_content.context.cursor_line
        local col = cmp_content.context.cursor.col
        -- NOTE: is there a better way to decide the selector?
        while
            string.sub(line, col, col) ~= "="
            and string.sub(line, col, col) ~= " "
        do
            col = col - 1
        end
        col = col - 1
        -- if "d" is found, it means the selector is "id"
        if string.sub(line, col, col) == "d" then
            is_class_cmp = false
        else
            is_id_cmp = false
        end
    end

    if is_class_cmp or is_id_cmp then
        local suggestions = {}
        local labels_indexes = {}
        for _, stylesheet in ipairs(stylesheets) do
            local selectors = state.css.selectors_by_file[stylesheet.path]
            local stylesheet_href = stylesheet.href
            for selector in pairs(selectors) do
                local type = string.sub(selector, 1, 1)
                local should_add_suggestion = (type == "." and is_class_cmp)
                    or (type == "#" and is_id_cmp)
                -- TODO: do not suggest repeated classes (e.g. <div class="foo f|">) should not suggest "foo" again
                -- TODO: do not suggest a new id with one is already set (e.g. <div id="foo |"> should not trigger any suggestion)
                if should_add_suggestion then
                    local label = string.sub(selector, 2)
                    logger.debug("Adding suggestion")
                    logger.debug(label)
                    logger.debug(selector)
                    local filename = stylesheet_href
                    if vim.startswith(filename, "./") then
                        filename = string.sub(filename, 3)
                    end
                    if labels_indexes[label] then
                        local index = labels_indexes[label]
                        logger.debug(
                            string.format(
                                "%s is repeated, so record is being added at index %d",
                                label,
                                index
                            )
                        )
                        suggestions[labels_indexes[label]].detail = suggestions[labels_indexes[label]].detail
                            .. ",\n"
                            .. filename
                    else
                        logger.debug(
                            string.format(
                                "adding new record labelled %s",
                                label
                            )
                        )
                        table.insert(suggestions, {
                            kind = cmp.lsp.CompletionItemKind.Constant,
                            label = label,
                            detail = string.format("Found at %s", filename),
                        })
                        labels_indexes[label] = #suggestions
                    end
                end
            end
        end
        return cb(suggestions)
    end

    logger.info("nothing to suggest")
    cb()
end

M.register = function()
    cmp.register_source("css-utils", M)
    print("registered source")
end

return M
