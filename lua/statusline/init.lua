local M = {}

local cache = {
    -- Component caches with timestamps
    mode = { value = '', time = 0, ttl = 50 },
    file = { value = '', time = 0, ttl = 1000 },
    git = { value = '', time = 0, ttl = 5000 },
    diagnostics = { value = '', time = 0, ttl = 500 },
    position = { value = '', time = 0, ttl = 100 },
    lsp = { value = '', time = 0, ttl = 200 },

    lsp_progress = {}, -- Add this line
    -- Global cache
    statusline = '',
    last_update = 0,
    update_threshold = 50, -- Minimum ms between updates

    -- Timers
    git_timer = nil,
    message_timer = nil,

    -- Message system
    message = '',
    message_timeout = 3000,
}

-- Modern color palette with semantic meanings
local colors = {
    -- Base colors
    bg = '#1e1e2e',
    fg = '#cdd6f4',
    surface = '#313244',
    overlay = '#6c7086',

    -- Accent colors
    blue = '#89b4fa',
    green = '#a6e3a1',
    yellow = '#f9e2af',
    red = '#f38ba8',
    purple = '#cba6f7',
    pink = '#f5c2e7',
    teal = '#94e2d5',
    orange = '#fab387',

    -- Semantic colors
    error = '#f38ba8',
    warn = '#fab387',
    info = '#89dceb',
    hint = '#94e2d5',

    -- Git colors
    git_add = '#a6e3a1',
    git_change = '#f9e2af',
    git_delete = '#f38ba8',
}

-- Modern icons with fallbacks
local icons = {
    -- File type icons
    file = '󰈙',
    folder = '󰉋',
    modified = '●',
    readonly = '󰌾',

    -- Git icons
    git_branch = '󰊢',
    git_add = '󰐕',
    git_change = '󰛿',
    git_delete = '󰍶',

    -- Diagnostic icons
    error = '󰅚',
    warn = '󰀪',
    info = '󰋽',
    hint = '󰌶',

    -- Mode icons
    normal = '󰊠',
    insert = '󰏫',
    visual = '󰈈',
    command = '󰘳',
    replace = '󰛔',

    -- Separators
    left_sep = '',
    right_sep = '',
    thin_left = '│',
    thin_right = '│',

    -- Position icons
    line = '󰍒',
    column = '󰗕',
    percent = '󰏰',
    lsp = '󰒋',
    progress = '󰔟',
}
-- Add the LSP progress handler back
local function setup_lsp_progress()
    vim.lsp.handlers["$/progress"] = function(_, result, ctx)
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        if not client or not result.value then return end

        local token = result.token
        local value = result.value

        if value.kind == "begin" then
            cache.lsp_progress[token] = {
                client = client.name,
                title = value.title or "",
                message = value.message or "",
                percentage = value.percentage or 0,
            }
        elseif value.kind == "report" then
            if cache.lsp_progress[token] then
                cache.lsp_progress[token].message = value.message or cache.lsp_progress[token].message
                cache.lsp_progress[token].percentage = value.percentage or cache.lsp_progress[token].percentage
            end
        elseif value.kind == "end" then
            cache.lsp_progress[token] = nil
        end

        -- Force LSP cache update
        cache.lsp.time = 0
        vim.schedule(function()
            vim.cmd('redrawstatus')
        end)
    end
end
-- Dynamic color extraction from current colorscheme
local function extract_colorscheme_colors()
    local function get_hl_color(group, attr)
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group })
        if ok and hl and hl[attr] then
            return string.format('#%06x', hl[attr])
        end
        return nil
    end

    -- Try to extract colors from common highlight groups
    local extracted = {}

    -- Base colors
    extracted.bg = get_hl_color('StatusLine', 'bg') or colors.bg
    extracted.fg = get_hl_color('StatusLine', 'fg') or colors.fg
    extracted.surface = get_hl_color('Pmenu', 'bg') or colors.surface

    -- Semantic colors
    extracted.blue = get_hl_color('Function', 'fg') or colors.blue
    extracted.green = get_hl_color('String', 'fg') or colors.green
    extracted.yellow = get_hl_color('Type', 'fg') or colors.yellow
    extracted.red = get_hl_color('Error', 'fg') or colors.red
    extracted.purple = get_hl_color('Statement', 'fg') or colors.purple

    -- Merge with defaults
    colors = vim.tbl_extend('force', colors, extracted)
