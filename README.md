# LuaTail
Implementation of tail utility in Lua

Usage: tail.tail("/path/to/file/you/want/to/tail", number_of_lines_you_want)

Notes: Caller should try to be mindful of the potential sizes of his/her lines
and number of lines being requested as tail will return a table of the 
lesser of n lines or all lines in the file.
