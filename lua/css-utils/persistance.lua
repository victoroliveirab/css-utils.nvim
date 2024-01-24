local Path = require("plenary.path")

local logger = require("css-utils.logger")

---@param path string[]
---@return State?
local read = function(path)
    logger.trace("persistance.read()")
    local file = Path:new(path)
    if not file:exists() then
        return
    end
    local reader = function()
        return vim.fn.json_decode(file:read())
    end
    local ok, content = pcall(reader)
    if not ok then
        return
    end
    return content
end

---@param path string[]
---@param state State
local write = function(path, state)
    logger.trace("persistance.write()")
    logger.trace(path)
    local file = Path:new(path)
    if not file:exists() then
        logger.info("touch file!!!!!!")
        file:touch()
    end
    logger.info("WRITE!")
    file:write(vim.fn.json_encode(state), "w")
    logger.info("AFTER WRITE!")
end

return {
    read = read,
    write = write,
}
