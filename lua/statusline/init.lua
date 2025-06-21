local M = {}

-- Cache frequently accessed values
local cache = {
    mode_colors = {},
    git_branch = nil,
    git_timer = nil,
    diagnostics = { error = 0, warn = 0, info = 0, hint = 0 },
    last_update = 0,
    last_message = '',
    message_timer = nil,
    message_timeout = 3000,
    last_statusline = '',
    original_cmdheight = vim.o.cmdheight
}

-- Color definitions - will be populated from active colorscheme
local colors = {}

-- Function to get colors from active colorscheme
local function get_colorscheme_colors()
    local hl_groups = {
        -- Base colors
        bg = 'StatusLine',
        fg = 'StatusLine',
        inactive = 'StatusLineNC',
        
        -- Mode colors (using different highlight groups for variety)
        normal = 'Function',
        insert = 'String',
        visual = 'Type',
        replace = 'Error',
        command = 'Special',
        
        -- Semantic colors
        git = 'Comment',
        error = 'Error',
        warn = 'WarningMsg',
        info = 'MoreMsg',
        hint = 'Question',
        message = 'Comment',
        lsp_progress = 'Type'
    }
    
    local scheme_colors = {}
    
    -- Helper function to safely get highlight colors
    local function get_hl_color(hl_group, attr)
        local success, hl = pcall(vim.api.nvim_get_hl, 0, { name = hl_group })
        if success and hl and hl[attr] then
            -- Convert RGB to hex
            return string.format('#%06x', hl[attr])
        end
        return nil
    end
    
    -- Extract colors from highlight groups
    for name, hl_group in pairs(hl_groups) do
        local color = get_hl_color(hl_group, 'fg')
        if color then
            scheme_colors[name] = color
        end
    end
    
    -- Try to get background color from StatusLine
    local bg_color = get_hl_color('StatusLine', 'bg')
    if bg_color then
        scheme_colors.bg = bg_color
    end
    
    -- Fallback colors if colorscheme doesn't provide them
    local fallback_colors = {
        bg = '#1e1e2e',
        fg = '#cdd6f4',
        normal = '#89b4fa',
        insert = '#a6e3a1',
        visual = '#f9e2af',
        replace = '#f38ba8',
        command = '#cba6f7',
        inactive = '#6c7086',
        git = '#fab387',
        error = '#f38ba8',
        warn = '#fab387',
        info = '#89dceb',
        hint = '#94e2d5',
        message = '#a6adc8',
        lsp_progress = '#f9e2af'
    }
    
    -- Use scheme colors if available, otherwise fallback
    for name, fallback in pairs(fallback_colors) do
        colors[name] = scheme_colors[name] or fallback
    end
    
    -- Ensure we have a background color for mode indicators
    if not colors.bg or colors.bg == '' then
        colors.bg = fallback_colors.bg
    end
    
    -- Ensure we have a foreground color
    if not colors.fg or colors.fg == '' then
        colors.fg = fallback_colors.fg
    end
    
    -- Debug: Log which colors were extracted (only in verbose mode)
    if vim.g.statusline_debug then
        print("Statusline colors extracted:")
        for name, color in pairs(colors) do
            print(string.format("  %s: %s", name, color))
        end
    end
end

-- Mode mappings (will be updated with dynamic colors)
local modes = {}

-- Update mode mappings with current colors
local function update_mode_mappings()
    modes = {
        ['n'] = { 'NORMAL', colors.normal },
        ['i'] = { 'INSERT', colors.insert },
        ['v'] = { 'VISUAL', colors.visual },
        ['V'] = { 'V-LINE', colors.visual },
        ['c'] = { 'COMMAND', colors.command },
        ['s'] = { 'SELECT', colors.visual },
        ['S'] = { 'S-LINE', colors.visual },
        [''] = { 'S-BLOCK', colors.visual },
        ['R'] = { 'REPLACE', colors.replace },
        ['r'] = { 'REPLACE', colors.replace },
        ['t'] = { 'TERMINAL', colors.command }
    }
