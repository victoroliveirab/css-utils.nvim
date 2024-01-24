local downloader = require("css-utils.downloader")
local HtmlParser = require("css-utils.parsers.markup.html")
local html_handlers = require("css-utils.lsp.handlers.html")
local InlineCssParser = require("css-utils.parsers.css.inline")
local LocalCssParser = require("css-utils.parsers.css.local")
local logger = require("css-utils.logger")
local lsp_utils = require("css-utils.lsp.utils")
local persistance = require("css-utils.persistance")
local state = require("css-utils.state")
local transform_url_into_filepath =
    require("css-utils.downloader.utils").transform_url_into_filepath
local utils = require("css-utils.utils")

local is_cache_up_to_date = function(cache_timestamp, last_modified)
    -- only consider cache up to date if last_modified is at most 1s later than cache
    return last_modified - cache_timestamp < 1000
end

---@param css_link HtmlCssInfo
---@param html_filename string
local parse_css_link = function(css_link, html_filename)
    if css_link.type == "local" then
        local local_css_parser = LocalCssParser:new(css_link.path)
        local_css_parser:parse(function(selectors)
            table.insert(
                state.html.stylesheets_by_file[html_filename].list,
                css_link
            )
            state.css.selectors_by_file[css_link.path] = {
                list = selectors,
                timestamp = os.time(),
            }
        end)
    elseif css_link.type == "inline" then
        local inline_css_parser =
            InlineCssParser:new(css_link.path, css_link.range)
        inline_css_parser:parse(function(selectors)
            table.insert(
                state.html.stylesheets_by_file[html_filename].list,
                css_link
            )
            state.css.selectors_by_file[css_link.path] = {
                list = selectors,
                timestamp = os.time(),
            }
        end)
    elseif css_link.type == "remote" then
        local url = css_link.href
        downloader(url, function(downloaded_filename)
            local local_css_parser = LocalCssParser:new(downloaded_filename)
            logger.debug(
                string.format(
                    "parsing %s after downloading",
                    downloaded_filename
                )
            )
            local_css_parser:parse(function(selectors)
                css_link.path = downloaded_filename
                table.insert(
                    state.html.stylesheets_by_file[html_filename].list,
                    css_link
                )
                state.css.selectors_by_file[css_link.path] = {
                    list = selectors,
                    timestamp = os.time(),
                }
            end)
        end)
    end
end

---@param css_links HtmlCssInfo[]
---@param html_filename string
---@param ignore_cache boolean
local parse_css_links = function(css_links, html_filename, ignore_cache)
    if not state.html.stylesheets_by_file[html_filename] then
        state.html.stylesheets_by_file[html_filename] = {
            list = {},
        }
    end
    for _, css_link in ipairs(css_links) do
        if ignore_cache then
            parse_css_link(css_link, html_filename)
        else
            local filename = css_link.path
            local last_modified_str, return_code, err = utils.exec_sync_job(
                "stat",
                { "--format=%Y", filename },
                vim.loop.cwd()
            )
            local last_modified = #err == 0
                and return_code == 0
                and tonumber(last_modified_str[1])

            logger.info(string.format("last modified of %s", filename))
            logger.info(last_modified_str)
            logger.info(last_modified)

            if #err > 0 then
                logger.error(
                    string.format(
                        "running stat command for file %s returned the following error:",
                        filename
                    )
                )
                logger.error(err)
                state.css.selectors_by_file[filename] = nil
                parse_css_link(css_link, html_filename)
            elseif not last_modified then
                logger.debug(
                    string.format(
                        "%s was not previously cached. triggering parse",
                        filename
                    )
                )
                state.css.selectors_by_file[filename] = nil
                parse_css_link(css_link, html_filename)
            elseif not state.css.selectors_by_file[filename] then
                logger.debug(
                    string.format(
                        "%s was not previously cached. triggering parse",
                        filename
                    )
                )
                parse_css_link(css_link, html_filename)
            else
                local cached_entry_timestamp =
                    state.css.selectors_by_file[filename].timestamp
                if
                    not is_cache_up_to_date(
                        cached_entry_timestamp,
                        last_modified
                    )
                then
                    logger.debug(
                        string.format(
                            "cached version of %s is older than last modified time. triggering parse",
                            filename
                        )
                    )
                    state.css.selectors_by_file[filename] = nil
                    parse_css_link(css_link, html_filename)
                else
                    logger.debug(
                        string.format(
                            "css file %s is up to date, skipping parse",
                            filename
                        )
                    )
                end
            end
        end
    end
    state.html.stylesheets_by_file[html_filename].timestamp = os.time()
