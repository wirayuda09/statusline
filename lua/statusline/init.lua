-- statusline/init.lua
local M = {}

-- Cache for performance
local cache = {
	mode = { value = "", time = 0, ttl = 50 },
	file = { value = "", time = 0, ttl = 1000 },
	git = { value = "", time = 0, ttl = 5000 },
	diagnostics = { value = "", time = 0, ttl = 500 },
	position = { value = "", time = 0, ttl = 100 },
	lsp = { value = "", time = 0, ttl = 200 },
	lsp_progress = {},
	statusline = "",
	last_update = 0,
	update_threshold = 50,
	git_timer = nil,
	message_timer = nil,
	message = "",
	message_timeout = 3000,
}

-- Icons
local icons = {
	file = "󰈙",
	modified = "●",
	readonly = "󰌾",
	git_branch = "󰊢",
	error = "󰅚",
	warn = "󰀪",
	info = "󰋽",
	hint = "󰌶",
	normal = "󰊠",
	insert = "󰏫",
	visual = "󰈈",
	command = "󰘳",
	replace = "󰛔",
	line = "󰍒",
	percent = "󰏰",
	progress = "󰔟",
}

-- Highlight setup
local function setup_highlights()
	local links = {
		StatusLineModeNormal = "StatusLine",
		StatusLineModeInsert = "StatusLine",
		StatusLineModeVisual = "StatusLine",
		StatusLineModeCommand = "StatusLine",
		StatusLineModeReplace = "StatusLine",
		StatusLineFile = "StatusLine",
		StatusLineGit = "StatusLine",
		StatusLineError = "StatusLine",
		StatusLineWarn = "StatusLine",
		StatusLineInfo = "StatusLine",
		StatusLineHint = "StatusLine",
		StatusLinePosition = "StatusLine",
		StatusLineLSP = "StatusLine",
		StatusLineProgress = "StatusLine",
		StatusLineMessage = "StatusLine",
		StatusLineAccent = "StatusLine",
		StatusLineSepLeft = "StatusLine",
		StatusLineSepRight = "StatusLine",
	}
	for group, link in pairs(links) do
		vim.cmd(string.format("highlight default link %s %s", group, link))
	end

	-- Check if StatusLine background is NONE (transparent)
	local statusline_bg = vim.api.nvim_get_hl_by_name("StatusLine", true).background
	if not statusline_bg or statusline_bg == 0 then
		-- If transparent, set all custom groups to guibg=NONE
		for group, _ in pairs(links) do
			vim.cmd(string.format("highlight default %s guibg=NONE ctermbg=NONE", group))
		end
	end

	vim.cmd("highlight StatusLine guibg=#222222AA guifg=#ffffff")
end

-- LSP progress
local function setup_lsp_progress()
	vim.lsp.handlers["$/progress"] = function(_, result, ctx)
		local client = vim.lsp.get_client_by_id(ctx.client_id)
		if not client or not result.value then
			return
		end
		local token, value = result.token, result.value
		if value.kind == "begin" then
			cache.lsp_progress[token] = { title = value.title, percentage = value.percentage }
		elseif value.kind == "report" and cache.lsp_progress[token] then
			cache.lsp_progress[token].percentage = value.percentage
		elseif value.kind == "end" then
			cache.lsp_progress[token] = nil
		end
		cache.lsp.time = 0
		vim.schedule(function()
			vim.cmd("redrawstatus")
		end)
	end
end

-- Cache helper
local function get_cached(key, fn)
	local now = vim.loop.now()
	local e = cache[key]
	if now - e.time > e.ttl then
		e.value, e.time = fn() or "", now
	end
	return e.value
end

-- Component getters
local function get_lsp_info()
	return get_cached("lsp", function()
		local parts = {}
		for _, p in pairs(cache.lsp_progress) do
			table.insert(parts, string.format("%d%%", p.percentage or 0))
		end
		return parts[1] and string.format(" %%#StatusLineProgress#%s %%*", parts[1]) or ""
	end)
end

local function get_mode_info()
	local m = vim.api.nvim_get_mode().mode
	local map = {
		n = "StatusLineModeNormal",
		i = "StatusLineModeInsert",
		v = "StatusLineModeVisual",
		c = "StatusLineModeCommand",
		R = "StatusLineModeReplace",
	}
	local icon = icons[m] or icons.normal
	local group = map[m] or "StatusLineModeNormal"
	return string.format("%%#%s# %s %%*", group, icon)
end

local function get_file_info()
	return get_cached("file", function()
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		if name == "" then
			return " [No Name]"
		end
		local s = string.format(" %s %s", icons.file, name)
		if vim.bo.modified then
			s = s .. icons.modified
		end
		return s
	end)
end

local function get_git_info()
	return get_cached("git", function()
		local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
		return branch ~= "" and string.format(" %s %s", icons.git_branch, branch) or ""
	end)
end

local function get_diagnostics()
	local d = vim.diagnostic.get(0)
	local errs = #vim.tbl_filter(function(x)
		return x.severity == vim.diagnostic.severity.ERROR
	end, d)
	return errs > 0 and string.format(" %%#StatusLineError#%s %d%%*", icons.error, errs) or ""
end

local function get_position()
	local l = vim.fn.line(".")
	local t = vim.fn.line("$")
	return string.format(" %%#StatusLinePosition#%d/%d %%*", l, t)
end

-- Statusline
function M.statusline()
	local left = get_mode_info() .. get_file_info() .. get_git_info() .. get_lsp_info()
	local right = get_diagnostics() .. get_position()
	return left .. "%=" .. right
end

function M.statusline_inactive()
	return get_file_info()
end

-- API
function M.show_message(msg, tm)
	cache.message = msg
	vim.defer_fn(function()
		cache.message = ""
		vim.cmd("redrawstatus")
	end, tm or cache.message_timeout)
	vim.cmd("redrawstatus")
end

function M.refresh_colors()
	setup_highlights()

	vim.cmd("redrawstatus!")
end

function M.setup()
	setup_highlights()
	setup_lsp_progress()
	vim.o.statusline = "%!v:lua.require'statusline'.statusline()"
	vim.o.cmdheight = 0
	local grp = vim.api.nvim_create_augroup("ModernStatusLine", { clear = true })
	vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, { group = grp, callback = M.refresh_colors })
end

return M
