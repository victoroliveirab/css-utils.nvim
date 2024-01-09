---@class CssSelectorInfo
---@field preview_text string
---@field range integer[]
---@field selector_range integer[]

---@class State
---@field stylesheets_by_html_file table<string, string[]>
---@field selectors_by_css_file table<string, table<string, CssSelectorInfo[]>>
local State = {
    stylesheets_by_html_file = {},
    selectors_by_css_file = {},
}

return State
