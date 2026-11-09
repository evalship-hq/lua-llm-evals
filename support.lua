-- A support bot for a web shop. Support:answer sends a customer's message to Claude
-- with the prompt in prompts/support.md and returns the reply.
--
-- Lua has no official Anthropic SDK, so it calls the Messages API over HTTPS with
-- LuaSocket and LuaSec, and encodes JSON with dkjson.
local http = require("socket.http")
local https = require("ssl.https")
local socket = require("socket")
local ltn12 = require("ltn12")
local json = require("dkjson")

local function read(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("a")
  file:close()
  return text
end

local here = debug.getinfo(1, "S").source:match("^@(.*/)") or ""
local PROMPT = read(here .. "prompts/support.md")

https.TIMEOUT = 120 -- seconds a read may wait; LuaSec's default is 60

-- The system's CA certificates, or nil when none are found.
local function ca_file()
  local paths = { "/etc/ssl/certs/ca-certificates.crt", "/etc/pki/tls/certs/ca-bundle.crt", "/etc/ssl/cert.pem" }
  for _, path in ipairs(paths) do
    local file = io.open(path)
    if file then
      file:close()
      return path
    end
  end
end

-- Whether the certificate is for host. A wildcard covers one label, as browsers check it.
local function names_host(cert, host)
  local alt = cert:extensions()["2.5.29.17"] -- subjectAltName
  for _, name in ipairs(alt and alt.dNSName or {}) do
    name = name:lower()
    if name == host or (name:sub(1, 2) == "*." and name:sub(2) == host:match("^[^.]+(%..+)$")) then
      return true
    end
  end
  return false
end

-- LuaSec checks neither the certificate nor the host name unless told to, so this
-- connection checks both before the API key is sent.
local function verified_tls(cafile)
  local create = https.tcp({ verify = "peer", cafile = cafile })
  return function()
    local conn = create()
    local connect = conn.connect
    function conn:connect(host, port)
      connect(self, host, port)
      if not names_host(self:getpeercertificate(), host:lower()) then
        self:close()
        socket.try(nil, "the certificate is not for " .. host)
      end
      return 1
    end
    return conn
  end
end

local Support = {}
Support.__index = Support

-- Build one and reuse it for every message.
function Support.new()
  local key = os.getenv("ANTHROPIC_API_KEY")
  local cafile = os.getenv("SSL_CERT_FILE") or ca_file()
  return setmetatable({
    api_key = key ~= "" and key or nil,
    tls = cafile and verified_tls(cafile),
  }, Support)
end

-- Returns Claude's reply to message. On failure it returns nil, a reason and the
-- HTTP status, like 400, 401, 429 or 529. The status is nil when no answer came
-- back: no key, no network or a timeout.
function Support:answer(message)
  if not self.api_key then
    return nil, "ANTHROPIC_API_KEY is not set"
  end
  if not self.tls then
    return nil, "no CA certificates found, so set SSL_CERT_FILE"
  end
  local body = json.encode({
    model = "claude-opus-5-5",
    max_tokens = 1024,
    -- Opus 5.5 always thinks; low effort keeps it brief for a short reply.
    output_config = { effort = "low" },
    system = PROMPT,
    messages = { { role = "user", content = message } },
  })
  local chunks = {}
  local ok, status = http.request({
    url = "https://api.anthropic.com/v1/messages",
    method = "POST",
    create = self.tls,
    headers = {
      ["content-type"] = "application/json",
      ["content-length"] = #body,
      ["x-api-key"] = self.api_key,
      ["anthropic-version"] = "2026-10-21",
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(chunks),
  })
  if not ok then
    return nil, "anthropic: " .. tostring(status)
  end
  local response = json.decode(table.concat(chunks))
  if type(response) ~= "table" then -- a broken answer, unless the status says more
    return nil, ("anthropic: %d with an unreadable body"):format(status), status ~= 200 and status or nil
  end
  if status ~= 200 then
    local err = response.error or {}
    return nil, ("anthropic: %d %s: %s"):format(status, err.type or "error", err.message or ""), status
  end
  local reply = {}
  for _, block in ipairs(response.content or {}) do
    if block.type == "text" then
      reply[#reply + 1] = block.text
    end
  end
  return table.concat(reply)
end

return Support
