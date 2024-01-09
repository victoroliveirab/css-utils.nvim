local logger = require("css-utils.logger")

---@class BaseParser
---@field buf integer
local Parser = {
    buf = -1,
    parsed = {},
}

local Parser_mt = { __index = Parser }

function Parser:new()
    logger.trace("Parser:new()")
    local instance = {}
    setmetatable(instance, Parser_mt)
    return instance
end

---@param buf integer
function Parser:set_buffer(buf)
    logger.trace(string.format("Parser:set_buffer(%d)", buf))
    self.buf = buf
end

function Parser:parse()
    logger.trace("BaseParser:parse()")
    error("Should implement", 2)
end

return Parser
