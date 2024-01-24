local constants = require("css-utils.constants")
local logger = require("css-utils.logger")

---@param node TSNode
local parse_node = function(node, bufnr, selectors)
    local type = node:type()
    local prefix = type == "id_name" and "#" or "."
    local row_start, col_start, row_end, col_end = node:range()
    local node_text = table.concat(
        vim.api.nvim_buf_get_text(
            bufnr,
            row_start,
            col_start,
            row_end,
            col_end,
            {}
        ),
        "\n"
    )
    local name = prefix .. node_text
    if not selectors[name] then
        selectors[name] = {}
    end
    local rule_set = node:parent()
    while rule_set and rule_set:type() ~= "rule_set" do
        rule_set = rule_set:parent()
    end
    if not rule_set then
        logger.debug("no ruleset found for node " .. name)
        logger.debug(node:range())
        return
    end
    logger.debug(
        string.format(
            "%s=%s found at range %d,%d,%d,%d",
            type,
            name,
            row_start,
            col_start,
            row_end,
            col_end
        )
    )
    local rs_row_start, rs_col_start, rs_row_end, rs_col_end = rule_set:range()
    logger.debug(
        string.format(
            "rule_set of %s=%s at range %d,%d,%d,%d",
            type,
            name,
            rs_row_start,
            rs_col_start,
            rs_row_end,
            rs_col_end
        )
    )

    -- check if the selector_range is already present. If it is, no need to duplicate the selector
    for _, selector in ipairs(selectors[name]) do
        if
            rs_row_start == selector.selector_range[1]
            and rs_col_start == selector.selector_range[2]
        then
            return
        end
    end

    local css_selector_info = {
        -- FIXME: using vim.api.nvim_buf_get_lines won't work for unformatted files. use vim.api.nvim_buf_get_text instead
        preview_text = "A",
        range = { row_start, col_start, row_end, col_end },
        selector_range = {
            rs_row_start,
            rs_col_start,
            rs_row_end,
            rs_col_end,
        },
    }
    table.insert(selectors[name], css_selector_info)
end

---@param root TSNode
---@param bufnr integer
---@return CssSelectorInfo[]
local parse_nodes = function(root, bufnr)
    local query = vim.treesitter.query.parse(
        "css",
        constants.treesitter_query_id_and_classes
    )
    local selectors = {}
    for _, match in query:iter_matches(root, bufnr, 0, 0) do
        for _, node in pairs(match) do
            parse_node(node, bufnr, selectors)
        end
    end

    return selectors
end

return {
    parse_nodes = parse_nodes,
}
