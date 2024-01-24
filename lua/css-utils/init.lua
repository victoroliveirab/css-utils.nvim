local Path = require("plenary.path")

local cmp = require("css-utils.cmp")
local logger = require("css-utils.logger")
local persistance = require("css-utils.persistance")
local register_css_autocmds = require("css-utils.autocmds.css")
local register_html_autocmds = require("css-utils.autocmds.html")
local state = require("css-utils.state")

local recreate_state = function()
    local cache_file = state.config.cache_file
    if not cache_file then
        return
    end
    local cached_state = persistance.read(cache_file)
    if not cached_state then
        return
    end
    state.css = cached_state.css
    state.html = cached_state.html
end

local M = {}

---@class CssUtilsConfig
---@field allow_style_in_body boolean?
---@field cache_file string | boolean?
---@field dev boolean?
---@field disabled boolean?
---@field keymaps ConfigKeymaps?

---@param config CssUtilsConfig?
M.setup = function(config)
    config = config or {}
    local disabled = config.disabled or false
    if disabled then
        return
    end
    local dev_mode = config.dev or false
    if dev_mode then
        logger.level = "trace"
        logger.use_console = "async"
        vim.lsp.set_log_level("TRACE")
        vim.api.nvim_create_user_command("CssUtilsDebug", function()
            print(vim.inspect(require("css-utils.state")))
        end, {})
    end
    logger.trace("setup()")

    -- keymaps
    local keymaps = config.keymaps or {}

    for action in pairs(state.config.keymaps) do
        logger.debug(string.format("action=%s", action))
        if keymaps[action] == false then
            logger.debug(string.format("user disabled keymap for action=%s"))
            state.config.keymaps[action] = nil
        end
        if type(keymaps[action]) == "string" then
            logger.debug(
                string.format(
                    "user override of keymap for action=%s is %s",
                    action,
                    keymaps[action]
                )
            )
            state.config.keymaps[action] = keymaps[action]
        end
    end

    local allow_style_in_body = config.allow_style_in_body or false
    state.config.allow_style_in_body = allow_style_in_body

    -- TODO: make this accept a function to create a cache file for each project instead only a big one
    local cache_file = config.cache_file or "cache.json"
    local cache_file_path = { vim.fn.stdpath("data"), "css-utils", cache_file }
    if type(cache_file) == "string" then
        cache_file_path[3] = cache_file
        state.config.cache_file = cache_file_path
    elseif type(cache_file) == "boolean" then
        state.config.cache_file = cache_file and cache_file_path or nil
    end

    local css_utils_data_path = Path:new({
        vim.fn.stdpath("data"),
        "css-utils",
    })

    -- Check data directory to handle downloaded stylesheets
    if not css_utils_data_path:exists() then
        css_utils_data_path:mkdir()
    end

    local remote_stylesheets_path = Path:new({
        vim.fn.stdpath("data"),
        "css-utils",
        "remote",
    })

    if not remote_stylesheets_path:exists() then
        remote_stylesheets_path:mkdir()
    end

    recreate_state()
    logger.debug("initial state:")
    logger.debug(state)

    vim.api.nvim_create_user_command("CssUtilsClearCache", function()
        -- TODO: clear everything, including remote css downloaded files
        state.html.stylesheets_by_file = {}
        state.css.selectors_by_file = {}
        persistance.write(state.config.cache_file, state)
    end, {})

    register_html_autocmds()
    register_css_autocmds()

    cmp.register()
end

return M
