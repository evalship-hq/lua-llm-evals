-- tinyeval worker: evals/support.sh starts it with `worker ... lua evals/worker.lua`.
-- It reads each input up to a NUL byte on stdin, and writes the reply and a NUL byte.
-- Nothing else may write to stdout, as it carries the replies.
local Support = require("support")

local support = Support.new() -- once per worker, not once per test case

local function reply(input)
  local answer, err, status = support:answer(input)
  if answer then
    return answer
  end
  -- Not the app's fault, so tinyeval counts it as couldn't run instead of failed.
  -- No status means no answer came back: no key, no network or a timeout.
  if not status or status == 401 or status == 429 or status >= 500 then
    return "#tinyeval couldnt_run " .. err:gsub("\n", " ") .. "\n"
  end
  -- A 400 or 404 comes from the request the app built: grade it as the reply.
  return "error: " .. err
end

-- One byte at a time, as a longer read waits until it has every byte it asked for.
local input = {}
for byte in io.stdin:lines(1) do
  if byte == "\0" then
    io.stdout:write(reply(table.concat(input)), "\0")
    io.stdout:flush()
    input = {}
  else
    input[#input + 1] = byte
  end
end
