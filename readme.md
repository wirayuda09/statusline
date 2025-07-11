# 🧬 statusline.nvim

Custom statusline plugin for Neovim written in pure Lua. Focused on **clarity**, **LSP diagnostics**, and **custom message handling** (e.g. from `print`, `vim.notify`, or `vim.api.nvim_echo`). Supports git branch, file info, and message overrides — all with no external dependencies.

---

## ✨ Features

- 📌 Mode display (NORMAL, INSERT, VISUAL, etc.)
- 📁 Filename with modified/readonly indicators
- 🌿 Git branch name (fetched every 5s, cached)
- 💡 LSP diagnostics (errors, warnings, hints, info)
- 🧠 Cursor position (line, column, progress %)
- 🔄 Auto-captures `print()` and `vim.notify()` messages and shows them in the statusline
- 🚫 Suppresses default Neovim messages (via `cmdheight=0`)
- 🔕 Optional filtering of noisy plugin messages

- 🎨 **Colorscheme adaptation** - Automatically adapts colors to match your active colorscheme

---

## 🛠️ Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "wirayuda09/statusline",
  event="VimEnter",
  config = function()
    require("statusline").setup()
  end
}
```

## 🎨 Colorscheme Adaptation

The statusline automatically adapts its colors to match your active colorscheme. It extracts colors from various highlight groups:

- **Mode colors**: Uses `Function`, `String`, `Type`, `Error`, and `Special` highlight groups
- **Semantic colors**: Uses `Error`, `WarningMsg`, `MoreMsg`, `Question`, and `Comment` highlight groups
- **Base colors**: Uses `StatusLine` and `StatusLineNC` highlight groups

The statusline will automatically refresh its colors when you change colorschemes. You can also manually refresh colors using:

```lua
require("statusline").refresh_colors()
```

### 🌈 External Colorscheme Support

The statusline is designed to work seamlessly with popular external colorscheme plugins including:

- **Modern themes**: `tokyonight`, `catppuccin`, `gruvbox`, `nord`, `dracula`
- **Popular themes**: `onedark`, `material`, `nightfox`, `rose-pine`, `kanagawa`
- **Classic themes**: `everforest`, `sonokai`, `edge`, `monokai`, `molokai`

### 🔧 Troubleshooting

If the statusline doesn't adapt to your colorscheme:

1. **Manual refresh**: Try calling `require("statusline").refresh_colors()`
2. **Debug mode**: Enable debug logging with `vim.g.statusline_debug = true`
3. **Plugin timing**: Some colorscheme plugins load asynchronously. The statusline handles this automatically, but you can manually trigger a refresh if needed.

### 🧪 Testing

Use the provided test scripts to verify compatibility:

```lua
-- Test with built-in colorschemes
:lua require("statusline").refresh_colors()

-- Test with external colorschemes (requires plugins to be installed)
:source test_external_colorschemes.lua
```

If a colorscheme doesn't provide certain highlight groups, the statusline will fall back to carefully chosen default colors.

```
[session:window:pane] MODE filename git-branch
```

- **Session**: Current tmux session name
- **Window**: Current window name
- **Pane**: Current pane index (0-based)

The tmux info is cached and updates every 2 seconds for performance. You can manually refresh it using:

```lua
require("statusline").refresh_tmux()
```

---
