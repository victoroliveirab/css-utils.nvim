local logger = require("plenary.log").new({
    level = vim.g.css_utils_dev and "trace" or "info",
    plugin = "css_utils.nvim",
    use_console = vim.g.css_utils_dev and "async" or false,
})
return logger
