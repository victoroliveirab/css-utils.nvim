---@param url string
---@return string[]
local transform_url_into_filepath = function(url)
    local filename = string.gsub(url, "/", "_")
    local path = {
        vim.fn.stdpath("data"),
        "css-utils",
        "remote",
        filename,
    }
    return path
end

return {
    transform_url_into_filepath = transform_url_into_filepath,
}
