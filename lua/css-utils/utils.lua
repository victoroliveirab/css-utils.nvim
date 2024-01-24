local Job = require("plenary.job")

local ends_with_pattern = function(str, pattern)
    local length = #str
    local _, index = string.find(str, pattern)
    return index == length
end

local exec_sync_job = function(cmd, args, cwd)
    local stderr = {}
    local stdout, code = Job:new({
        command = cmd,
        args = args,
        cwd = cwd,
        on_stderr = function(_, data)
            table.insert(stderr, data)
        end,
    }):sync()
    return stdout, code, stderr
end

---@param filepath string
local get_relative_path = function(filepath)
    local cwd = vim.loop.cwd()
    if not cwd then
        return filepath
    end
    local _, index = string.find(filepath, cwd, 1, true)
    if not index then
        return filepath
    end
    return string.sub(filepath, index + 2)
end

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
    ends_with_pattern = ends_with_pattern,
    exec_sync_job = exec_sync_job,
    get_relative_path = get_relative_path,
    get_ts_node_text = get_ts_node_text,
    has_whitespace = has_whitespace,
}
