local helpers = require "spec.helpers"

describe("hello-world-header plugin", function()

  local proxy_client
  local admin_client

  setup(function()
    local api = assert(helpers.dao.apis:insert {
      name         = "fixture-api",
      uris         = "/html",
      upstream_url = "http://httpbin.org"
    })
    assert(helpers.dao.plugins:insert {
      name         = "hello-world-header",
      api_id       = api.id
    })

    -- start Kong with your testing Kong configuration (defined in "spec.helpers")
    assert(helpers.start_kong({
      custom_plugins = "hello-world-header"
    }))

    admin_client = helpers.admin_client()
  end)

  teardown(function()
    if admin_client then
      admin_client:close()
    end

    helpers.stop_kong()
  end)

  before_each(function()
    proxy_client = helpers.proxy_client()
  end)

  after_each(function()
    if proxy_client then
      proxy_client:close()
    end
  end)

  describe("API responses", function()
    it("should respond with the X-Hello-World header", function()
      local res = assert(proxy_client:send {
        method = "GET",
        path   = "/html"
      })

      assert.res_status(200, res)
      assert.is.truthy(res.headers["x-hello-world"])
      assert.is.truthy(string.match(res.headers["x-hello-world"], "Today is .+"))
    end)
  end)
end)
