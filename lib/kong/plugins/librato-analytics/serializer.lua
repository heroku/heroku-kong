local _M = {}

-- Return Librato metric measurements
-- See: http://dev.librato.com/v1/post/metrics
function _M.serialize(ngx)
  local source = "kong-"..ngx.ctx.api.name
  local measure_time = math.floor(ngx.req.start_time())

  local total_latency = (ngx.var.request_time or 0) * 1000
  local upstream_latency = (ngx.var.upstream_response_time or 0) * 1000
  local kong_latency = (ngx.ctx.kong_processing_access or 0) +
    (ngx.ctx.kong_processing_header_filter or 0) +
    (ngx.ctx.kong_processing_body_filter or 0)

  local gauges = {
    {
      name          = "request-size",
      source        = source,
      measure_time  = measure_time,
      value         = math.floor(ngx.var.request_length)
    },
    {
      name          = "upstream-latency",
      source        = source,
      measure_time  = measure_time,
      value         = math.floor(upstream_latency)
    },
    {
      name          = "kong-latency",
      source        = source,
      measure_time  = measure_time,
      value         = math.floor(kong_latency)
    },
    {
      name          = "response-size",
      source        = source,
      measure_time  = measure_time,
      value         = math.floor(ngx.var.bytes_sent)
    },
    {
      name          = "response-latency",
      source        = source,
      measure_time  = measure_time,
      value         = math.floor(total_latency)
    }
  }
  
  return gauges
end

return _M
