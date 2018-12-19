local helpers = require "spec.helpers"
local json = require "cjson"

for _, strategy in helpers.each_strategy() do
  describe("Plugin: ndfd-xml-as-json [" .. strategy .. "]", function()

    local bp
    local db
    local proxy_client
    local service

    lazy_setup(function()
      bp, db = helpers.get_db_utils(strategy, {
        "plugins",
        "routes",
        "services",
      }, {
        "ndfd-xml-as-json"
      })

      service = bp.services:insert {
        name = "test-service",
        protocol = "https",
        port = 443,
        host = "mockbin.com",
        path = "/bin/c209eeb6-af56-44bf-95b5-62b9486ae800"
      }

      bp.routes:insert({
        paths = { "/ndfd" },
        service = { id = service.id }
      })

      bp.plugins:insert({
        name = "ndfd-xml-as-json",
        service = { id = service.id }
      })

      -- start Kong with your testing Kong configuration (defined in "spec.helpers")
      assert(helpers.start_kong({
        database = strategy,
        plugins  = "bundled,ndfd-xml-as-json",
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
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
        local res = proxy_client:get("/ndfd", {
          body = {
            latitude = 38.99,
            longitude = -77.01
          },
          headers = {
            ["Content-Type"] = "application/json"
          },
        })

        local body = assert.res_status(200, res)

        -- ngx.log(ngx.WARN, "Response body: " .. body)
        -- os.execute("sleep " .. tonumber(300))

        local data = json.decode(body)
        assert.is.equal('temperature', data.name)
      end)
    end)
  end)
end