end

-- Modern highlight groups with gradients and effects
local function setup_highlights()
    extract_colorscheme_colors()

    local highlights = {
        -- Base statusline
        StatusLine = { bg = colors.bg, fg = colors.fg },
        StatusLineNC = { bg = colors.bg, fg = colors.overlay },
        StatusLineLSP = { bg = colors.bg, fg = colors.teal },
        StatusLineProgress = { bg = colors.bg, fg = colors.purple, italic = true },

        -- Modern mode indicators with background gradients
        StatusLineModeNormal = {
            bg = colors.blue,
            fg = colors.bg,
            bold = true
        },
        StatusLineModeInsert = {
            bg = colors.green,
            fg = colors.bg,
            bold = true
        },
        StatusLineModeVisual = {
            bg = colors.purple,
            fg = colors.bg,
            bold = true
        },
        StatusLineModeCommand = {
            bg = colors.yellow,
            fg = colors.bg,
            bold = true
        },
        StatusLineModeReplace = {
            bg = colors.red,
            fg = colors.bg,
            bold = true
        },

        -- Separator gradients
        StatusLineSepLeft = { bg = colors.bg, fg = colors.blue },
        StatusLineSepRight = { bg = colors.bg, fg = colors.surface },

        -- Component highlights
        StatusLineFile = { bg = colors.surface, fg = colors.fg, bold = true },
        StatusLineGit = { bg = colors.bg, fg = colors.orange, italic = true },

        -- Diagnostic highlights with modern styling
        StatusLineError = { bg = colors.bg, fg = colors.error, bold = true },
        StatusLineWarn = { bg = colors.bg, fg = colors.warn },
        StatusLineInfo = { bg = colors.bg, fg = colors.info },
        StatusLineHint = { bg = colors.bg, fg = colors.hint },

        -- Position indicator
        StatusLinePosition = { bg = colors.surface, fg = colors.fg },

        -- Message system
        StatusLineMessage = { bg = colors.bg, fg = colors.yellow, italic = true },

        -- Special effects
        StatusLineAccent = { bg = colors.bg, fg = colors.pink },
        StatusLineSubtle = { bg = colors.bg, fg = colors.overlay },
    }

    for name, opts in pairs(highlights) do
        vim.api.nvim_set_hl(0, name, opts)
    end
end

-- Performance-optimized cache getter
local function get_cached(key, generator, force_update)
    local now = vim.uv and vim.uv.now() or vim.loop.now()
    local cache_entry = cache[key]

    if not cache_entry then
        cache[key] = { value = '', time = 0, ttl = 1000 }
        cache_entry = cache[key]
    end

    if force_update or (now - cache_entry.time) > cache_entry.ttl then
        local result = generator()
        cache_entry.value = result or ''
        cache_entry.time = now
    end

    return cache_entry.value
end

local function get_lsp_info()
    return get_cached('lsp', function()
        -- Only show progress if available, don't show client names
        if next(cache.lsp_progress) then
            local progress_parts = {}
            for _, progress in pairs(cache.lsp_progress) do
                local part = progress.title
                if progress.percentage and progress.percentage > 0 then
                    part = part .. string.format(' %d%%', progress.percentage)
                end
                table.insert(progress_parts, part)
            end

            if #progress_parts > 0 then
                return string.format('%%#StatusLineProgress#%s %s',
                    icons.progress, table.concat(progress_parts, ' '))
            end
        end

        return ''
    end)
end



