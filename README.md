# LuaTail

An attempt to duplicate the functionality of GNU coreutils "tail" utility with Lua

Usage: tail("/path/to/file", number_of_lines_you_want, [stream])

number_of_lines should be a positive integer.
stream, if given, should be a boolean.

If stream = false, tail() will return a table with one line per numeric index.
Caller should be mindful of the potential memory requirements of such a table.

This is my first Lua programming attempt, and I welcome your constructive criticism.
