local Path = require("plenary.path")

local logger = require("css-utils.logger")

---@param path string[]
---@return State?
local read = function(path)
    logger.trace("persistance.read()")
    local file = Path:new(path)
    if not file:exists() then
        logger.debug(
            string.format(
                "tried to read file %s but it does not exist",
                file.filename
            )
        )
        return
    end
    local reader = function()
        return vim.fn.json_decode(file:read())
    end
    local ok, content = pcall(reader)
    if not ok then
        logger.warn(
            string.format("could not json decode contents of %s", file.filename)
        )
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
        file:touch()
    end
    file:write(vim.fn.json_encode(state), "w")
end

return {
    read = read,
    write = write,
}
