---@class ConfigKeymaps
---@field peek_previous string
---@field peek_next string

---@class ConfigState
---@field keymaps ConfigKeymaps

---@class CssSelectorInfo
---@field preview_text string
---@field range integer[]
---@field selector_range integer[]

---@class LspState
---@field attached_handlers_map table<integer, table<string, boolean>>
---@field hover_cache table<string, table<string, table>>

---@class HtmlState
---@field stylesheets_by_file table<string, string[]>

---@class CssState
---@field selectors_by_file table<string, table<string, CssSelectorInfo[]>>

---@class State
---@field config ConfigState
---@field css CssState
---@field html HtmlState
---@field lsp LspState
local State = {
    config = {
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
