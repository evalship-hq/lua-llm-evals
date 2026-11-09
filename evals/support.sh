# Evals for the support bot in support.lua. The worker loads it once and answers every test case.
# luarocks path points Lua at the rocks in lua_modules, for the Lua version they were built for.
worker env LUA_PATH="$(luarocks --tree lua_modules path --lr-path);;" LUA_CPATH="$(luarocks --tree lua_modules path --lr-cpath);;" lua evals/worker.lua

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  target support.lua#answer
  matches "30[- ]day"   # "30 days" and "30-day window" are both right
  judge "Says a refund isn't possible anymore, politely"

test_case "missing package" "My package never showed up and I'm getting really annoyed."
  target support.lua#answer
  matches "order (number|id|#)"
  judge "Asks for the order number before promising a refund or resend"

test_case "refund inside the window" "My shoes arrived last week and they don't fit. Can I send them back?"
  target support.lua#answer
  judge "Says they can return them for a refund"
