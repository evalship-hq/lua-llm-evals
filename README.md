# LLM evals for Lua

A Lua support bot whose AI call is tested on every pull request with [tinyeval](https://tinyeval.com).

## Run it

Clone the repo, or use it as a template. You need Lua 5.4 or later, LuaRocks, and OpenSSL's headers for LuaSec. Then:

```sh
luarocks --tree lua_modules install --only-deps lua-llm-evals-dev-1.rockspec   # nothing goes global
export ANTHROPIC_API_KEY=sk-ant-...
./tinyeval
```

```
support
  ✓ refund after the window 4.2s
  ✓ missing package 3.9s
  ✓ refund inside the window 4.0s

All 3 evals passed (eval-results.json)
```

## What's here

- `support.lua`: the support bot. `Support:answer` sends a message to Claude and returns the reply. Lua has no official Anthropic SDK, so it calls the Messages API with LuaSocket, LuaSec and dkjson.
- `prompts/support.md`: the bot's system prompt.
- `evals/worker.lua`: the tinyeval worker. It builds `Support` once, then answers each test case.
- `evals/support.sh`: three test cases and the checks on their replies. Its worker line points Lua at the rocks in `lua_modules`.
- `lua-llm-evals-dev-1.rockspec`: the rocks the bot needs.
- `tinyeval`: the eval runner, one bash file.
- `.github/workflows/evals.yml`: runs the evals on pull requests and on pushes to main.

## Use it for your app

1. Replace `answer` with your AI call, and keep the worker so your app starts once, not once per test case.
2. Write your test cases in `evals/`. The [check lines](https://github.com/evalship-hq/tinyeval#writing-evals) are `contains`, `matches`, `json`, `judge` and a few more.
3. In an OpenResty app or a Neovim plugin, keep the AI call in a plain Lua module that doesn't need the host's APIs, like `ngx` or `vim`. The worker can then run it with the standalone interpreter.

The worker reports a missing key, 401, 429, 5xx, timeouts and network errors as couldn't run, so an outage doesn't show as a failed eval. Keep that split when you swap in your own client.

LuaSec checks neither certificates nor host names unless told to. `support.lua` checks both, against the system's CA certificates or the file in `SSL_CERT_FILE`. Keep that if you reuse its HTTP code.

## In CI

Add `ANTHROPIC_API_KEY` under **Settings** > **Secrets and variables** > **Actions**. The judge uses the same key.

The workflow installs Lua 5.4 and LuaRocks, caches `lua_modules` and checks that the bot loads. Then it runs each test case 3 times. A test case passes when at least 2 of the 3 runs pass. A failing eval fails the job, so you can require it before merging. The results go up as the `eval-results` artifact, also when evals fail.

Without the secret, the workflow skips the evals and stays green. Pull requests from forks get no secrets, so their evals skip too.

## Compare pull requests with main

A fresh CI run has nothing to compare with. [evalship](https://evalship.com) reads `eval-results.json`, compares each pull request with main, tells flaky evals from real drops and comments on the pull request.

## License

MIT, see [LICENSE](LICENSE).
