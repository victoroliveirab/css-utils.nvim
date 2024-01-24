local logger = require("css-utils.logger")

---@class BaseParser
---@field filename string
local Parser = {
    filename = "",
}

local Parser_mt = { __index = Parser }

---@param filename string
function Parser:new(filename)
    logger.trace(string.format("Parser:new(%s)", filename))
    local instance = {
        filename = filename,
    }
    setmetatable(instance, Parser_mt)
    return instance
end

function Parser:parse()
    logger.trace("BaseParser:parse()")
    error("Should implement", 2)
end

return Parser
