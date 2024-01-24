---@class ListWithTimestamp<T>: { list: T, timestamp: integer }

---@class ConfigKeymaps
---@field peek_previous string
---@field peek_next string

---@class ConfigState
---@field allow_style_in_body boolean
---@field cache_file string[]?
---@field keymaps ConfigKeymaps

---@alias CssFileType "inline" | "local" | "remote"

---@class HtmlCssInfo
---@field href string the link attached to the html
---@field origin string the origin of the css file
---@field path string the filepath to the css file (href expanded to fullpath for all css files, except remote)
---@field range? integer[] the rnage where the css is (only useful for inline css)
---@field type CssFileType the kind of css file

---@class CssSelectorInfo
---@field preview_text string
---@field range integer[]
---@field selector_range integer[]

---@class LspState
---@field attached_handlers_map table<integer, true>
---@field hover_cache table<string, table<string, table>>

---@class HtmlState
---@field stylesheets_by_file table<string, ListWithTimestamp<HtmlCssInfo[]>>

---@class CssState
---@field selectors_by_file table<string, ListWithTimestamp<table<string, CssSelectorInfo[]>>>

---@class State
---@field config ConfigState
---@field css CssState
---@field html HtmlState
---@field lsp LspState
local State = {
    config = {
        allow_style_in_body = false,
        keymaps = {
            peek_next = "<C-l>",
            peek_previous = "<C-h>",
        },
    },
    css = {
        selectors_by_file = {},
    },
    html = {
        stylesheets_by_file = {},
    },
    lsp = {
        attached_handlers_map = {},
        hover_cache = {},
    },
}

return State
