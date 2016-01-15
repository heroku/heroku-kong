local MashapePlugin = require "kong.plugins.mashape-analytics.handler"
local LibratoAnalytics = MashapePlugin:extend()
local Serializer = require "kong.plugins.librato-analytics.serializer"
local Buffer = require "kong.plugins.librato-analytics.buffer"

local METRIC_BUFFERS = {} -- buffers per-api

function LibratoAnalytics:new()
  LibratoAnalytics.super.new(self, "librato-analytics")
end

function LibratoAnalytics:log(conf)
  -- Use the super-super class to avoid calling Mashape-specific code
  LibratoAnalytics.super.super.log(self)

  local api_id = ngx.ctx.api.id

  -- Create the metric buffer if not existing for this API
  if not METRIC_BUFFERS[api_id] then
    METRIC_BUFFERS[api_id] = Buffer.new(conf)
  end

  local buffer = METRIC_BUFFERS[api_id]

  -- Creating the metric
  local metric = Serializer.serialize(ngx)
  if metric then
    -- Simply add metric to the buffer, it will decide if it is necessary to flush itself
    buffer:add(metric)
  end
end

return LibratoAnalytics
