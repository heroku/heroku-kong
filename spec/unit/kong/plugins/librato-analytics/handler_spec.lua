require "kong.tools.ngx_stub"
ngx.config = {}
ngx.config.ngx_lua_version = "9.9.9"

local handler = require "kong.plugins.librato-analytics.handler"

describe("kong.plugins.librato-analytics.handler", function()

  it("should return a table", function()
    assert.is.equal("table", type(handler))
  end)

  describe("#new", function()
    it("is a function", function()
      assert.is.equal("function", type(handler.new))
    end)
  end)

  describe("#log", function()
    it("is a function", function()
      assert.is.equal("function", type(handler.log))
    end)
  end)

end)