end

function M.clean_message(msg)
    if not msg then return '' end
    msg = tostring(msg)
    msg = msg
        :gsub("[\226\128\147]", "-") -- replace en dash (–) or em dash (—)
        :gsub("…", "...") -- replace ellipsis with 3 dots
        :gsub("•", "-") -- replace bullet with dash
        :gsub("↪", "->") -- arrow right
        :gsub("[\194\244].", "") -- fallback: remove unprintable UTF-8 (optional)

    return msg
end

local function truncate(msg, max_width)
    if not msg or msg == '' then return '' end
    if #msg <= max_width then return msg end
    return msg:sub(1, max_width - 1) .. '…'
end

-- Initialize highlight groups
local function setup_highlights()
    -- Refresh colors from active colorscheme
    get_colorscheme_colors()
    update_mode_mappings()
    
    local highlights = {
        StatusLine = { bg = colors.bg, fg = colors.fg },
        StatusLineNC = { bg = colors.bg, fg = colors.inactive },
        StatusLineModeNormal = { bg = colors.normal, fg = colors.bg, bold = true },
        StatusLineModeInsert = { bg = colors.insert, fg = colors.bg, bold = true },
        StatusLineModeVisual = { bg = colors.visual, fg = colors.bg, bold = true },
        StatusLineModeReplace = { bg = colors.replace, fg = colors.bg, bold = true },
        StatusLineModeCommand = { bg = colors.command, fg = colors.bg, bold = true },
        StatusLineGit = { bg = colors.bg, fg = colors.git },
        StatusLineError = { bg = colors.bg, fg = colors.error },
        StatusLineWarn = { bg = colors.bg, fg = colors.warn },
        StatusLineInfo = { bg = colors.bg, fg = colors.info },
        StatusLineHint = { bg = colors.bg, fg = colors.hint },
        StatusLineMessage = { bg = colors.bg, fg = colors.message, italic = true },
        StatusLineLspProgress = { bg = colors.bg, fg = colors.lsp_progress, italic = true }
    }

    for name, opts in pairs(highlights) do
        vim.api.nvim_set_hl(0, name, opts)
    end
end

-- Function to refresh colors when colorscheme changes
local function refresh_colors()
    setup_highlights()
    cache.last_update = 0 -- Force statusline update
    vim.schedule(function()
        vim.cmd('redrawstatus')
    end)
end

-- Function to handle popular external colorschemes
local function handle_external_colorscheme()
    local colorscheme = vim.g.colors_name or ''
    
    -- List of popular external colorschemes that might need special handling
    local external_colorschemes = {
        'tokyonight', 'catppuccin', 'gruvbox', 'nord', 'dracula', 
        'onedark', 'material', 'nightfox', 'dayfox', 'duskfox',
        'rose-pine', 'kanagawa', 'everforest', 'sonokai', 'edge',
        'monokai', 'molokai', 'zenburn', 'solarized', 'wombat'
    }
    
    -- Check if current colorscheme is in the list
    for _, name in ipairs(external_colorschemes) do
        if colorscheme:lower():find(name:lower()) then
            -- For external colorschemes, we might need to wait a bit for colors to load
            vim.schedule(function()
                vim.defer_fn(function()
                    refresh_colors()
                end, 100) -- Wait 100ms for colorscheme to fully load
            end)
            return true
        end
    end
    
    return false
end

local function set_message(msg)
    msg = M.clean_message(msg)
    if msg == cache.last_message then
        return -- Avoid duplicate messages
    end

    cache.last_message = msg
    cache.last_update = 0

    -- Clear existing timer
    if cache.message_timer then
        cache.message_timer:close()
        cache.message_timer = nil
    end

    -- Use vim.schedule to avoid circular dependency
    vim.schedule(function()
        vim.cmd('redrawstatus')
    end)

    -- Set timer to clear message
    if msg ~= '' then
        cache.message_timer = vim.loop.new_timer()
        cache.message_timer:start(cache.message_timeout, 0, vim.schedule_wrap(function()
            cache.last_message = ''
            cache.last_update = 0
            vim.schedule(function()
                vim.cmd('redrawstatus')
            end)
            if cache.message_timer then
                cache.message_timer:close()
                cache.message_timer = nil
            end
        end))
    end
