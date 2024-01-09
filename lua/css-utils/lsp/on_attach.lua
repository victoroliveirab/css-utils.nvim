local CssParser = require("css-utils.parsers.css")
local HtmlParser = require("css-utils.parsers.html")
local html_handlers = require("css-utils.lsp.handlers.html")
local lsp_utils = require("css-utils.lsp.utils")
local state = require("css-utils.state")

local on_attach = function(params)
    local lsp_client_id = params.data.client_id
    local lsp_client = vim.lsp.get_client_by_id(lsp_client_id)
    if lsp_client.name ~= "html" then
        return
    end
    lsp_utils.attach_custom_handler(
        lsp_client,
        "textDocument/definition",
        html_handlers.go_to_definition
    )
    local css_parser = CssParser:new()
    local html_parser = HtmlParser:new()
    html_parser:set_buffer(params.buf)
    html_parser:parse(function(css_links)
        for _, css_link in ipairs(css_links) do
            local html_file = css_link.file
            if not state.stylesheets_by_html_file[html_file] then
                state.stylesheets_by_html_file[html_file] = {}
            end
            table.insert(
                state.stylesheets_by_html_file[html_file],
                css_link.href
            )
            if css_link.type == "local" then
                local css_bufnr = vim.fn.bufadd(css_link.href)
                vim.api.nvim_buf_set_option(css_bufnr, "filetype", "css")
                css_parser:set_buffer(css_bufnr)
                css_parser:parse(function(selectors)
                    state.selectors_by_css_file[css_link.href] = selectors
                end)
            end
        end
    end)
end

return on_attach
