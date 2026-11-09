rockspec_format = "3.0"
package = "lua-llm-evals"
version = "dev-1"
source = {
  url = "git+https://github.com/evalship-hq/lua-llm-evals.git",
}
description = {
  summary = "A Lua support bot whose AI call is tested on every pull request with tinyeval.",
  homepage = "https://github.com/evalship-hq/lua-llm-evals",
  license = "MIT",
}
dependencies = {
  "lua >= 5.4",
  "luasocket >= 3.1",
  "luasec >= 1.3",
  "dkjson >= 2.8",
}
build = {
  type = "builtin",
  modules = {
    support = "support.lua",
  },
}
