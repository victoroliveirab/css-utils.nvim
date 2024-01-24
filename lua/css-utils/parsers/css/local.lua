local logger = require("css-utils.logger")
local Parser = require("css-utils.parsers")
local parse_nodes = require("css-utils.parsers.css.common").parse_nodes

---@class LocalCssParser : BaseParser
local LocalCssParser = {}
setmetatable(LocalCssParser, { __index = Parser })

---@param filename string
---@return LocalCssParser
function LocalCssParser:new(filename, range)
    logger.trace("CssParser:new()")
    local instance = Parser:new(filename)
    setmetatable(instance, { __index = LocalCssParser })
    instance.range = range
    return instance
end

function LocalCssParser:_get_root(bufnr)
    local treesitter_parser = vim.treesitter.get_parser(bufnr, "css")
    local root = treesitter_parser:parse()[1]:root()
    return root
end

---@param cb fun(selectors: table<string, CssSelectorInfo[]>): nil
function LocalCssParser:parse(cb)
    local filename = self.filename
    local bufnr = vim.fn.bufadd(filename)
    logger.trace(string.format("LocalCssParser:parse() of %s", filename))
    local root = self:_get_root(bufnr)
    local selectors = parse_nodes(root, bufnr)
    logger.debug(
        string.format("done parsing nodes of local css file %s", filename)
    )
    logger.debug(selectors)
    cb(selectors)
end

return LocalCssParser
