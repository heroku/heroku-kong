local http_client = require "kong.tools.http_client"
local spec_helper = require "spec.spec_helpers"

describe("hello-world-header plugin", function()
  setup(function()
    spec_helper.prepare_db()

    spec_helper.insert_fixtures {
      api = {
        {name = "fixture-api", request_path = "/status", upstream_url = "http://mockbin.com"}
      },
      plugin = {
        {name = "hello-world-header", __api = 1},
      }
    }

    spec_helper.start_kong()
  end)

  teardown(function()
    spec_helper.stop_kong()
  end)

  describe("API responses", function()
    local BASE_URL = spec_helper.PROXY_URL.."/status/200"

    it("should respond with the X-Hello-World header", function()
      local response, status, headers = http_client.get(BASE_URL)
      assert.is.equal(200, status)
      assert.is.truthy(string.match(headers["x-hello-world"], "Today is .+"))
    end)
  end)
end)
