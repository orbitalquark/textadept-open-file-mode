# Open File Mode
---

A Textadept module that extends the editor's `ui.command_entry` with a mode that can open
files relative to the current file or directory.
Tab-completion is available.

This is an alternative to Textadept's default File Open dialog.

Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
*modules/* directory, and then putting the following in your *~/.textadept/init.lua*:

	keys['alt+o'] = require('open_file_mode')

Replace "alt+o" with the key you want to bind the function to. You can also create a menu
item with that function.

## Functions defined by `ui.command_entry.open_file`

<a id="_G.ui.command_entry.open_file"></a>
### `_G.ui.command_entry.open_file`()

Opens the command entry in a mode that can open files relative to the current file or
directory.
Tab-completion is available, and on Windows, Cygwin-style '/c/' root directories are supported.
If no file is ultimately specified, the user is prompted with Textadept's default File
Open dialog.


---
