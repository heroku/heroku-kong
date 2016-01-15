local http_client = require "kong.tools.http_client"
local spec_helper = require "spec.spec_helpers"
local json = require "cjson"
local serpent = require "serpent"

describe("librato-analytics plugin", function()
  setup(function()
    spec_helper.prepare_db()

    -- mockbin is used to provide a prerecorded response
    spec_helper.insert_fixtures {
      api = {
        {
          name = "measure-me",
          request_path = "/measure-me",
          upstream_url = "http://mockbin.com/bin/dabf0b5d-bdd3-4389-be94-c4eb5f59a8d7"
        }
      },
      plugin = {
        {
          name = "librato-analytics",
          config = {
            username = "test-user",
            token = "test-token"
          },
          __api = 1
        }
      }
    }

    spec_helper.start_kong()
  end)

  teardown(function()
    spec_helper.stop_kong()
  end)

  describe("API responses", function()
    local BASE_URL = spec_helper.PROXY_URL.."/measure-me"

    it("should respond", function()
      -- local req_headers = {}
      -- req_headers["content-type"] = "application/json"
      -- local data = '{"latitude":38.99,"longitude":-77.01}'
      -- local response, status, headers = http_client.post(BASE_URL, data, req_headers)
      -- local response_json = json.decode(response)
      -- assert.is.equal('temperature', response_json.name)
      -- assert.is.equal(200, status)
    end)
  end)
end)
