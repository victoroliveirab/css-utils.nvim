local constants = require("css-utils.constants")
local Parser = require("css-utils.parsers")
local logger = require("css-utils.logger")
local utils = require("css-utils.utils")

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
    local bufnr = self.bufnr
    logger.trace(string.format("CssParser:parse - bufnr=%d", bufnr))
    local selectors = {}
    local treesitter_parser = vim.treesitter.get_parser(bufnr, "css")
    local root = treesitter_parser:trees()[1]:root()
    local query = vim.treesitter.query.parse(
        "css",
        constants.treesitter_query_id_and_classes
    )
    for _, match in query:iter_matches(root, bufnr, 0, 0) do
        for _, node in pairs(match) do
            local type = node:type()
            local prefix = type == "id_name" and "#" or "."
            local name = prefix .. vim.treesitter.get_node_text(node, bufnr)
            if not selectors[name] then
                selectors[name] = {}
            end
            local row_start, col_start, row_end, col_end = node:range()
            local rule_set = node:parent()
            while rule_set:type() ~= "rule_set" do
                rule_set = rule_set:parent()
            end
            logger.debug(
                string.format(
                    "%s=%s found at range %d,%d,%d,%d",
                    type,
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
                    type,
                    name,
                    rs_row_start,
                    rs_col_start,
                    rs_row_end,
                    rs_col_end
                )
            )
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
            if not is_range_present then
                local css_selector_info = {
                    -- FIXME: using vim.api.nvim_buf_get_lines won't work for unformatted files. use vim.api.nvim_buf_get_text instead
                    preview_text = "A",
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
    end
    logger.debug("Final selectors")
    logger.debug(selectors)
    cb(selectors)
end

return CssParser
