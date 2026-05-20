-- Copyright 2020-2026 Mitchell. See LICENSE.

local open_file_mode = require('open_file_mode')

teardown(function() test.type('esc') end)

test('open_file_mode should open the command entry, tab-complete, and open filenames', function()
	local file = 'file.txt'
	local subdir = 'subdir'
	local subfile = 'subfile.txt'
	local dir<close> = test.tmpdir({file, [subdir] = {subfile}}, true)

	local auto_c_show = test.stub()
	local _<close> = test.mock(ui.command_entry, 'auto_c_show', auto_c_show)

	open_file_mode()
	test.wait(function() return ui.command_entry.active end)

	test.type('\t')
	local args = auto_c_show.args
	test.type(subdir .. '/\t' .. subfile .. '\n')

	test.assert_equal(auto_c_show.called, 2)
	local first_completions = {}
	for item in args[3]:gmatch('[^;]+') do
		first_completions[#first_completions + 1] = item:gsub('%p%d$', '') -- strip xpm
	end
	table.sort(first_completions)
	test.assert_equal(first_completions, {'file.txt', 'subdir' .. (OS ~= 'windows' and '/' or '\\')})
	local second_completions = auto_c_show.args[3]:gsub('%p%d$', '') -- strip xpm
	test.assert_equal(second_completions, subfile)
	test.assert_equal(buffer.filename, dir / (subdir .. '/' .. subfile))
end)

test('open_file_mode should select unique items after typing and pressing Tab again', function()
	local file = 'file.txt'
	local file2 = 'file2.txt'
	local _<close> = test.tmpdir({file, file2}, true)

	local auto_c_show = test.stub()
	local _<close> = test.mock(ui.command_entry, 'auto_c_show', auto_c_show)
	local auto_c_active = function() return auto_c_show.called end
	local _<close> = test.mock(ui.command_entry, 'auto_c_active', auto_c_active)
	local auto_c_pos_start = test.stub(1)
	local _<close> = test.mock(ui.command_entry, 'auto_c_pos_start', auto_c_pos_start)
	local auto_c_complete = test.stub()
	local _<close> = test.mock(ui.command_entry, 'auto_c_complete', auto_c_complete)

	open_file_mode()
	test.wait(function() return ui.command_entry.active end)
	test.type('\t')
	test.type('file2\t')

	test.assert_equal(auto_c_complete.called, true)
end)

test('open_file_mode should expand ~', function()
	local auto_c_show = test.stub()
	local _<close> = test.mock(ui.command_entry, 'auto_c_show', auto_c_show)

	open_file_mode()
	test.wait(function() return ui.command_entry.active end)
	test.type('~/\t')

	local items = auto_c_show.args[3]
	local path = os.getenv('HOME') .. '/' .. items:match('^[^;]+'):gsub('%p%d$', '') -- strip xpm
	test.assert(lfs.attributes(path), "'%s' does not exist", path)
end)
if OS == 'windows' then skip('~ is meaningless on Windows') end

test('open_file_mode should support Cygwin-style paths on Windows', function()
	local file = 'file.txt'
	local _<close> = test.mock(_G, 'OS', 'windows')
	local open_file = test.stub()
	local _<close> = test.mock(io, 'open_file', open_file)

	open_file_mode()
	test.wait(function() return ui.command_entry.active end)
	test.type('/c/' .. file .. '\n')

	test.assert_equal(open_file.args[1], 'C:\\' .. file)
end)