-- Modern mode detection with icons
local function get_mode_info()
    return get_cached('mode', function()
        local mode = vim.api.nvim_get_mode().mode
        local mode_map = {
            ['n'] = { 'NORMAL', 'StatusLineModeNormal', icons.normal },
            ['i'] = { 'INSERT', 'StatusLineModeInsert', icons.insert },
            ['v'] = { 'VISUAL', 'StatusLineModeVisual', icons.visual },
            ['V'] = { 'V-LINE', 'StatusLineModeVisual', icons.visual },
            [''] = { 'V-BLOCK', 'StatusLineModeVisual', icons.visual },
            ['c'] = { 'COMMAND', 'StatusLineModeCommand', icons.command },
            ['R'] = { 'REPLACE', 'StatusLineModeReplace', icons.replace },
            ['t'] = { 'TERMINAL', 'StatusLineModeCommand', icons.command },
        }

        local info = mode_map[mode] or { 'UNKNOWN', 'StatusLineModeNormal', icons.normal }
        return string.format('%%#%s# %s %s %%#StatusLineSepLeft#%s',
            info[2], info[3], info[1], icons.right_sep)
    end)
end

-- Enhanced file info with modern styling
local function get_file_info()
    return get_cached('file', function()
        local buf = vim.api.nvim_get_current_buf()
        local filename = vim.api.nvim_buf_get_name(buf)

        if filename == '' then
            return string.format('%%#StatusLineFile# %s [No Name] %%#StatusLineSepRight#%s',
                icons.file, icons.right_sep)
        end

        filename = vim.fn.fnamemodify(filename, ':t')
        local modified = vim.bo[buf].modified and icons.modified or ''
        local readonly = vim.bo[buf].readonly and icons.readonly or ''

        return string.format('%%#StatusLineFile# %s %s %s%s %%#StatusLineSepRight#%s',
            icons.file, filename, modified, readonly, icons.right_sep)
    end)
end

-- Git integration with async updates
local function get_git_info()
    return get_cached('git', function()
        if not cache.git_timer then
            local timer = vim.uv and vim.uv.new_timer() or vim.loop.new_timer()
            cache.git_timer = timer
            timer:start(0, 5000, vim.schedule_wrap(function()
                -- Use job for git command
                local job_id = vim.fn.jobstart({ 'git', 'branch', '--show-current' }, {
                    cwd = vim.fn.getcwd(),
                    stdout_buffered = true,
                    on_stdout = function(_, data)
                        if data and data[1] and data[1] ~= '' then
                            local branch = vim.trim(data[1])
                            cache.git.value = string.format('%%#StatusLineGit# %s %s',
                                icons.git_branch, branch)
                            cache.git.time = vim.uv and vim.uv.now() or vim.loop.now()
                            vim.schedule(function()
                                vim.cmd('redrawstatus')
                            end)
                        end
                    end,
                    on_exit = function(_, code)
                        if code ~= 0 then
                            cache.git.value = ''
                        end
                    end
                })

                -- Timeout the job after 1 second
                vim.defer_fn(function()
                    if job_id > 0 then
                        vim.fn.jobstop(job_id)
                    end
                end, 1000)
            end))
        end
        return cache.git.value or ''
    end)
end

-- Modern diagnostic display
local function get_diagnostics()
    return get_cached('diagnostics', function()
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

        local parts = {}
        if counts.error > 0 then
            table.insert(parts, string.format('%%#StatusLineError#%s %d', icons.error, counts.error))
        end
        if counts.warn > 0 then
            table.insert(parts, string.format('%%#StatusLineWarn#%s %d', icons.warn, counts.warn))
        end
        if counts.info > 0 then
            table.insert(parts, string.format('%%#StatusLineInfo#%s %d', icons.info, counts.info))
        end
        if counts.hint > 0 then
            table.insert(parts, string.format('%%#StatusLineHint#%s %d', icons.hint, counts.hint))
        end

        return table.concat(parts, ' ')
    end)
end

-- Enhanced position indicator
local function get_position()
    return get_cached('position', function()
        local line = vim.fn.line('.')
        local col = vim.fn.col('.')
        local total = vim.fn.line('$')
        local percent = math.floor(line / total * 100)

        return string.format('%%#StatusLineSepLeft#%s%%#StatusLinePosition# %s %d:%d %s %d%%%% ',
            icons.left_sep, icons.line, line, col, icons.percent, percent)
    end)
end

-- Message system with auto-clear
local function set_message(msg, timeout)
    timeout = timeout or cache.message_timeout
    cache.message = msg or ''

    if cache.message_timer then
        cache.message_timer:close()
        cache.message_timer = nil
    end

    if cache.message ~= '' then
        local timer = vim.uv and vim.uv.new_timer() or vim.loop.new_timer()
        cache.message_timer = timer
        timer:start(timeout, 0, vim.schedule_wrap(function()
            cache.message = ''
            vim.cmd('redrawstatus')
            if cache.message_timer then
                cache.message_timer:close()
                cache.message_timer = nil
            end
        end))
    end

    vim.cmd('redrawstatus')
