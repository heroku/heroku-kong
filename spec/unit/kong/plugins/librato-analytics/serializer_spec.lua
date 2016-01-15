require "kong.tools.ngx_stub"

local serializer = require "kong.plugins.librato-analytics.serializer"

describe("kong.plugins.librato-analytics.serializer", function()

  local mock_ngx = {
    ctx = {
      api = {
        name = "test-api"
      },
      kong_processing_access = 50,
      kong_processing_header_filter = 75,
      kong_processing_body_filter = 100
    },
    var = {
      request_time = 5,
      upstream_response_time = 1,
      request_length = 1024,
      bytes_sent = 2048
    },
    req = {
      start_time = function() return 1452906061.055 end
    }
  }

  it("should return a table", function()
    assert.is.equal("table", type(serializer))
  end)

  describe("#serialize", function()
    local return_value

    before_each(function() 
      return_value = serializer.serialize(mock_ngx)
    end)

    it("is a function", function()
      assert.is.equal("function", type(serializer.serialize))
    end)

    it("returns a table", function()
      assert.is.equal("table", type(return_value))
    end)

    -- Iterate through the returned gauges
    for i = 1,5,1 do
      it("has a source based on the API name", function()
        assert.is.equal("kong-test-api", return_value[i].source)
      end)

      it("has a measure time based on the request start time", function()
        assert.is.equal(1452906061, return_value[i].measure_time)
      end)
    end

    it("includes request-size", function()
      assert.is.equal("request-size", return_value[1].name)
    end)

    it("captures request-size value", function()
      assert.is.equal(1024, return_value[1].value)
    end)

    it("includes upstream-latency", function()
      assert.is.equal("upstream-latency", return_value[2].name)
    end)

    it("captures upstream-latency value", function()
      assert.is.equal(1000, return_value[2].value)
    end)

    it("includes kong-latency", function()
      assert.is.equal("kong-latency", return_value[3].name)
    end)

    it("captures kong-latency value", function()
      assert.is.equal(225, return_value[3].value)
    end)

    it("includes response-size", function()
      assert.is.equal("response-size", return_value[4].name)
    end)

    it("captures response-size value", function()
      assert.is.equal(2048, return_value[4].value)
    end)

    it("includes response-latency", function()
      assert.is.equal("response-latency", return_value[5].name)
    end)

    it("captures response-latency value", function()
      assert.is.equal(5000, return_value[5].value)
    end)

  end)

end)
