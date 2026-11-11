-- tinyeval worker: evals/support.sh starts it with `worker ... lua evals/worker.lua`.
local tinyeval = require("tinyeval") -- first, so the app's output stays off the replies
local support = require("support").new() -- once per worker, not once per test case

tinyeval.worker(function(input)
  local answer, err, status = support:answer(input)
  -- Not the app's fault, so tinyeval counts it as couldn't run instead of failed.
  -- No status means no answer came back: no key, no network or a timeout.
  if not answer and (not status or status == 401 or status == 429 or status >= 500) then
    error(tinyeval.CouldntRun(err))
  end
  -- A 400 or 404 comes from the request the app built, so the helper makes nil and err the reply, which fails.
  return answer, err
end)
