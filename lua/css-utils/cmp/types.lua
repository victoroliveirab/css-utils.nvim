---@class CmpContext
---@field bufnr integer
---@field cursor { character: integer, col: integer, line: integer, row: integer }
---@field cursor_after_line string
---@field cursor_before_line string
---@field cursor_line string
---@field filetype string

---@class CmpContent
---@field context CmpContext

---@class CmpSuggestion
---@field label string
---@field kind string
---@field detail? string
---@field documentation? string

---@alias CmpCallback fun(items: CmpSuggestion[] | nil): nil

---@class CmpSourceInstance
---@field name string
---@field complete? fun(self: CmpSourceInstance, content: CmpContent, callback: CmpCallback)
---@field register? fun()
