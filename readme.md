
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
