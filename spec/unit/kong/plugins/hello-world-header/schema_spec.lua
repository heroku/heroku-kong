local schema = require "kong.plugins.hello-world-header.schema"

describe("kong.plugins.hello-world-header.schema", function()

  it("should return a table", function()
    assert.is.equal("table", type(schema))
  end)

  it("is a global plugin", function()
    assert.is.True(schema.no_consumer)
  end)

  it("defines the configuration fields", function()
    assert.is.equal("table", type(schema.fields))
  end)

end)
