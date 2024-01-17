local Parser = require("css-utils.parsers")
local logger = require("css-utils.logger")

local href_pattern_dbl_quotes = 'href="[^"]*"'
local href_pattern_sgl_quotes = "href='[^']*'"

---@class HtmlParsedLink
---@field href string
---@field file string
---@field type "inline" | "local" | "remote"

---@param bufnr integer
---@param item LspSymbol
---@param stylesheets HtmlParsedLink[]
local handle_link_tag = function(bufnr, item, stylesheets)
    logger.trace(string.format("handle_link_tag() - bufnr=%d", bufnr))
    logger.trace(item)
    local line =
        vim.api.nvim_buf_get_lines(bufnr, item.lnum - 1, item.lnum, false)[1]

    -- TODO: improve the decision to consider a link a stylesheet or not
    -- This seems too restrictive
    if not string.find(line, 'rel="stylesheet"') then
        logger.debug("Line discarded (is not a stylesheet):")
        logger.debug(line)
        return
    end

    local href_start, href_end = string.find(line, href_pattern_dbl_quotes)
    if not href_start then
        href_start, href_end = string.find(line, href_pattern_sgl_quotes)
    end
    -- Remove href=" from the start and " at the end
    local href = string.sub(line, href_start + 6, href_end - 1)

    if not vim.endswith(href, "css") then
        logger.debug("Line discarded (doesn't end with css)")
        logger.debug(line)
        return
    end

    local entry = {
        href = href,
        file = vim.api.nvim_buf_get_name(bufnr),
        type = string.sub(href, 1, 4) == "http" and "remote" or "local",
    }
    logger.debug(string.format("New entry found on bufnr=%d:", bufnr))
    logger.debug(entry)
    table.insert(stylesheets, entry)
end

---@class HtmlParser : BaseParser
---@field acc HtmlParser[]
local HtmlParser = {}
setmetatable(HtmlParser, { __index = Parser })

---@param bufnr integer
---@return HtmlParser
function HtmlParser:new(bufnr)
    logger.trace("HtmlParser:new()")
    local instance = Parser:new(bufnr)
    setmetatable(instance, { __index = HtmlParser })
    return instance
end

---@param cb fun(links: HtmlParsedLink[]): nil
function HtmlParser:parse(cb)
    logger.trace("HtmlParser:parse()")
    vim.lsp.buf.document_symbol({
        on_list = function(object)
            local stylesheets = {}
            ---@type LspSymbol[]
            local items = object.items
            for _, item in ipairs(items) do
                local type = item.text
                logger.debug(type)
                logger.debug(item)
                if type == "[Field] link" then
                    handle_link_tag(self.bufnr, item, stylesheets)
                elseif type == "[Field] style" then
                    table.insert(stylesheets, {
                        href = vim.api.nvim_buf_get_name(self.bufnr),
                        file = vim.api.nvim_buf_get_name(self.bufnr),
                        type = "inline",
                    })
                end
            end
            cb(stylesheets)
        end,
    })
end

return HtmlParser
