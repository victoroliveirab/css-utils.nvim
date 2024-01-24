local downloader = require("css-utils.downloader")
local HtmlParser = require("css-utils.parsers.markup.html")
local html_handlers = require("css-utils.lsp.handlers.html")
local InlineCssParser = require("css-utils.parsers.css.inline")
local LocalCssParser = require("css-utils.parsers.css.local")
local logger = require("css-utils.logger")
local lsp_utils = require("css-utils.lsp.utils")
local state = require("css-utils.state")

local register = function()
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(params)
            local lsp_client_id = params.data.client_id
            local lsp_client = vim.lsp.get_client_by_id(lsp_client_id)
            if lsp_client.name ~= "html" then
                return
            end
            local bufnr = params.buf
            local filename = vim.api.nvim_buf_get_name(bufnr)
            logger.trace(string.format("html lsp attached to %s", filename))
            -- Make sure duplicate handler attaching is not done
            if not state.lsp.attached_handlers_map[lsp_client_id] then
                state.lsp.attached_handlers_map[lsp_client_id] = true
                lsp_utils.attach_custom_handler(
                    lsp_client,
                    "textDocument/definition",
                    html_handlers.go_to_definition
                )
                lsp_utils.attach_custom_handler(
                    lsp_client,
                    "textDocument/hover",
                    html_handlers.hover
                )
            end

            local parser = HtmlParser:new(
                filename,
                { stop_at_body = not state.config.allow_style_in_body }
            )
            parser:parse(function(css_links)
                logger.debug(
                    string.format(
                        "html_parser:parse of %s finished with css_links:",
                        filename
                    )
                )
                logger.debug(css_links)
                state.html.stylesheets_by_file[filename] = {
                    list = {},
                }
                for _, css_link in ipairs(css_links) do
                    if css_link.type == "local" then
                        local css_path = css_link.href
                        local local_css_parser = LocalCssParser:new(css_path)
                        local_css_parser:parse(function(selectors)
                            table.insert(
                                state.html.stylesheets_by_file[filename].list,
                                {
                                    href = css_link.href,
                                    path = css_path,
                                }
                            )
                            state.css.selectors_by_file[css_path] = {
                                list = selectors,
                                timestamp = os.time(),
                            }
                        end)
                    elseif css_link.type == "inline" then
                        local inline_css_parser =
                            InlineCssParser:new(css_link.href, css_link.range)
                        inline_css_parser:parse(function(selectors)
                            table.insert(
                                state.html.stylesheets_by_file[filename].list,
                                {
                                    href = css_link.href,
                                    path = css_link.file,
                                }
                            )
                            state.css.selectors_by_file[css_link.file] = {
                                list = selectors,
                                timestamp = os.time(),
                            }
                        end)
                    elseif css_link.type == "remote" then
                        local url = css_link.href
                        downloader(url, function(downloaded_filename)
                            local local_css_parser =
                                LocalCssParser:new(downloaded_filename)
                            local_css_parser:parse(function(selectors)
                                table.insert(
                                    state.html.stylesheets_by_file[filename].list,
                                    {
                                        href = url,
                                        path = downloaded_filename,
                                    }
                                )
                                state.css.selectors_by_file[downloaded_filename] =
                                    {
                                        list = selectors,
                                        timestamp = os.time(),
                                    }
                            end)
                        end)
                    end
                end
                state.html.stylesheets_by_file[filename].timestamp = os.time()
            end)
        end,
        pattern = { "*.html" },
    })
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function(params)
            local bufnr = params.buf
            local filename = vim.api.nvim_buf_get_name(bufnr)
            logger.trace(
                string.format("BufWritePost event ran at %s", filename)
            )
            state.html.stylesheets_by_file[filename] = nil
            local parser = HtmlParser:new(
                filename,
                { stop_at_body = not state.config.allow_style_in_body }
            )
            parser:parse(function(css_links)
                logger.debug(string.format("html parsing of %s done", filename))
                logger.debug(css_links)
                state.html.stylesheets_by_file[filename] = {
                    list = css_links,
                    timestamp = os.time(),
                }
                for _, css_link in ipairs(css_links) do
                    -- After HTML file save, only inline css has to be reparsed
                    if css_link.type == "inline" then
                        logger.debug("found inline css to reparse at range:")
                        logger.debug(css_link.range)
                        local inline_parser =
                            InlineCssParser:new(filename, css_link.range)
                        inline_parser:parse(function(selectors)
                            state.css.selectors_by_file[css_link.file] = {
                                list = selectors,
                                timestamp = os.time(),
                            }
                        end)
                    end
                end
                -- TODO: check if there's some new stylesheet and if there is, parse it
            end)
        end,
        pattern = { "*.html" },
    })
end

return register
