---@alias LspResultContents { kind: string, value: string }

---@alias LspRangePoint { character: integer, line: integer }

---@alias LspRange { end: LspRangePoint, start: LspRangePoint }

---@class LspResult
---@field contents LspResultContents
---@field range LspRange

---@alias LspContextParams { position: LspRange, textDocument: { uri: string } }

---@class LspContext
---@field bufnr integer
---@field client_id integer
---@field method string
---@field params LspContextParams

---@class LspSymbol
---@field col integer
---@field filename string
---@field kind string
---@field lnum integer
---@field text string

---@alias LspCustomHandler fun(original_handler: lsp-handler, err: lsp.ResponseError, result: LspResult, ctx: LspContext, config: table?): nil

error("Do not import types.lua anywhere", 2)
