require "kong.tools.ngx_stub"
ngx.config = {}
ngx.config.ngx_lua_version = "9.9.9"

local json = require "cjson"
local utils = require "kong.tools.utils"
local Buffer = require "kong.plugins.librato-analytics.buffer"

local MB = 1024 * 1024
local METRIC_STUB = {hello = "world"}
local STUB_SIZE = string.len(json.encode(METRIC_STUB))
local COMMA_SIZE = string.len(",")
local JSON_ARR_SIZE = string.len("[]")
local CONF_STUB = {
  batch_size = 100,
  delay = 2,
  host = "",
  port = "",
  path = "",
  max_sending_queue_size = 10,
  username = "test-user",
  token = "test-token"
}

-- Adapted from Mashape's analytics plugin
-- See: https://github.com/Mashape/kong/blob/master/spec/plugins/mashape-analytics/buffer_spec.lua
describe("Buffer", function()

  it("should create a new buffer", function()
    local buffer = Buffer.new(CONF_STUB)
    assert.truthy(buffer)
    assert.equal(CONF_STUB.batch_size, buffer.max_entries)
    assert.equal(CONF_STUB.delay, buffer.auto_flush_delay)
    assert.equal("", buffer.host)
    assert.equal("", buffer.port)
    assert.equal("", buffer.path)
  end)

  it("should generate authorization", function()
    local buffer = Buffer.new(CONF_STUB)
    -- Test value from `ngx` stub
    assert.equal("Basic base64_test-user:test-token", buffer.authorization)
  end)

  describe(":add()", function()
    it("should be possible to add an metric to it", function()
      local buffer = Buffer.new(CONF_STUB)
      buffer:add(METRIC_STUB)
      assert.equal(1, #buffer.entries)
    end)
  end)
  describe(":flush()", function()
    it("should have emptied the current buffer and added a payload to be sent", function()
      local buffer = Buffer.new(CONF_STUB)
      buffer:add(METRIC_STUB)
      buffer:flush()
      buffer:add(METRIC_STUB)
      assert.equal(1, #buffer.entries)
      assert.equal(1, #buffer.sending_queue)
      assert.equal("table", type(buffer.sending_queue[1]))
      assert.equal("string", type(buffer.sending_queue[1].payload))
    end)
  end)
  describe("batch_size flushing", function()
    it("should call :flush() when reaching its n entries limit", function()
      local buffer = Buffer.new(CONF_STUB)

      spy.on(buffer, "flush")
      finally(function()
        buffer.flush:revert()
      end)

      for i = 1, 100 do
        buffer:add(METRIC_STUB)
      end

      assert.spy(buffer.flush).was_not.called()
      -- One more to go over the limit
      buffer:add(METRIC_STUB)
      assert.spy(buffer.flush).was.called()
      assert.equal(1, #buffer.entries)
    end)
  end)
end)