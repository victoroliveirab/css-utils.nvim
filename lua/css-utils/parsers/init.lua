local logger = require("css-utils.logger")

---@class BaseParser
---@field buf integer
local Parser = {
    bufnr = -1,
}

local Parser_mt = { __index = Parser }

---@param bufnr integer
function Parser:new(bufnr)
    logger.trace(string.format("Parser:new(%d)", bufnr))
    local instance = {
        bufnr = bufnr,
    }
    setmetatable(instance, Parser_mt)
    return instance
end

function Parser:parse()
    logger.trace("BaseParser:parse()")
    error("Should implement", 2)
end

return Parser
