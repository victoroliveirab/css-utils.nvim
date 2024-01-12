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
    local is_id_selector = node_type == "id_selector"
    if is_class_selector or is_id_selector then
        for child in node:iter_children() do
            local child_type = child:type()
            if child_type == "class_name" or child_type == "id_name" then
                local prefix = is_class_selector and "." or "#"
                local name = prefix .. utils.get_ts_node_text(bufnr, child)
                if not selectors[name] then
                    selectors[name] = {}
                end
                local row_start, col_start, row_end, col_end = child:range()
                -- Rollback on the tree to get the whole range of the selector
                local rule_set = child:parent()
                while rule_set:type() ~= "rule_set" do
                    rule_set = rule_set:parent()
                end
                logger.debug(
                    string.format(
                        "%s=%s found at range %d,%d,%d,%d",
                        child_type,
                        name,
                        row_start,
                        col_start,
                        row_end,
                        col_end
                    )
                )
                local rs_row_start, rs_col_start, rs_row_end, rs_col_end =
                    rule_set:range()
                logger.debug(
                    string.format(
                        "rule_set of %s=%s at range %d,%d,%d,%d",
                        child_type,
                        name,
                        rs_row_start,
                        rs_col_start,
                        rs_row_end,
                        rs_col_end
                    )
                )
                -- check if the selector_range is already present. If it is, no need to duplicate the selector
                local is_range_present = false
                for _, selector in ipairs(selectors[name]) do
                    if
                        rs_row_start == selector.selector_range[1]
                        and rs_col_start == selector.selector_range[2]
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
                        rs_row_start,
                        rs_row_start + 1,
                        false
                    )[1],
                    range = { row_start, col_start, row_end, col_end },
                    selector_range = {
                        rs_row_start,
                        rs_col_start,
                        rs_row_end,
                        rs_col_end,
                    },
                }
                table.insert(selectors[name], css_selector_info)
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

---@param bufnr integer
---@return CssParser
function CssParser:new(bufnr)
    logger.trace("CssParser:new()")
    local instance = Parser:new(bufnr)
    setmetatable(instance, { __index = CssParser })
    return instance
end

---@param cb fun(selectors: table<string, CssSelectorInfo[]>): nil
function CssParser:parse(cb)
    logger.trace("CssParser:parse")
    local bufnr = self.bufnr
    local selectors = {}
    local treesitter_parser = vim.treesitter.get_parser(bufnr, "css")
    local root = treesitter_parser:trees()[1]:root()
    traverse_css(bufnr, root, selectors, 1)
    logger.debug("Final selectors")
    logger.debug(selectors)
    cb(selectors)
end

return CssParser