end

local function setup_message_capture()
    -- Store original functions
    _G._statusline_original_print = _G.print
    _G._statusline_original_echo = vim.api.nvim_echo

    -- Override print function
    _G.print = function(...)
        local args = { ... }
        local msg = table.concat(vim.tbl_map(tostring, args), '\t')
        if msg and msg ~= '' then
            set_message(msg)
        end
    end

    -- Override echo function
    vim.api.nvim_echo = function(chunks, history, opts)
        if chunks and #chunks > 0 then
            local msg_parts = {}
            for _, chunk in ipairs(chunks) do
                if type(chunk) == 'table' and chunk[1] then
                    table.insert(msg_parts, chunk[1])
                elseif type(chunk) == 'string' then
                    table.insert(msg_parts, chunk)
                end
            end
            local msg = table.concat(msg_parts, '')
            if msg and msg ~= '' and not msg:match('^%s*$') then
                set_message(msg)
                return -- Don't call original echo
            end
        end
        return _G._statusline_original_echo(chunks, history, opts)
    end
end

local function restore_message_capture()
    if _G._statusline_original_print then
        _G.print = _G._statusline_original_print
        _G._statusline_original_print = nil
    end
    if _G._statusline_original_echo then
        vim.api.nvim_echo = _G._statusline_original_echo
        _G._statusline_original_echo = nil
    end
end

-- Get current mode
local function get_mode()
    local mode = vim.api.nvim_get_mode().mode
    local mode_info = modes[mode] or { 'UNKNOWN', colors.fg }
    return mode_info[1], mode_info[2]
end

-- Get file info
local function get_file_info()
    local buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(buf)

    if filename == '' then
        return '[No Name]'
    end

    filename = vim.fn.fnamemodify(filename, ':t')

    -- Add modified indicator
    if vim.api.nvim_buf_get_option(buf, 'modified') then
        filename = filename .. ' ●'
    end

    -- Add readonly indicator
    if vim.api.nvim_buf_get_option(buf, 'readonly') then
        filename = filename .. ' '
    end

    return filename
end

local function get_git_branch()
    if cache.git_timer and not cache.git_timer:is_closing() then
        return cache.git_branch
    end

    cache.git_timer = vim.loop.new_timer()
    cache.git_timer:start(0, 5000, vim.schedule_wrap(function()
        local handle = io.popen('git branch --show-current 2>/dev/null')
        if handle then
            local branch = handle:read('*a'):gsub('\n', '')
            handle:close()
            cache.git_branch = branch ~= '' and branch or nil
        end
    end))

    return cache.git_branch
end

-- Get LSP progress
local function get_lsp_progress()
    if not _G.lsp_progress then
        return ''
    end

    local progress_parts = {}
    for _, progress in pairs(_G.lsp_progress) do
        local part = string.format("[%s] %s", progress.client, progress.title)
        if progress.percentage > 0 then
            part = part .. string.format(" (%d%%)", progress.percentage)
        end
        if progress.message and progress.message ~= "" then
            part = part .. " " .. progress.message
        end
        table.insert(progress_parts, part)
    end

    local progress_str = table.concat(progress_parts, " | ")
    if progress_str ~= "" then
        return string.format('%%#StatusLineLspProgress# %s', progress_str)
    end
    return ''
end

local function get_diagnostics()
    local diagnostics = vim.diagnostic.get(0)
    local counts = { error = 0, warn = 0, info = 0, hint = 0 }

    for _, diagnostic in ipairs(diagnostics) do
        local severity = diagnostic.severity
        if severity == vim.diagnostic.severity.ERROR then
            counts.error = counts.error + 1
        elseif severity == vim.diagnostic.severity.WARN then
            counts.warn = counts.warn + 1
        elseif severity == vim.diagnostic.severity.INFO then
            counts.info = counts.info + 1
        elseif severity == vim.diagnostic.severity.HINT then
            counts.hint = counts.hint + 1
        end
    end

    cache.diagnostics = counts
    return counts
