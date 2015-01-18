--[[
    Tail writes the lesser of n lines or all lines in the passed file to
    io.stdout in 8K blocks.
    
    Usage: tail("/path/to/file", last_n_lines)
    
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
      error("Unexpected EOF; possible file truncation.")
  end
  return block
end

local function newline_counter(buffer, lines_remaining)
  local newlines_encountered = 0 
  for i = #buffer, 1, -1 do
    if string.sub(buffer, i, i) == "\n" then
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
    So as not to clutter the global namespace, we only expose the tail()
    function to the caller. All other functions are local.
--]]
function tail(file_to_read, n_lines)
  if type(file_to_read) ~= 'string' or #file_to_read < 1 then
    error("non-empty string expected.", 2)
  end
  if type(n_lines) ~= 'number' or n_lines < 1 or n_lines % 1 ~= 0 then
    error("positive integer expected.", 2)
  end
  
  local file = assert(io.open(file_to_read, "r"))
  local size = file:seek("end")
  local offset = get_offset(file, n_lines, size)
  
  --[[
      The file may have been appended since we first opened it. Therefore, we
      specify the number of bytes to be read.
  --]]
  local to_be_read = size - offset
  local buffer = ''
  local BUFSIZE = 2^13
  file:seek("set", offset)

  --[[
      To avoid potential memory bottlenecks in output, we read 8K blocks and
      write them to stdout. Redirection of stdout, if desired, is left to the
      caller.
  --]]
  while to_be_read >= BUFSIZE do
    buffer = file:read(BUFSIZE)
    if not buffer or #buffer ~= BUFSIZE then
      error("Unexpected EOF; possible file truncation.")
    end
    io.stdout:write(buffer)
    to_be_read = to_be_read - BUFSIZE
  end
  
  if to_be_read > 0 then
    BUFSIZE = to_be_read
    buffer = file:read(BUFSIZE)
    if not buffer or #buffer ~= BUFSIZE then
      error("Unexpected EOF; possible file truncation.")
    end
    io.stdout:write(buffer)
  end
  
  file:close()
  return
end