end

-- Main statusline builder with smart layout
function M.statusline()
    local now = vim.uv and vim.uv.now() or vim.loop.now()

    -- Performance throttling
    if now - cache.last_update < cache.update_threshold then
        return cache.statusline
    end

    cache.last_update = now

    -- Build components (removed LSP info)
    local mode = get_mode_info() or ''
    local file = get_file_info() or ''
    local git = get_git_info() or ''
    local diagnostics = get_diagnostics() or ''
    local position = get_position() or ''
    local lsp = get_lsp_info() or ''

    -- Message display
    local message = ''
    if cache.message ~= '' then
        local max_width = math.floor(vim.o.columns * 0.3)
        local truncated = #cache.message > max_width and
            cache.message:sub(1, max_width - 1) .. '…' or cache.message
        message = string.format(' %%#StatusLineMessage#💬 %s', truncated)
    end

    -- Smart layout based on available width
    local left = mode .. file .. git .. lsp .. message -- Include lsp here
    local right = diagnostics .. position              -- Build final statusline
    cache.statusline = string.format('%s%%=%s', left, right)

    return cache.statusline
end

-- Minimalist inactive statusline
function M.statusline_inactive()
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
    if filename == '' then filename = '[No Name]' end

    return string.format('%%#StatusLineNC# %s %s', icons.file, filename)
end

-- Public API
function M.show_message(msg, timeout)
    set_message(msg, timeout)
end

function M.refresh_colors()
    setup_highlights()
    -- Force all cache refresh
    for key in pairs(cache) do
        if type(cache[key]) == 'table' and cache[key].time then
            cache[key].time = 0
        end
    end
    vim.cmd('redrawstatus')
end

-- Setup function
function M.setup(opts)
    opts = opts or {}

    -- Apply user customizations
    if opts.colors then
        colors = vim.tbl_extend('force', colors, opts.colors)
    end

    if opts.icons then
        icons = vim.tbl_extend('force', icons, opts.icons)
    end

    if opts.message_timeout then
        cache.message_timeout = opts.message_timeout
    end

    if opts.update_threshold then
        cache.update_threshold = opts.update_threshold
    end

    -- Initialize
    setup_highlights()
    setup_lsp_progress()

    -- Set statusline with proper module reference
    local module_name = debug.getinfo(1, 'S').source:match('@.*lua/(.*)%.lua$') or 'statusline'
    vim.o.statusline = string.format('%%{%%v:lua.require("%s").statusline()%%}', module_name)
    vim.o.cmdheight = 0

    -- Auto commands
    local group = vim.api.nvim_create_augroup('ModernStatusLine', { clear = true })

    -- Window focus management
    vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
        group = group,
        callback = function()
            vim.wo.statusline = string.format('%%{%%v:lua.require("%s").statusline()%%}', module_name)
        end
    })

    vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave' }, {
        group = group,
        callback = function()
            vim.wo.statusline = string.format('%%{%%v:lua.require("%s").statusline_inactive()%%}', module_name)
        end
    })

    -- Smart refresh triggers
    vim.api.nvim_create_autocmd({ 'DiagnosticChanged' }, {
        group = group,
        callback = function()
            cache.diagnostics.time = 0
            vim.cmd('redrawstatus')
        end
    })

    -- Colorscheme changes
    vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = function()
            vim.defer_fn(M.refresh_colors, 100)
        end
    })

    -- Performance optimization
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group,
        callback = function()
            cache.position.time = 0
        end
    })

    -- Cleanup
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            if cache.git_timer and not cache.git_timer:is_closing() then
                cache.git_timer:close()
            end
            if cache.message_timer and not cache.message_timer:is_closing() then
                cache.message_timer:close()
            end
        end
    })

    -- Show welcome message
    vim.defer_fn(function()
        M.show_message('󰄀 Modern statusline loaded!', 2000)
    end, 500)
end

return M