end

local parse_html_file = function(bufnr, ignore_cache)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local params = { stop_at_body = not state.config.allow_style_in_body }

    local parser = HtmlParser:new(filename, params)

    parser:parse(function(css_links)
        logger.info("parse_html_file csslinks")
        logger.info(css_links)
        parse_css_links(css_links, filename, ignore_cache)
    end)
end

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

            local on_parsing_complete = function()
                persistance.write(state.config.cache_file, state)
            end

            local last_modified_str, return_code, err = utils.exec_sync_job(
                "stat",
                { "--format=%Y", filename },
                vim.loop.cwd()
            )

            if #err > 0 then
                logger.error(
                    "running stat command returned the following error:"
                )
                logger.error(err)
                state.html.stylesheets_by_file[filename] = nil
                parse_html_file(params.buf, true)
                on_parsing_complete()
                return
            end

            local last_modified = return_code == 0
                and tonumber(last_modified_str[1])
            if not last_modified then
                logger.debug(
                    string.format(
                        "could not get last_modified stat of %s. triggering parse",
                        filename
                    )
                )
                state.html.stylesheets_by_file[filename] = nil
                parse_html_file(params.buf, true)
                on_parsing_complete()
                return
            end

            if not state.html.stylesheets_by_file[filename] then
                logger.debug(
                    string.format(
                        "%s was not previously cached. triggering parse",
                        filename
                    )
                )
                parse_html_file(params.buf, false)
                on_parsing_complete()
                return
            end

            local cached_entry_timestamp =
                state.html.stylesheets_by_file[filename].timestamp
            if
                not is_cache_up_to_date(cached_entry_timestamp, last_modified)
            then
                logger.debug(
                    string.format(
                        "cached version of %s is older than last modified time (%d < %d). triggering parse",
                        filename,
                        cached_entry_timestamp,
                        last_modified
                    )
                )
                state.html.stylesheets_by_file[filename] = nil
                parse_html_file(params.buf, false)
                on_parsing_complete()
                return
            end

            -- Cached html state is up-to-date

            local css_links = state.html.stylesheets_by_file[filename].list
            logger.debug(
                string.format(
                    "html file %s is up to date, cache_timestamp=%d, last_modified=%d",
                    filename,
                    cached_entry_timestamp,
                    last_modified
                )
            )
            parse_css_links(css_links, filename, false)
            on_parsing_complete()
            state.html.stylesheets_by_file[filename].timestamp = os.time()
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
            state.html.stylesheets_by_file[filename] = {
                timestamp = os.time(),
            }
            local parser = HtmlParser:new(
                filename,
                { stop_at_body = not state.config.allow_style_in_body }
            )
            parser:parse(function(css_links)
                logger.debug(string.format("html parsing of %s done", filename))
                logger.debug(css_links)
                state.html.stylesheets_by_file[filename].list = css_links
                for _, css_link in ipairs(css_links) do
                    -- After HTML file save, only inline css has to be reparsed
                    if css_link.type == "inline" then
                        logger.debug("found inline css to reparse at range:")
                        logger.debug(css_link.range)
                        local inline_parser =
                            InlineCssParser:new(filename, css_link.range)
                        inline_parser:parse(function(selectors)
                            state.css.selectors_by_file[css_link.path] = {
                                list = selectors,
                                timestamp = os.time(),
                            }
                        end)
                    elseif css_link.type == "remote" then
                        -- TODO: check operating system before deciding separator
                        -- Check plenary source code
                        css_link.path = table.concat(
                            transform_url_into_filepath(css_link.href),
                            "/"
                        )
                    end
                end
                -- TODO: check if there's some new stylesheet and if there is, parse it
            end)
        end,
        pattern = { "*.html" },
    })
end

return register
