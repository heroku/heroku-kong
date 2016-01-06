local BasePlugin = require "kong.plugins.base_plugin"
local HelloWorld = BasePlugin:extend()

function HelloWorld:header_filter(config)
  HelloWorld.super.header_filter(self)

  ngx.header["x-hello-world"] = "The 8th Wonder"
end
