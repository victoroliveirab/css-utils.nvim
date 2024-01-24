local curl = require("plenary.curl")
local Path = require("plenary.path")

local downloader_utils = require("css-utils.downloader.utils")
local logger = require("css-utils.logger")

---@param url string
---@param cb fun(downloaded_filename: string)
local download = function(url, cb)
    local filepath = downloader_utils.transform_url_into_filepath(url)
    local file = Path:new(filepath)
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
