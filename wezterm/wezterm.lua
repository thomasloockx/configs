local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- Format tab title to show: "[dir] process"
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane

  -- Get last directory component from cwd
  local dir_name = ""
  local cwd = pane.current_working_dir
  if cwd then
    local path = cwd.file_path or tostring(cwd)
    dir_name = path:match("([^/\\]+)[/\\]?$") or path
  end

  -- Get process name (strip path and .exe)
  local proc_name = ""
  local proc = pane.foreground_process_name
  if proc and proc ~= "" then
    proc_name = proc:match("([^/\\]+)$") or proc
    proc_name = proc_name:gsub("%.exe$", "")
  end

  -- Build title: index: [dir] process
  local idx = tab.tab_index + 1
  if dir_name ~= "" and proc_name ~= "" then
    return string.format(" %d: %s | %s ", idx, dir_name, proc_name)
  elseif dir_name ~= "" then
    return string.format(" %d: %s ", idx, dir_name)
  elseif proc_name ~= "" then
    return string.format(" %d: %s ", idx, proc_name)
  else
    return string.format(" %d ", idx)
  end
end)

config.color_scheme = 'Solarized Darcula (Gogh)'
config.font = wezterm.font('JetBrains Mono', {weight='Regular', style='Normal'})

local gitbash = {"C:\\Program Files\\Git\\bin\\bash.exe", "-i", "-l"}
config.default_prog = gitbash

-- Launch menu items for different terminal types
config.launch_menu = {
    {
        label = 'Git Bash (Default)',
        args = {"C:\\Program Files\\Git\\bin\\bash.exe", "-i", "-l"},
    },
    {
        label = 'PowerShell',
        args = {'powershell.exe', '-NoLogo'},
    },
    {
        label = 'Command Prompt',
        args = {'cmd.exe'},
    },
    {
        label = 'WSL',
        args = {'wsl.exe'},
    },
    {
        label = 'Developer Powershell for VS 2022',
        args = {
          'powershell.exe',
          '-noe',
          '-c',
          '& "C:/Program Files/Microsoft Visual Studio/2022/Community/Common7/Tools/Launch-VsDevShell.ps1"'
        },
    }
}

-- Configure like tmux.
config.leader = { key = 'a', mods = 'CTRL' }
config.keys = {
	{
	    key    = "\"",
		mods   = "LEADER|SHIFT",
	    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }
	},
	{
	    key    = "|",
		mods   = "LEADER|SHIFT",
	    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' }
	},
	{
		key = "n",
		mods = "LEADER",
		action = wezterm.action.ActivateTabRelative(1),
	},
	{
		key = "p",
		mods = "LEADER",
		action = wezterm.action.ActivateTabRelative(-1),
	},
  	{ 
		key = 'c', 
		mods = "LEADER",
		action = wezterm.action.SpawnTab 'DefaultDomain',
	},
  	{
		key = "x",
		mods = "LEADER",
		action = wezterm.action.CloseCurrentPane { confirm = false },
  	},
  	{
		key = "j",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection 'Down',
  	},
  	{
		key = "k",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection 'Up',
  	},
  	{
		key = "h",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection 'Left',
  	},
  	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection 'Right',
  	},
    {
        key = "Space",
        mods = "LEADER",
        action = wezterm.action.RotatePanes "Clockwise"
    },
    {
        key = "t",
        mods = "CTRL|SHIFT",
        action = wezterm.action.ShowLauncherArgs {
            flags = 'FUZZY|TABS|LAUNCH_MENU_ITEMS',
        },
    },
}

for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(i - 1),
  })
end

return config
