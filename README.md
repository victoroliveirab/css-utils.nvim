# css-utils.nvim

A neovim plugin to improve the developer experience of writing HTML and CSS together. You deserve to write markup with style 😉

## Why?

Have you noticed that when trying to peek a css class or id definition from your HTML file nothing happens? Also, hovering the cited selectors doesn't help you either?
This is because the [HTML language server](https://github.com/microsoft/vscode-html-languageservice) does not implement a `definition` handler.
Likewise, the `hover` handler, although implemented, only shows information regarding HTML tags.

## I'm sold! How do I get started?

### Installation

Install the plugin with your favorite package manager. If you use packer, you can copy the code below:

```lua
use({
    "victoroliveirab/css-utils.nvim",
    requires = "nvim-lua/plenary.nvim",
    config = function()
        require("css-utils").setup({
            -- configuration goes here
        })
    end,
}) 
```

### Configuration
Below is the table with all the default values.

```lua
{
    -- Whether <style> tags are allowed inside <body>. `false` makes parsing html bail when <body> is found, which should increase performance.
    allow_style_in_body = false,
    -- Sets up dev mode, with logging to debug
    dev = false,
    -- Disables the plugin
    disabled = false,
    -- Sets up custom keymaps. Map to the boolean `false` to disable a keymap
    keymaps = {
        peek_previous = "<C-h>", -- Peek selector's previous definition on hover
        peek_next = "<C-l>", -- Peek selector's next definition on hover
    },
    ui = {
        hover = {
            fixed_height = false -- Controls whether hover floating window changes height when cycling through options
            fixed_width = false -- Controls whether hover floating window changes width when cycling through options
            max_height = 12 -- Controls the max number of rows of the floating window. Larger chunks of text will be scrollable
            max_width = 72 -- Controls the max number of columns of the floating window. Larger chunks of text will be scrollable
        }
    }
}
```

## Roadmap
- [ ] Add support to `htmldjango` and `erb`
- [ ] Try to use local node_modules for external stylesheets before downloading
- [ ] Add auto reparse of modified files, including when done outside neovim
- [ ] Add ability to decide between eager or lazy project scan
- [ ] Add tests with luassert/plenary
- [ ] Add github actions to run tests
- [ ] Write a CONTRIBUTING document
