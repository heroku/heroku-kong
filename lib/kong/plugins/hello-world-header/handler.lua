local BasePlugin = require "kong.plugins.base_plugin"
local HelloWorld = BasePlugin:extend()

local date = require "date"

function HelloWorld:new()
  HelloWorld.super.new(self, "hello-world-header")
end

function HelloWorld:header_filter(config)
  HelloWorld.super.header_filter(self)

  local now = date()
  ngx.header["X-Hello-World"] = "Today is "..now:fmt("%F")..". "..(os.getenv('HELLO_WORLD_MESSAGE') or "")
end

return HelloWorld