end

local function get_position()
    local line = vim.fn.line('.')
    local col = vim.fn.col('.')
    local total = vim.fn.line('$')
    return string.format('%d:%d %d%%%%', line, col, math.floor(line / total * 100))
end

local function build_left()
    local mode_name, mode_color = get_mode()
    local file_info = get_file_info()
    local git_branch = get_git_branch()
    local lsp_progress = get_lsp_progress()

    local mode_hl = 'StatusLineModeNormal'
    if mode_color == colors.insert then
        mode_hl = 'StatusLineModeInsert'
    elseif mode_color == colors.visual then
        mode_hl = 'StatusLineModeVisual'
    elseif mode_color == colors.replace then
        mode_hl = 'StatusLineModeReplace'
    elseif mode_color == colors.command then
        mode_hl = 'StatusLineModeCommand'
    end

    local left_section = string.format('%%#%s# %s %%#StatusLine# %s', mode_hl, mode_name, file_info)

    -- Add git branch right after file name
    if git_branch then
        left_section = left_section .. string.format(' %%#StatusLineGit# %s', git_branch)
    end

    -- Add LSP progress
    if lsp_progress ~= '' then
        left_section = left_section .. ' ' .. lsp_progress
    end

    -- Add message right after LSP progress
    if cache.last_message ~= '' then
        local total_width = vim.o.columns or 80                                -- fallback width
        local max_message_width = math.max(25, math.floor(total_width * 0.25)) -- minimum 20 chars
        local msg = truncate(cache.last_message, max_message_width)
        left_section = left_section .. string.format(' %%#StatusLineMessage# %s', msg)
    end

    return left_section
end

-- Build right section (with diagnostic symbols)
local function build_right()
    local diagnostics = get_diagnostics()
    local position = get_position()
    local filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'text'

    local diag_parts = {}
    if diagnostics.error > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineError#✘ %d', diagnostics.error))
    end
    if diagnostics.warn > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineWarn#⚠ %d', diagnostics.warn))
    end
    if diagnostics.info > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineInfo#ℹ %d', diagnostics.info))
    end
    if diagnostics.hint > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineHint#H %d', diagnostics.hint))
    end

    local diag_str = table.concat(diag_parts, ' ')
    if diag_str ~= '' then
        diag_str = diag_str .. ' %#StatusLine#'
    end

    return string.format('%s %s  %s', diag_str, filetype, position)
end

-- Main statusline function
function M.statusline()
    local current_time = vim.loop.now()

    -- Throttle updates for performance
    if current_time - cache.last_update < 100 then
        return cache.last_statusline or ''
    end

    cache.last_update = current_time

    local left = build_left()
    local right = build_right()

    -- Simple layout: left section + right section
    local statusline = string.format('%s%%=%s', left, right)

    cache.last_statusline = statusline
    return statusline
end

-- Inactive statusline
function M.statusline_inactive()
    local filename = get_file_info()
    local git_branch = get_git_branch()

    local inactive_line = string.format('%%#StatusLineNC# %s', filename)

    -- Show git branch in inactive windows too, but dimmed
    if git_branch then
        inactive_line = inactive_line .. string.format('  %s', git_branch)
    end

    return inactive_line
end

function M.show_message(msg, timeout)
    cache.message_timeout = timeout or 1500
    set_message(msg)
end

function M.silent_write()
    local filename = vim.fn.expand('%:t')
    local success, err = pcall(vim.cmd, 'silent! write')

    if success then
        local lines_after = vim.fn.line('$')
        local bytes = vim.fn.getfsize(vim.fn.expand('%'))
        M.show_message(string.format('"%s" %dL, %dB written', filename, lines_after, bytes))
    else
        M.show_message('Write failed: ' .. (err or 'unknown error'))
    end
