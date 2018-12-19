local helpers = require "spec.helpers"
local inspect = require "inspect"

for _, strategy in helpers.each_strategy() do
  describe("Plugin: hello-world-header [" .. strategy .. "]", function()

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
        "hello-world-header"
      })

      service = bp.services:insert {
        name = "test-service",
        protocol = "https",
        port = 443,
        host = "eatmore.cricket"
      }

      bp.routes:insert({
        paths        = { "/html" },
        service = { id = service.id }
      })

      bp.plugins:insert({
        name = "hello-world-header",
        service = { id = service.id }
      })

      -- start Kong with your testing Kong configuration (defined in "spec.helpers")
      assert(helpers.start_kong({
        database = strategy,
        plugins  = "bundled,hello-world-header",
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
      it("should respond with the X-Hello-World header", function()
        local res = proxy_client:get("/html")

        -- ngx.log(ngx.WARN, "Response headers: " .. inspect(res.headers))
        -- os.execute("sleep " .. tonumber(300))

        assert.res_status(200, res)
        assert.is.truthy(res.headers["x-hello-world"])
        assert.is.truthy(string.match(res.headers["x-hello-world"], "Today is .+"))
      end)
    end)
  end)
end
