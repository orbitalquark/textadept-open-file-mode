-- Copyright 2020-2024 Mitchell. See LICENSE.

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
	for item in args[3]:gmatch('[^;]+') do first_completions[#first_completions + 1] = item end
	table.sort(first_completions)
	test.assert_equal(first_completions, {'file.txt', 'subdir' .. (not WIN32 and '/' or '\\')})
	local second_completions = auto_c_show.args[3]
	test.assert_equal(second_completions, subfile)
	test.assert_equal(buffer.filename, dir / (subdir .. '/' .. subfile))
end)
if QT and LINUX then skip('there are focus issues') end
