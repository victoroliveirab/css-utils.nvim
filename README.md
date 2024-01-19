# css-utils.nvim

A neovim plugin to improve the developer experience of writing HTML and CSS together. You deserve to write markup with style 😉

## Why?

Have you noticed that when trying to peek a css class or id definition from your HTML file nothing happens? Also, hovering the cited selectors doesn't help you either?
This is because the [HTML language server](https://github.com/microsoft/vscode-html-languageservice) does not implement a `definition` handler.
Likewise, the `hover` handler, although implemented, only shows information regarding HTML tags.

## How?

By leveraging [tree-sitter](https://github.com/tree-sitter/tree-sitter) inside neovim, we parse an HTML file, track referenced stylesheets and inline styles, and parse each one of them.
This creates a map of classes/ids to file locations and provide a similar workflow to what we have developing javascript-based web apps.

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
    }
}
```

## Roadmap
- [ ] Add support to `htmldjango` and `erb`
- [x] Add support to external/cdn stylesheets
- [ ] Try to use local node_modules for external stylesheets before downloading
- [ ] Add ability to persist of parsed css between sessions
- [ ] Add auto reparse of modified files, including when done outside neovim
- [ ] Add ability to decide between eager or lazy project scan
- [ ] Add tests with luassert/plenary
- [ ] Add github actions to run tests
- [ ] Write a CONTRIBUTING document
