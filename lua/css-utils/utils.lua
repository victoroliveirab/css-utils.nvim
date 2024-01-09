---@param buf integer
---@param node TSNode
local get_ts_node_text = function(buf, node)
    local row_start, col_start, row_end, col_end = node:range()
    return vim.api.nvim_buf_get_text(
        buf,
        row_start,
        col_start,
        row_end,
        col_end,
        {}
    )[1]
end

---@param str string
---@return boolean
local has_whitespace = function(str)
    return string.match(str, "%s") ~= nil
end

return {
    get_ts_node_text = get_ts_node_text,
    has_whitespace = has_whitespace,
}
