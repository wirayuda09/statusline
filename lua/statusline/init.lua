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

-- Color definitions
local colors = {
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
    message = '#a6adc8'
}

-- Mode mappings
local modes = {
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

-- Initialize highlight groups
local function setup_highlights()
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
        StatusLineMessage = { bg = colors.bg, fg = colors.message, italic = true }
    }

    for name, opts in pairs(highlights) do
        vim.api.nvim_set_hl(0, name, opts)
    end
end

-- Message handling
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

    -- Immediate redraw
    vim.cmd('redrawstatus')

    -- Set timer to clear message
    if msg ~= '' then
        cache.message_timer = vim.loop.new_timer()
        cache.message_timer:start(cache.message_timeout, 0, vim.schedule_wrap(function()
            cache.last_message = ''
            cache.last_update = 0
            vim.cmd('redrawstatus')
            if cache.message_timer then
                cache.message_timer:close()
                cache.message_timer = nil
            end
        end))
    end
end

-- Override vim's echo functions to capture messages
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
        -- Call original for empty/whitespace messages
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

-- Get git branch with caching
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

-- Get LSP diagnostics
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

-- Get cursor position
local function get_position()
    local line = vim.fn.line('.')
    local col = vim.fn.col('.')
    local total = vim.fn.line('$')
    return string.format('%d:%d %d%%%%', line, col, math.floor(line / total * 100))
end

-- Build left section (mode + file + git branch)
local function build_left()
    local mode_name, mode_color = get_mode()
    local file_info = get_file_info()
    local git_branch = get_git_branch()

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

    return left_section
end

-- Build center section (messages)


function M.clean_message(msg)
    msg = msg
        :gsub("[\226\128\147]", "-") -- replace en dash (–) or em dash (—)
        :gsub("…", "...") -- replace ellipsis with 3 dots
        :gsub("•", "-") -- replace bullet with dash
        :gsub("↪", "->") -- arrow right
        :gsub("[\194-\244].", "") -- fallback: remove unprintable UTF-8 (optional)

    return msg
end

local function truncate(msg, max_width)
    if #msg <= max_width then return msg end
    return msg:sub(1, max_width - 1) .. '…'
end

local function build_center()
    if cache.last_message ~= '' then
        local total_width = vim.o.columns
        local max_center_width = math.floor(total_width * 0.33)
        local msg = truncate(cache.last_message, max_center_width)
        return string.format('%%#StatusLineMessage# %s', msg)
    end
    return ''
end


-- Build right section
local function build_right()
    local diagnostics = get_diagnostics()
    local position = get_position()
    local filetype = vim.bo.filetype ~= '' and vim.bo.filetype or 'text'

    local diag_parts = {}
    if diagnostics.error > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineError# %d', diagnostics.error))
    end
    if diagnostics.warn > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineWarn# %d', diagnostics.warn))
    end
    if diagnostics.info > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineInfo# %d', diagnostics.info))
    end
    if diagnostics.hint > 0 then
        table.insert(diag_parts, string.format('%%#StatusLineHint# %d', diagnostics.hint))
    end

    local diag_str = table.concat(diag_parts, '')
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
    local center = build_center()
    local right = build_right()

    -- If there's a message, show it in center, otherwise normal layout
    local statusline
    if cache.last_message ~= '' then
        statusline = string.format('%s%%=%s%%=%s', left, center, right)
    else
        statusline = string.format('%s%%=%s', left, right)
    end

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

-- Public API for showing messages
function M.show_message(msg, timeout)
    cache.message_timeout = timeout or 3000
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

    -- Override write command to prevent default message
    vim.api.nvim_create_user_command('W', M.silent_write, {})
    vim.keymap.set('n', '<C-s>', M.silent_write, { desc = 'Write file silently', silent = true })

    -- Cleanup on exit
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            restore_message_capture()
            vim.o.cmdheight = cache.original_cmdheight

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
