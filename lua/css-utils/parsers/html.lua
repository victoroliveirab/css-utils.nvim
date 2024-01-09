local Parser = require("css-utils.parsers")
local logger = require("css-utils.logger")

local href_pattern = 'href="[A-z0-9./:]*"'

---@class HtmlParsedLink
---@field href string
---@field file string
---@field type "local" | "remote"

---@class HtmlParser : BaseParser
---@field acc HtmlParser[]
local HtmlParser = {
    acc = {},
}
setmetatable(HtmlParser, { __index = Parser })

---@return HtmlParser
function HtmlParser:new()
    logger.trace("HtmlParser:new()")
    local instance = Parser:new()
    setmetatable(instance, { __index = HtmlParser })
    return instance
end

---@param item LspSymbol
function HtmlParser:handle_link_tag(item)
    logger.trace("HtmlParser:handle_link_tag(item)")
    logger.trace(item)
    local line =
        vim.api.nvim_buf_get_lines(self.buf, item.lnum - 1, item.lnum, false)[1]

    -- TODO: improve the decision to consider a link a stylesheet or not
    -- This seems too restrictive
    if not string.find(line, 'rel="stylesheet"') then
        logger.debug("Line discarded (is not a stylesheet):")
        logger.debug(line)
        return
    end

    local href_start, href_end = string.find(line, href_pattern)
    -- Remove href=" from the start and " at the end
    local href = string.sub(line, href_start + 6, href_end - 1)

    if not vim.endswith(href, "css") then
        logger.debug("Line discarded (doesn't end with css)")
        logger.debug(line)
        return
    end

    local entry = {
        href = href,
        file = vim.api.nvim_buf_get_name(self.buf),
        type = string.sub(line, 1, 4) == "http" and "remote" or "local",
    }
    logger.debug("New link:")
    logger.debug(entry)
    table.insert(self.acc, entry)
end

---@param cb fun(links: HtmlParsedLink[]): nil
function HtmlParser:parse(cb)
    logger.trace("HtmlParser:parse()")
    vim.lsp.buf.document_symbol({
        on_list = function(object)
            ---@type LspSymbol[]
            local items = object.items
            for _, item in ipairs(items) do
                local type = item.text
                if type == "[Field] link" then
                    self:handle_link_tag(item)
                end
                -- TODO: handle other cases such as <style> tags
            end
            local css_links = self.acc
            self.acc = {}
            cb(css_links)
        end,
    })
end

return HtmlParser
