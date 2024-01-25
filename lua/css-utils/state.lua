---@class ListWithTimestamp<T>: { list: T, timestamp: integer }

---@class ConfigKeymaps
---@field peek_previous string
---@field peek_next string

---@class HoverConfigUi
---@field fixed_height boolean -- whether all windows have the same height
---@field fixed_width boolean -- whether all windows have the same width
---@field max_height number -- window's max height allowed (scroll if more lines are needed)
---@field max_width number -- window's max width allowed (scroll if more lines are needed)

---@class ConfigUi
---@field hover HoverConfigUi

---@class ConfigState
---@field allow_style_in_body boolean
---@field cache_file string[]?
---@field keymaps ConfigKeymaps
---@field ui ConfigUi

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

---@class LspHoverCacheTableEntry
---@field height integer
---@field lines string[]
---@field width integer

---@class LspHoverCacheTable
---@field entries LspHoverCacheTableEntry[]
---@field max_height integer
---@field max_width integer

---@class LspState
---@field attached_handlers_map table<integer, true>
---@field hover_cache table<string, table<string, LspHoverCacheTable>>

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
        ui = {
            hover = {
                fixed_height = false,
                fixed_width = false,
                max_height = 12,
                max_width = 72,
            },
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
        -- TODO: implement config option to control hover_cache size
        -- Add timestamp to every entry and when full, remove that least recently used (LRU cache)
        hover_cache = {},
    },
}

return State
