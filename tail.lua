--[[
    Tail writes the lesser of n lines or all lines in the passed file to
    io.stdout in 8K blocks or, optionally, returns a table.

    Usage: tail.tail("/path/to/file", last_n_lines, [stream])

    Optional boolean stream parameter specifies whether a stream to stdout is
    desired. If false, a table of lines is returned with one line per index.
    If stream parameter is omitted, true is assumed.

    Files which are appended during runtime are accommodated without raising an
    error; we define our tail such that it returns n lines from the end of the
    file at the time when it was called.

    Files which are truncated during runtime raise an error indicating that we
    encountered an unexpected EOF.
--]]

local function get_block(file, offset, BUFSIZE)
  file:seek("set", offset)
  local block = file:read(BUFSIZE)

  if not block or #block ~= BUFSIZE then
      file:close()
      error("Unexpected EOF; possible file truncation.")
  end

  return block
end

local function newline_counter(buffer, lines_remaining)
  local newlines_encountered = 0

  for i = #buffer, 1, -1 do
    if buffer:sub(i, i) == "\n" then
      newlines_encountered = newlines_encountered + 1
      if newlines_encountered > lines_remaining then
        return newlines_encountered, i
      end
    end
  end

  return newlines_encountered, false
end

local function get_offset(file_to_read, n_lines, filesize)
  local BUFSIZE = 2^13
  local initial_offset = 0

  if filesize <= BUFSIZE then
    BUFSIZE = filesize
  else
    initial_offset = filesize - BUFSIZE
  end

  local newline_count = 0
  local lines_remaining = n_lines
  local buffer = ''
  local str_offset = false

-- This loop is skipped in the edge case of filesize <= 8K (BUFSIZE).
  while initial_offset > 0 do
    buffer = get_block(file_to_read, initial_offset, BUFSIZE)
    newline_count, str_offset = newline_counter(buffer, lines_remaining)

    if str_offset then
      local offset = initial_offset + str_offset
      return offset
    end

    lines_remaining = lines_remaining - newline_count
    initial_offset = initial_offset - BUFSIZE
  end

  if initial_offset < 0 then
    BUFSIZE = BUFSIZE + initial_offset
    buffer = get_block(file_to_read, 0, BUFSIZE)
    newlines_found, str_offset = newline_counter(buffer, lines_remaining)

    if str_offset then
      local offset = initial_offset + str_offset
      return offset
    end

    return 0
  end

--[[
    This section only executes in the edge cases of filesize <= 8K or our
    initial_offset reassignment equals 0.
--]]

  buffer = get_block(file_to_read, 0, BUFSIZE)
  newlines_found, str_offset = newline_counter(buffer, lines_remaining)

  if str_offset then
    return str_offset
  end

  return 0
end

--[[
    To avoid potential memory bottlenecks in output, we read 8K blocks and
    write them to stdout. Redirection of the stdout stream, if desired,
    is left to the caller.
--]]

local function linestream(BUFSIZE, file, to_be_read)
  local buffer = ''

  while to_be_read >= BUFSIZE do
    buffer = file:read(BUFSIZE)

    if not buffer or #buffer ~= BUFSIZE then
      file:close()
      error("Unexpected EOF; possible file truncation.")
    end

    io.stdout:write(buffer)
    to_be_read = to_be_read - BUFSIZE
  end

  if to_be_read > 0 then
    BUFSIZE = to_be_read
    buffer = file:read(BUFSIZE)

    if not buffer or #buffer ~= BUFSIZE then
      file:close()
      error("Unexpected EOF; possible file truncation.")
    end

    io.stdout:write(buffer)
  end

  file:close()
  return
end

--[[
    If stream = false, build and return a table of lines, one line per index.
    To save on memory during the process of building our table, we read in 8K
    blocks and split them up into the constituent lines. However, this does not
    mean that we have eliminated all need to care about memory when calling the
    tail() function with stream = false. In particular, the caller should try
    to be reasonably aware of the potential size of the table being returned.
    The most relevant factors are average line size, the number of lines being
    requested, file size, and total amount of memory available to the Lua
    interpreter.
--]]

local function linetable(BUFSIZE, file, to_be_read)
  local buffer = ''
  local lines = {}
  local line_frag = ''
  local expected_size = 0

  while to_be_read >= BUFSIZE do
    if line_frag then
      buffer = line_frag .. file:read(BUFSIZE)
      expected_size = BUFSIZE + #line_frag
    else
      buffer = file:read(BUFSIZE)
      expected_size = BUFSIZE
    end

    if not buffer or #buffer ~= expected_size then
      file:close()
      error("Unexpected EOF; possible file truncation.")
    end

    for line in buffer:gmatch('[^\n]+') do
      lines[#lines + 1] = line
    end

    if buffer:sub(-1) ~= '\n' and to_be_read ~= BUFSIZE then
      line_frag = lines[#lines]
      lines[#lines] = nil
    else
      line_frag = nil
    end

    to_be_read = to_be_read - BUFSIZE
  end

  if to_be_read > 0 then
    BUFSIZE = to_be_read

    if line_frag then
      buffer = line_frag .. file:read(BUFSIZE)
      expected_size = BUFSIZE + #line_frag
    else
      buffer = file:read(BUFSIZE)
      expected_size = BUFSIZE
    end

    if not buffer or #buffer ~= expected_size then
      file:close()
      error("Unexpected EOF; possible file truncation.")
    end

    for line in buffer:gmatch('[^\n]+') do
      lines[#lines + 1] = line
    end
  end
  
  file:close()
  return lines
end

--[[
    So as not to pollute the global namespace when called with require(), we
    only export the tail() function when we return the namespace table.
--]]

local namespace = {}

function namespace.tail(file_to_read, n_lines, stream)
  if type(file_to_read) ~= 'string' or #file_to_read < 1 then
    error("non-empty string expected.")
  end

  if type(n_lines) ~= 'number' or n_lines < 1 or n_lines % 1 ~= 0 then
    error("positive integer expected.")
  end

  if stream and type(stream) ~= 'boolean' then
    error("expected boolean or nil.")
  end

  local file = assert(io.open(file_to_read, "r"))
  local size = file:seek("end")
  local offset = get_offset(file, n_lines, size)

--[[
    The file may have been appended since we first opened it. Therefore, we
    specify the number of bytes to be read.
--]]

  local to_be_read = size - offset
  local BUFSIZE = 2^13
  file:seek("set", offset)

  if stream == true or stream == nil then return linestream(BUFSIZE, file, to_be_read) end
  return linetable(BUFSIZE, file, to_be_read)
end

return namespace
