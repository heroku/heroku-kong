local helpers = require "spec.helpers"
local json = require "cjson"

describe("ndfd-xml-as-json plugin", function()

  local proxy_client
  local admin_client

  setup(function()
    local api = assert(helpers.dao.apis:insert {
      name         = "ndfd-api",
      uris         = "/ndfd",
      upstream_url = "http://mockbin.com/bin/c209eeb6-af56-44bf-95b5-62b9486ae800"
    })
    assert(helpers.dao.plugins:insert {
      name         = "ndfd-xml-as-json",
      api_id       = api.id
    })

    -- start Kong with your testing Kong configuration (defined in "spec.helpers")
    assert(helpers.start_kong({
      custom_plugins = "ndfd-xml-as-json"
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
    it("should respond", function()
      local res = assert(proxy_client:send {
        method = "GET",
        path   = "/ndfd",
        body = {
          latitude = 38.99,
          longitude = -77.01
        },
        headers = {
          ["Content-Type"] = "application/json"
        },

      })

      local body = assert.res_status(200, res)
      local data = json.decode(body)
      assert.is.equal('temperature', data.name)
    end)
  end)
end)
