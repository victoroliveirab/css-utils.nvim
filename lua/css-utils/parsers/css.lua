local Parser = require("css-utils.parsers")
local logger = require("css-utils.logger")
local utils = require("css-utils.utils")

local traverse_css
---Traverse the AST of a CSS file
---@param bufnr integer
---@param node TSNode
---@param selectors table<string, CssSelectorInfo[]>
---@param depth integer
traverse_css = function(bufnr, node, selectors, depth)
    logger.trace(
        string.format("traverse_css() - buf=%d, depth=%d", bufnr, depth)
    )
    local node_type = node:type()
    local is_class_selector = node_type == "class_selector"
    if is_class_selector then
        for child in node:iter_children() do
            if child:type() == "class_name" then
                local class = "." .. utils.get_ts_node_text(bufnr, child)
                if not selectors[class] then
                    selectors[class] = {}
                end
                local row_start, col_start, row_end, col_end = child:range()
                -- Rollback on the tree to get the whole range of the selector
                local rule_set = child:parent()
                while rule_set:type() ~= "rule_set" do
                    rule_set = rule_set:parent()
                end
                logger.debug(
                    string.format(
                        "class_name=%s found at range %d,%d,%d,%d",
                        class,
                        row_start,
                        col_start,
                        row_end,
                        col_end
                    )
                )
                local class_row_start, class_col_start, class_row_end, class_col_end =
                    rule_set:range()
                logger.debug(
                    string.format(
                        "rule_set of class_name=%s at range %d,%d,%d,%d",
                        class,
                        class_row_start,
                        class_col_start,
                        class_row_end,
                        class_col_end
                    )
                )
                -- check if the selector_range is already present. If it is, no need to duplicate the selector
                local is_range_present = false
                for _, selector in ipairs(selectors[class]) do
                    if
                        class_row_start == selector.selector_range[1]
                        and class_col_start == selector.selector_range[2]
                    then
                        is_range_present = true
                        break
                    end
                end
                if is_range_present then
                    return
                end

                local css_selector_info = {
                    preview_text = vim.api.nvim_buf_get_lines(
                        bufnr,
                        class_row_start,
                        class_row_start + 1,
                        false
                    )[1],
                    range = { row_start, col_start, row_end, col_end },
                    selector_range = {
                        class_row_start,
                        class_col_start,
                        class_row_end,
                        class_col_end,
                    },
                }
                table.insert(selectors[class], css_selector_info)
            end
        end
        return
    end
    for child in node:iter_children() do
        traverse_css(bufnr, child, selectors, depth + 1)
    end
end

---@class CssParser : BaseParser
local CssParser = {}
setmetatable(CssParser, { __index = Parser })

---@return CssParser
function CssParser:new()
    logger.trace("CssParser:new()")
    local instance = Parser:new()
    setmetatable(instance, { __index = CssParser })
    return instance
end

---@param cb fun(selectors: table<string, CssSelectorInfo[]>): nil
function CssParser:parse(cb)
    logger.trace("CssParser:parse")
    local bufnr = self.buf
    local selectors = {}
    local treesitter_parser = vim.treesitter.get_parser(bufnr, "css")
    local root = treesitter_parser:trees()[1]:root()
    traverse_css(bufnr, root, selectors, 1)
    logger.debug("Final selectors")
    logger.debug(selectors)
    cb(selectors)
end

return CssParser
