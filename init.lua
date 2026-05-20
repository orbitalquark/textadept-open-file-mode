-- Copyright 2019-2026 Mitchell.

--- A Textadept module that extends the editor's `ui.command_entry` with a mode that can open
-- files relative to the current file or directory.
-- Tab-completion is available.
--
-- This is an alternative to Textadept's default File Open dialog.
--
-- Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
-- *modules/* directory, and then putting the following in your *~/.textadept/init.lua*:
--
-- ```lua
-- keys['alt+o'] = require('open_file_mode')
-- ```
--
-- Replace "alt+o" with the key you want to bind the function to. You can also create a menu
-- item with that function.
-- @module ui.command_entry.open_file

-- LuaFormatter off
local xpm16 = {folder=UI~='terminal' and [[/* XPM */ static char *folder[] = { /* columns rows colors chars-per-pixel */ "16 16 7 1 ", "  c None", ". c #A89453", "X c #AD9856", "o c #BCA55D", "O c #D5BA69", "+ c #EDD075", "@ c #FBDC7C", /* pixels */ "                ", "                ", "......          ", ".@@@@+X         ", ".OOOOOo........ ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", ".@@@@@@@@@@@@@. ", "............... ", "                ", "                " };]] or ' ', file=UI~='terminal' and [[/* XPM */ static char *file[] = { /* columns rows colors chars-per-pixel */ "16 16 9 1 ", "  c None", ". c #6D6D6D", "X c #717171", "o c #727272", "O c gray45", "+ c #8D8D8D", "@ c #A9A9A9", "# c #AAAAAA", "$ c #ECECEC", /* pixels */ " .........X     ", " .$$$$$$$+#X    ", " .$$$$$$$+$#X   ", " .$$$$$$$+$$#X  ", " .$$$$$$$++++.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .$$$$$$$$$$$.  ", " .............  ", "                " };]] or ' '}
local xpm32 = {folder=UI~='terminal' and [[/* XPM */ static char *folder[] = { /* columns rows colors chars-per-pixel */ "32 32 10 1 ", "  c None", ". c #A89453", "X c #AA9655", "o c #AC9755", "O c #B29B57", "+ c #B6A05A", "@ c #C8AF63", "# c #EDD075", "$ c #F7D97A", "% c #FBDC7C", /* pixels */ "                                ", "                                ", "                                ", "                                ", "............                    ", ".............                   ", "..%%%%%%%%%@..                  ", "..%%%%%%%%%$+.O                 ", "..%%%%%%%%%%#.................  ", "..............................  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..%%%%%%%%%%%%%%%%%%%%%%%%%%..  ", "..............................  ", "..............................  ", "                                ", "                                ", "                                ", "                                " };]] or ' ', file=UI~='terminal' and [[/* XPM */ static char *file[] = { /* columns rows colors chars-per-pixel */ "32 32 6 1 ", "  c None", ". c #6D6D6D", "X c #8D8D8D", "o c #A9A9A9", "O c gray67", "+ c #ECECEC", /* pixels */ "  ...................           ", "  ....................          ", "  ..++++++++++++++XXO..         ", "  ..++++++++++++++XX+O..        ", "  ..++++++++++++++XX++O..       ", "  ..++++++++++++++XX+++O..      ", "  ..++++++++++++++XX++++O..     ", "  ..++++++++++++++XX+++++O..    ", "  ..++++++++++++++XXXXXXXX..    ", "  ..++++++++++++++XXXXXXXX..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..++++++++++++++++++++++..    ", "  ..........................    ", "  ..........................    ", "                                ", "                                " };]] or ' '}
-- LuaFormatter on

--- Returns a normalized version of the given path that `lfs` can work with.
-- @param path String path to normalize.
local function normalize_path(path)
	if OS ~= 'windows' then path = path:gsub('^~', os.getenv('HOME')) end

	-- Convert relative path into an absolute one.
	if not path:find('^%a?:?[/\\]') then
		path = (buffer.filename or lfs.currentdir() .. '/'):match('^.+[/\\]') .. path
	end

	-- Normalizes Windows paths by replacing '/' with '\\'.
	-- Also transform Cygwin-style '/c/' root directories into 'C:\'.
	if OS == 'windows' then
		path = path:gsub('^/([%a])/', function(ch) return string.format('%s:\\', string.upper(ch)) end)
			:gsub('/', '\\')
	end

	return path
end

--- The current list of files in the autocompletion list.
local files = {}

--- Show an autocompletion list for the current filename in the command entry.
-- If a list is already active, try to autocomplete the current item if it has a unique prefix.
local function complete()
	-- Try to autocomplete a uniquely-prefixed item (like in bash).
	if ui.command_entry:auto_c_active() then
		local prefix = ui.command_entry:text_range(ui.command_entry:auto_c_pos_start(),
			ui.command_entry.current_pos)
		local count = 0
		for _, file in ipairs(files) do if file:find(prefix, 1, true) == 1 then count = count + 1 end end
		if count == 1 then ui.command_entry:auto_c_complete() end
		return
	end

	-- Show an autocomplete list.
	files = {} -- clear

	-- Determine the current directory and file prefix (if any).
	local dir, part = normalize_path(ui.command_entry:get_text()):match('^(.-)\\?([^/\\]*)$')
	if OS == 'windows' and dir:find('^%a:$') then dir = dir .. '\\' end -- C: --> C:\
	if lfs.attributes(dir, 'mode') ~= 'directory' then return end

	-- Iterate over directory, finding file matches.
	for path in lfs.walk(dir, nil, 0, true) do
		local filename = path:match('[^/\\]+[/\\]?$')
		local xpm = ui.command_entry._xpm[filename:find('[/\\]$') and 'folder' or 'file']
		if filename:find(part, 1, true) == 1 then
			files[#files + 1] = string.format('%s%s%d', filename,
				string.char(ui.command_entry.auto_c_type_separator), xpm)
		end
	end

	-- Show the autocompletion list.
	table.sort(files)
	ui.command_entry.auto_c_separator = string.byte(';')
	ui.command_entry.auto_c_order = buffer.ORDER_PRESORTED
	ui.command_entry:auto_c_show(#part, table.concat(files, ';'))
end

--- Opens the command entry in a mode that can open files relative to the current file or
-- directory.
-- Tab-completion is available, and on Windows, Cygwin-style '/c/' root directories are supported.
-- If no file is ultimately specified, the user is prompted with Textadept's default File
-- Open dialog.
-- @function _G.ui.command_entry.open_file
local function open_file()
	ui.command_entry.run(_L['Open file:'], function(file)
		if file ~= '' then file = normalize_path(file) end
		io.open_file(file ~= '' and file or nil)
	end, {['\t'] = complete})
end
rawset(ui.command_entry, 'open_file', open_file)

-- Add autocompletion list images for files and folders.
-- Make use of the undocumented `ui.command_entry._xpm` table.
events.connect(events.INITIALIZED, function()
	if is_hidpi() then ui.command_entry.auto_c_image_scale = 200 end
	local image_type = 1 -- no need to use M.new_image_type() since this is a special view
	for _ in pairs(ui.command_entry._xpm) do image_type = image_type + 1 end
	for name, xpm in pairs(not is_hidpi() and xpm16 or xpm32) do
		ui.command_entry:register_image(image_type, xpm)
		ui.command_entry._xpm[name], image_type = image_type, image_type + 1
	end
end)

return open_file
