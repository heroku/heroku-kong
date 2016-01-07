local handler = require "kong.plugins.hello-world-header.handler"

describe("kong.plugins.hello-world-header.handler", function()

  it("should return a table", function()
    assert.is.equal("table", type(handler))
  end)

  it("should provide a header filter function", function()
    assert.is.equal("function", type(handler.header_filter))
  end)

end)
