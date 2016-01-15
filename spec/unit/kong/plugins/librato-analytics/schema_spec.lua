local schema = require "kong.plugins.librato-analytics.schema"

describe("kong.plugins.librato-analytics.schema", function()

  it("should return a table", function()
    assert.is.equal("table", type(schema))
  end)

  describe(".fields", function()

    it("is a table", function()
      assert.is.equal("table", type(schema.fields))
    end)

    it("a Librato username is optional", function()
      assert.is.False(schema.fields.username.required)
    end)

    it("a Librato token is optional", function()
      assert.is.False(schema.fields.token.required)
    end)

    it("has the default host for Librato", function()
      assert.is.equal("metrics-api.librato.com", schema.fields.host.default)
    end)

    it("has the default path for Librato", function()
      assert.is.equal("/v1/metrics", schema.fields.path.default)
    end)
  end)

end)
