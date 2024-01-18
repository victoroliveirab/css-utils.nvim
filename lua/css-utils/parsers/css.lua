local constants = require("css-utils.constants")
local Parser = require("css-utils.parsers")
local logger = require("css-utils.logger")

---@class CssParser : BaseParser
---@field info HtmlParsedLink
local CssParser = {}
setmetatable(CssParser, { __index = Parser })

---@param bufnr integer
---@param info HtmlParsedLink
---@return CssParser
function CssParser:new(bufnr, info)
    logger.trace("CssParser:new()")
    local instance = Parser:new(bufnr)
    setmetatable(instance, { __index = CssParser })
    instance.info = info
    return instance
end

---@return TSNode
function CssParser:_get_inline_root()
    local bufnr = self.bufnr
    ---@type integer[]
    local range = self.info.range
    -- NOTE: table.unpack not working
    local row_start = range[1]
    local col_start = range[2]
    local row_end = range[3]
    local col_end = range[4]
    local lines =
        vim.api.nvim_buf_get_lines(bufnr, row_start, row_end + 1, false)
    lines[1] = string.sub(lines[1], col_start + 1)
    lines[#lines] = string.sub(lines[#lines], 1, col_end)
    local lines_str = vim.fn.join(lines, "\n")
    local treesitter_parser = vim.treesitter.get_string_parser(lines_str, "css")
    local root = treesitter_parser:parse()[1]:root()
    return root
end

---@return TSNode
function CssParser:_get_local_root()
    local bufnr = self.bufnr
    local treesitter_parser = vim.treesitter.get_parser(bufnr, "css")
    local root = treesitter_parser:parse()[1]:root()
    return root
end

---@param cb fun(selectors: table<string, CssSelectorInfo[]>): nil
function CssParser:parse(cb)
    local bufnr = self.bufnr
    logger.trace(string.format("CssParser:parse - bufnr=%d", bufnr))
    local root = self.info.type == "inline" and self:_get_inline_root()
        or self:_get_local_root()
    local query = vim.treesitter.query.parse(
        "css",
        constants.treesitter_query_id_and_classes
    )
    local selectors = {}

    ---@param node TSNode
    local parse_node = function(node)
        local type = node:type()
        local prefix = type == "id_name" and "#" or "."
        local row_start, col_start, row_end, col_end = node:range()
        if self.info.range then
            row_start = row_start + self.info.range[1]
            row_end = row_end + self.info.range[1]
        end
        local node_text = table.concat(
            vim.api.nvim_buf_get_text(
                bufnr,
                row_start,
                col_start,
                row_end,
                col_end,
                {}
            ),
            "\n"
        )
        local name = prefix .. node_text
        if not selectors[name] then
            selectors[name] = {}
        end
        local rule_set = node:parent()
        while rule_set and rule_set:type() ~= "rule_set" do
            rule_set = rule_set:parent()
        end
        if not rule_set then
            logger.debug("no ruleset found for node " .. name)
            logger.debug(node:range())
            return
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

        -- check if the selector_range is already present. If it is, no need to duplicate the selector
        for _, selector in ipairs(selectors[name]) do
            if
                rs_row_start == selector.selector_range[1]
                and rs_col_start == selector.selector_range[2]
            then
                return
            end
        end

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
    for _, match in query:iter_matches(root, bufnr, 0, 0) do
        for _, node in pairs(match) do
            parse_node(node)
        end
    end
    logger.debug(selectors)
    cb(selectors)
end

return CssParser
