local logger = require("css-utils.logger")
local Parser = require("css-utils.parsers")
local parse_nodes = require("css-utils.parsers.css.common").parse_nodes

---@class InlineCssParser : BaseParser
---@field range integer[]
local InlineCssParser = {}
setmetatable(InlineCssParser, { __index = Parser })

---@param filename string
---@return InlineCssParser
function InlineCssParser:new(filename, range)
    logger.trace("CssParser:new()")
    local instance = Parser:new(filename)
    setmetatable(instance, { __index = InlineCssParser })
    instance.range = range
    return instance
end

function InlineCssParser:_get_root(bufnr)
    local range = self.range
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

---@param cb fun(selectors: table<string, CssSelectorInfo[]>): nil
function InlineCssParser:parse(cb)
    local filename = self.filename
    local bufnr = vim.fn.bufadd(filename)
    logger.trace(string.format("InlineCssParser:parse() of %s", filename))
    local root = self:_get_root(bufnr)
    local range_getter = function(node)
        local row_start, col_start, row_end, col_end = node:range()
        row_start = row_start + self.range[1]
        row_end = row_end + self.range[1]
        return row_start, col_start, row_end, col_end
    end
    local selectors = parse_nodes(root, bufnr, range_getter)
    logger.debug(
        string.format("done parsing nodes of inline css at %s", filename)
    )
    logger.debug(selectors)
    for _, entries in pairs(selectors) do
        for _, selector in ipairs(entries) do
            selector.selector_range[1] = selector.selector_range[1]
                + self.range[1]
            selector.selector_range[3] = selector.selector_range[3]
                + self.range[1]
        end
    end
    logger.debug(string.format("shifted selectors to match actual file lines"))
    logger.debug(selectors)
    cb(selectors)
end

return InlineCssParser