end

-- Public function to manually refresh colors
function M.refresh_colors()
    refresh_colors()
end

-- Public function to handle colorscheme plugin loading
function M.handle_colorscheme_loaded()
    -- Wait a bit for the colorscheme to fully load
    vim.schedule(function()
        vim.defer_fn(function()
            refresh_colors()
        end, 200) -- Wait 200ms for colorscheme to fully load
    end)
end

function M.setup(opts)
    opts = opts or {}

    -- Override default colors if provided
    if opts.colors then
        colors = vim.tbl_extend('force', colors, opts.colors)
    end

    -- Override message timeout if provided
    if opts.message_timeout then
        cache.message_timeout = opts.message_timeout
    end

    setup_highlights()
    setup_message_capture()

    -- Handle initial colorscheme if already loaded
    if vim.g.colors_name then
        handle_external_colorscheme()
    end

    -- Set up LSP progress handler
    _G.lsp_progress = {}
    vim.lsp.handlers["$/progress"] = function(_, result, ctx)
        local client_id = ctx.client_id
        local client = vim.lsp.get_client_by_id(client_id)
        local value = result.value
        if not value or not client then
            return
        end

        local token = result.token
        local client_name = client.name

        if value.kind == "begin" then
            _G.lsp_progress[token] = {
                client = client_name,
                title = value.title or "",
                message = value.message or "",
                percentage = value.percentage or 0,
            }
        elseif value.kind == "report" then
            if _G.lsp_progress[token] then
                _G.lsp_progress[token].message = value.message or _G.lsp_progress[token].message
                _G.lsp_progress[token].percentage = value.percentage or _G.lsp_progress[token].percentage
            end
        elseif value.kind == "end" then
            _G.lsp_progress[token] = nil
        end

        cache.last_update = 0 -- Force statusline update
        vim.schedule(function()
            vim.cmd("redrawstatus")
        end)
    end

    -- Set cmdheight to 0 and disable various message options
    cache.original_cmdheight = vim.o.cmdheight
    vim.o.cmdheight = 0
    vim.o.shortmess = vim.o.shortmess .. 'F' -- Don't show file info when editing

    -- Set statusline
    vim.o.statusline = '%{%v:lua.require("statusline").statusline()%}'

    -- Set up autocommands for inactive windows
    local group = vim.api.nvim_create_augroup('StatusLine', { clear = true })

    vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
        group = group,
        callback = function()
            vim.wo.statusline = '%{%v:lua.require("statusline").statusline()%}'
        end
    })

    vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave' }, {
        group = group,
        callback = function()
            vim.wo.statusline = '%{%v:lua.require("statusline").statusline_inactive()%}'
        end
    })

    -- Refresh on diagnostics change
    vim.api.nvim_create_autocmd('DiagnosticChanged', {
        group = group,
        callback = function()
            cache.last_update = 0
            vim.cmd('redrawstatus')
        end
    })

    -- Refresh colors when colorscheme changes
    vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = function()
            -- Try to handle external colorschemes first
            if not handle_external_colorscheme() then
                -- For built-in colorschemes, refresh immediately
                refresh_colors()
            end
        end
    })

    -- Handle colorscheme plugins that use User events
    vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = { 'ColorScheme', 'Colorscheme', 'ThemeChanged' },
        callback = function()
            M.handle_colorscheme_loaded()
        end
    })

    -- Override write command to prevent default message
    vim.api.nvim_create_user_command('W', M.silent_write, {})
    vim.keymap.set('n', '<C-s>', M.silent_write, { desc = 'Write file silently', silent = true })

    -- Cleanup on exit
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            restore_message_capture()
            vim.o.cmdheight = cache.original_cmdheight

            -- Clear LSP progress
            _G.lsp_progress = {}

            if cache.git_timer and not cache.git_timer:is_closing() then
                cache.git_timer:close()
            end
            if cache.message_timer and not cache.message_timer:is_closing() then
                cache.message_timer:close()
            end
        end
    })
end

return M
