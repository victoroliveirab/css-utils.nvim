local constants = require("css-utils.constants")
local Parser = require("css-utils.parsers")
local logger = require("css-utils.logger")

local href_pattern_dbl_quotes = 'href="[^"]*"'
local href_pattern_sgl_quotes = "href='[^']*'"
local rel_stylesheet_dbl_quotes = 'rel="stylesheet"'
local rel_stylesheet_sgl_quotes = "rel='stylesheet'"

---@class HtmlParsedLink
---@field href string
---@field file string
---@field type "inline" | "local" | "remote"
---@field range? integer[]

---@param tag string
---@param html_filename string
---@return HtmlParsedLink?
local handle_link_tag = function(tag, html_filename)
    logger.trace("handle_link_tag()")
    if
        not string.find(tag, rel_stylesheet_dbl_quotes)
        and not string.find(tag, rel_stylesheet_sgl_quotes)
    then
        logger.debug("tag discarded (is not a stylesheet):")
        logger.debug(tag)
        return
    end

    local href_start, href_end = string.find(tag, href_pattern_dbl_quotes)
    if not href_start then
        href_start, href_end = string.find(tag, href_pattern_sgl_quotes)
    end
    -- Remove href=" from the start and " at the end
    local href = string.sub(tag, href_start + 6, href_end - 1)
    if not vim.endswith(href, "css") then
        logger.debug("tag discarded (href doesn't end with css)")
        logger.debug(tag)
        return
    end

    local entry = {
        href = href,
        file = html_filename,
        type = string.sub(href, 1, 4) == "http" and "remote" or "local",
    }
    return entry
end

---@class HtmlParser : BaseParser
---@field config { stop_at_body: boolean }
local HtmlParser = {}
setmetatable(HtmlParser, { __index = Parser })

---@param bufnr integer
---@return HtmlParser
function HtmlParser:new(bufnr, config)
    logger.trace("HtmlParser:new()")
    local instance = Parser:new(bufnr)
    setmetatable(instance, { __index = HtmlParser })
    instance.config = config
    return instance
end

---@param cb fun(links: HtmlParsedLink[]): nil
function HtmlParser:parse(cb)
    logger.trace("HtmlParser:parse()")
    local bufnr = self.bufnr
    local html_filename = vim.api.nvim_buf_get_name(bufnr)
    logger.trace(vim.api.nvim_buf_get_name(bufnr))
    local ts_parser = vim.treesitter.get_parser(bufnr, "html")
    local root = ts_parser:parse()[1]:root()
    local query =
        vim.treesitter.query.parse("html", constants.treesitter_html_tags)
    local stylesheets = {}
    for _, match in query:iter_matches(root, bufnr, 0, 0) do
        for _, node in pairs(match) do
            local type = node:type()
            if type == "raw_text" then
                -- NOTE: for some reason, table.pack is erroring
                local row_start, col_start, row_end, col_end = node:range()
                local range = { row_start, col_start, row_end, col_end }
                logger.debug("inline style found at range:")
                logger.debug(range)
                table.insert(stylesheets, {
                    href = html_filename,
                    file = html_filename,
                    type = "inline",
                    range = range,
                })
            else
                local text = vim.treesitter.get_node_text(node, bufnr)
                logger.info(text)
                if
                    vim.startswith(text, "<body") and self.config.stop_at_body
                then
                    logger.debug(
                        "found <body>, stopping search and returning stylesheets"
                    )
                    return cb(stylesheets)
                end
                if vim.startswith(text, "<link") then
                    local entry = handle_link_tag(text, html_filename)
                    if entry then
                        logger.debug(
                            string.format("new entry from tag %s", text)
                        )
                        logger.debug(entry)
                        table.insert(stylesheets, entry)
                    end
                end
            end
        end
    end
    cb(stylesheets)
end

return HtmlParser
