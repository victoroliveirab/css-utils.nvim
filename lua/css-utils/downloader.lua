local curl = require("plenary.curl")
local Path = require("plenary.path")

local logger = require("css-utils.logger")

---@param url string
---@param cb fun(downloaded_filename: string)
local download = function(url, cb)
    local filename = string.gsub(url, "/", "_")
    local file = Path:new({
        vim.fn.stdpath("data"),
        "css-utils",
        "remote",
        filename,
    })
    if file:exists() then
        logger.debug(
            string.format(
                "%s already exists, jumping curl request",
                file.filename
            )
        )
        return cb(file.filename)
    end

    curl.get(url, {
        callback = function(response)
            file:touch()
            local writeable = io.open(file.filename, "w")
            if not writeable then
                logger.error(
                    string.format(
                        "could not open %s as writeable, aborting...",
                        file.filename
                    )
                )
                return
            end
            writeable:write(response.body)
            writeable:close()
            return cb(file.filename)
        end,
    })
end

return download
