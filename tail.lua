--[[
    Tail returns a table to the caller with one line per index. For this
    reason, the caller should be mindful of his/her line sizes and number of
    lines being requested with respect to the potential memory requirements
    of such a table.
    
    To do:  if possible, optimize to return a stream of blocks to the caller
            to better avoid potential memory bottlenecks.
--]]

local function get_block(file, offset, BUFSIZE)
  file:seek("set", offset)
  local block = file:read(BUFSIZE)
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
      break
    end 
    lines_remaining = lines_remaining - newline_count
    initial_offset = initial_offset - BUFSIZE
  end

  if str_offset then
    local offset = initial_offset + str_offset
    return offset
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

local function tailer(file_to_read, n_lines)
  local file = assert(io.open(file_to_read, "r"))
  local size = file:seek("end")
  local offset = get_offset(file, n_lines, size)
  local num_of_bytes = size - offset
  file:seek("set", offset)
  local lines = file:read(num_of_bytes)
  file:close()
  local lines_table = {}

  for line in lines:gmatch('[^\n]+') do
    lines_table[#lines_table + 1] = line
  end
  return lines_table
end

--[[
    So as not to clutter the global namespace, we only export the one
    function necessary to use this package. All other functions are private.
--]]

local functions = {}
tail = functions
tail = {
  tail = tailer
  }