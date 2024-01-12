# css-utils.nvim

A neovim plugin to improve the developer experience of writing HTML and CSS together. You deserve to write markup with style 😉

## Why?

Have you noticed that when trying to peek a css class or id definition from your HTML file nothing happens? Also, hovering the cited selectors doesn't help you either?
This is because the [HTML language server](https://github.com/microsoft/vscode-html-languageservice) does not implement a `definition` handler.
Likewise, the `hover` handler, although implemented, only shows information regarding HTML tags.

## How?

By leveraging the HTML language server `findDocumentSymbols` handler, tracking referenced stylesheets, and parsing each one of them with [tree-sitter](https://github.com/tree-sitter/tree-sitter) inside neovim,
we can create a map of classes/ids to file locations and have a similar workflow to what we have developing javascript-based web apps.

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
To do. The only configuration available for now is to enable dev-mode.

## Roadmap
- [ ] Add hover handler and cycling window to peek definitions
- [ ] Add support to `htmldjango` and `erb`
- [ ] Add support to `<style>` tags
- [ ] Add support to external/cdn stylesheets
- [ ] Add ability to persist of parsed css between sessions
- [ ] Add auto reparse of modified files, including when done outside neovim
- [ ] Add ability to decide between eager or lazy project scan
- [ ] Add tests with luassert/plenary
- [ ] Add github actions to run tests
- [ ] Write a CONTRIBUTING document
