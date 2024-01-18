local CssParser = require("css-utils.parsers.css")
local HtmlParser = require("css-utils.parsers.html")
local html_handlers = require("css-utils.lsp.handlers.html")
local logger = require("css-utils.logger")
local lsp_utils = require("css-utils.lsp.utils")
local state = require("css-utils.state")

local on_attach = function(params)
    local lsp_client_id = params.data.client_id
    local lsp_client = vim.lsp.get_client_by_id(lsp_client_id)
    if lsp_client.name ~= "html" then
        return
    end
    -- Make sure duplicate handler attaching is not done
    if state.lsp.attached_handlers_map[lsp_client_id] then
        return
    end
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

    local filename = vim.api.nvim_buf_get_name(params.buf)

    local parse_file = function()
        local html_parser = HtmlParser:new(
            params.buf,
            { stop_at_body = not state.config.allow_style_in_body }
        )
        html_parser:parse(function(css_links)
            for _, css_link in ipairs(css_links) do
                local html_file = css_link.file
                if not state.html.stylesheets_by_file[filename] then
                    logger.debug(
                        string.format(
                            "(re)creating state.html.stylesheets_by_file[%s]",
                            filename
                        )
                    )
                    state.html.stylesheets_by_file[html_file] = {}
                end
                -- OPTIMIZE: avoid reparsing CSS that was already parsed and not modified
                -- REFACTOR: DRY this badboy
                if css_link.type == "local" then
                    local css_bufnr = vim.fn.bufadd(css_link.href)
                    local css_path = vim.api.nvim_buf_get_name(css_bufnr)
                    table.insert(state.html.stylesheets_by_file[html_file], {
                        href = css_link.href,
                        path = css_path,
                    })
                    vim.api.nvim_buf_set_option(css_bufnr, "filetype", "css")
                    local css_parser = CssParser:new(css_bufnr, css_link)
                    css_parser:parse(function(selectors)
                        state.css.selectors_by_file[css_path] = selectors
                    end)
                elseif css_link.type == "inline" then
                    table.insert(state.html.stylesheets_by_file[html_file], {
                        href = css_link.href,
                        path = css_link.file,
                    })
                    local css_parser = CssParser:new(params.buf, css_link)
                    css_parser:parse(function(selectors)
                        state.css.selectors_by_file[css_link.file] = selectors
                    end)
                elseif css_link.type == "remote" then
                    local url = css_link.href
                    local css_filename = string.gsub(url, "/", "_")
                    local file = require("plenary.path"):new({
                        vim.fn.stdpath("data"),
                        "css-utils",
                        "remote",
                        css_filename,
                    })
                    if file:exists() then
                        logger.debug(
                            string.format(
                                "%s already exists, jumping http fetching",
                                file.filename
                            )
                        )
                        local css_bufnr = vim.fn.bufadd(file.filename)
                        local css_path = vim.api.nvim_buf_get_name(css_bufnr)
                        table.insert(
                            state.html.stylesheets_by_file[html_file],
                            {
                                href = url,
                                path = css_path,
                            }
                        )
                        vim.api.nvim_buf_set_option(
                            css_bufnr,
                            "filetype",
                            "css"
                        )
                        local css_parser = CssParser:new(css_bufnr, css_link)
                        css_parser:parse(function(selectors)
                            state.css.selectors_by_file[file.filename] =
                                selectors
                        end)
                    else
                        logger.debug(
                            string.format("fetching css file at %s", url)
                        )
                        require("plenary.curl").get(url, {
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
                                vim.defer_fn(function()
                                    local css_bufnr =
                                        vim.fn.bufadd(file.filename)
                                    local css_path =
                                        vim.api.nvim_buf_get_name(css_bufnr)
                                    table.insert(
                                        state.html.stylesheets_by_file[html_file],
                                        {
                                            href = url,
                                            path = css_path,
                                        }
                                    )
                                    vim.api.nvim_buf_set_option(
                                        css_bufnr,
                                        "filetype",
                                        "css"
                                    )
                                    local css_parser =
                                        CssParser:new(css_bufnr, css_link)
                                    css_parser:parse(function(selectors)
                                        state.css.selectors_by_file[css_path] =
                                            selectors
                                    end)
                                end, 10000)
                            end,
                            on_error = function(err)
                                logger.error(err)
                            end,
                        })
                    end
                end
            end
        end)
    end
    parse_file()
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function()
            logger.trace(
                string.format(
                    "reparsing bufnr=%d, filename=%s",
                    params.buf,
                    filename
                )
            )
            state.html.stylesheets_by_file[filename] = nil
            state.lsp.hover_cache[filename] = nil
            logger.debug(state.html)
            parse_file()
        end,
    })
end

return on_attach
