-- Librato Metric buffer module
--
-- Adapted from Mashape's analytics plugin
-- See: https://github.com/Mashape/kong/tree/master/kong/plugins/mashape-analytics
--
-- This module contains a buffer of metric objects. When the buffer reaches `config.batch_size` or the `config.delay` seconds, it is eventually converted to a JSON payload and moved to a queue of payloads to be sent to the server. 

-- local serpent = require "serpent"
local lub = require "lub"

local json = require "cjson"
local http = require "resty.http" -- this is "lua-resty-http" instead of the one vendored w/ Kong

local json_encode = json.encode
local table_getn = table.getn
local ngx_now = ngx.now
local ngx_log = ngx.log
local ngx_log_ERR = ngx.ERR
local ngx_timer_at = ngx.timer.at
local ngx_encode_base64 = ngx.encode_base64
local table_insert = table.insert
local table_concat = table.concat
local table_remove = table.remove
local string_sub = string.sub
local string_len = string.len
local string_rep = string.rep
local string_format = string.format
local math_pow = math.pow
local math_min = math.min
local setmetatable = setmetatable

-- Define an exponential retry policy for all workers.
-- The policy will give a delay that grows everytime
-- Galileo fails to respond. As soon as Galileo responds,
-- the delay is reset to its base.
local dict = ngx.shared.cache
local RETRY_INDEX_KEY = "librato_analytics_retry_index"
local RETRY_BASE_DELAY = 1 -- seconds
local RETRY_MAX_DELAY = 60 -- seconds

local buffer_mt = {}
buffer_mt.__index = buffer_mt

-- A handler for delayed batch sending. When no call has been made for X seconds
-- (X being conf.delay), we send the batch to keep analytics as close to real-time
-- as possible.
local delayed_send_handler
delayed_send_handler = function(premature, buffer)
  if ngx_now() - buffer.latest_call < buffer.auto_flush_delay then
    -- If the latest call was received during the wait delay, abort the delayed send and
    -- report it for X more seconds.
    local ok, err = ngx_timer_at(buffer.auto_flush_delay, delayed_send_handler, buffer)
    if not ok then
      buffer.lock_delayed = false -- re-enable creation of a delayed-timer for this buffer
      ngx_log(ngx_log_ERR, "[librato-analytics] failed to create delayed batch sending timer: ", err)
    end
  else
    -- Buffer is not full but it's been too long without an API call, let's flush it
    -- and send the data to analytics.
    buffer:flush()
    buffer.lock_delayed = false
    buffer.send_batch(nil, buffer)
  end
end

-- Instanciate a new buffer with configuration and properties
function buffer_mt.new(conf)
  local username = conf.username or os.getenv('LIBRATO_USER')
  if not username then
    error("[librato-analytics] Missing username; either set API's `config.username` or environment variable `LIBRATO_USER`")
  end
  local token = conf.token or os.getenv('LIBRATO_TOKEN')
  if not token then
    error("[librato-analytics] Missing authorization token; either set API's `config.token` or environment variable `LIBRATO_TOKEN`")
  end

  local buffer = {
    max_entries = conf.batch_size,
    auto_flush_delay = conf.delay,
    host = conf.host,
    port = conf.port,
    use_ssl = conf.use_ssl,
    verify_ssl = conf.verify_ssl,
    ssl_session = nil, -- last SSL session for reuse
    authorization = "Basic "..ngx_encode_base64(username..":"..token),
    path = conf.path,
    entries = {}, -- current buffer as an array of strings (serialized metrics)
    sending_queue = {}, -- array of constructed payloads (batches of metrics) to be sent
    lock_sending = false, -- lock if currently sending its data
    lock_delayed = false, -- lock if a delayed timer is already set for this buffer
    latest_call = nil -- date at which a request was last made to this API (for the delayed timer to know if it needs to trigger)
  }
  return setmetatable(buffer, buffer_mt)
end

-- Add a metric to the buffer
-- If the buffer is full (max entries or size in bytes), then trigger a sending.
-- If the buffer is not full, start a delayed timer in case no call is received
-- for a while.
function buffer_mt:add(metric)
  -- Keep track of the latest call for the delayed timer
  self.latest_call = ngx_now()

  local next_n_entries = table_getn(self.entries) + 1
  local full = next_n_entries > self.max_entries
  if full then
    self:flush()
    -- Batch size reached, let's send the data
    local ok, err = ngx_timer_at(0, self.send_batch, self)
    if not ok then
      ngx_log(ngx_log_ERR, "[librato-analytics] failed to create batch sending timer: ", err)
    end
  elseif not self.lock_delayed then
    -- Batch size not yet reached.
    -- Set a timer sending the data only in case nothing happens for awhile or if the batch_size is taking
    -- too much time to reach the limit and trigger the flush.
    local ok, err = ngx_timer_at(self.auto_flush_delay, delayed_send_handler, self)
    if ok then
      self.lock_delayed = true -- Make sure only one delayed timer is ever pending for a given buffer
    else
      ngx_log(ngx_log_ERR, "[librato-analytics] failed to create delayed batch sending timer: ", err)
    end
  end

  table_insert(self.entries, metric)
end

function buffer_mt:to_json()
  local entries = self.entries
  local all_entries = {}
  for i = 1, #entries, 1 do
    local individual_metrics = entries[i]
    for ii = 1, #individual_metrics, 1 do
      table_insert(all_entries, json_encode(individual_metrics[ii]))
    end
  end
  return "{\"gauges\":["..lub.join(all_entries, ",").."]}"
end

function buffer_mt:flush()
  table_insert(self.sending_queue, {
    payload = self:to_json(),
    n_entries = table_getn(self.entries)
  })
  self.entries = {}
end

-- Send the oldest payload (batch of metrics) from the queue to the collector.
-- The payload will be removed if the collector acknowledged the batch.
-- If the queue still has payloads to be sent, keep on sending them.
-- If the connection to the collector fails, use the retry policy.
function buffer_mt.send_batch(premature, self)
  if self.lock_sending then return end
  self.lock_sending = true -- simple lock

  if table_getn(self.sending_queue) < 1 then
    return
  end

  -- Let's send the oldest batch in our queue
  local batch_to_send = table_remove(self.sending_queue, 1)

  local retry
  local client = http:new()
  client:set_timeout(5000) -- 5 sec

  local use_ssl = self.use_ssl
  local use_port
  if use_ssl then use_port = 443 else use_port = 80 end

  local ok, err = client:connect(self.host, use_port)

  if ok then
    local ssl_err
    if use_ssl then
      self.ssl_session, ssl_err = client:ssl_handshake(self.ssl_session, self.host, self.verify_ssl)
    end
    if (not use_ssl or (use_ssl and not ssl_err)) then
      -- ngx_log(ngx_log_ERR, string_format("[librato-analytics] body: %s", serpent.block(batch_to_send.payload)))
      local res, err = client:request({
        version = 1.1,
        headers = {
          Authorization = self.authorization
        },
        method = "POST",
        path = self.path,
        body = batch_to_send.payload
      })
      if not res then
        retry = true
        ngx_log(ngx_log_ERR, string_format("[librato-analytics] failed to send batch (%s metrics %s bytes): %s", batch_to_send.n_entries, batch_to_send.size, err))
      else
        local res_body = res:read_body()
        if res.status == 200 then
          ngx_log(ngx.DEBUG, string_format("[librato-analytics] successfully saved the batch. (%s)", res_body))
        elseif res.status == 207 then
          ngx_log(ngx_log_ERR, string_format("[librato-analytics] collector could not save all metrics from the batch. (%s)", res_body))
        elseif res.status == 400 then
          ngx_log(ngx_log_ERR, string_format("[librato-analytics] collector refused the batch (%s metrics %s bytes). Dropping batch. Status: (%s) Error: (%s)", batch_to_send.n_entries, batch_to_send.size, res.status, res_body))
        else
          retry = true
          ngx_log(ngx_log_ERR, string_format("[librato-analytics] collector could not save the batch (%s metrics %s bytes). Status: (%s) Error: (%s)", batch_to_send.n_entries, batch_to_send.size, res.status, res_body))
        end
      end

      -- close connection, or put it into the connection pool
      if not res or res.headers["connection"] == "close" then
        ok, err = client:close()
        if not ok then
          ngx_log(ngx_log_ERR, "[librato-analytics] failed to close socket: ", err)
        end
      else
        client:set_keepalive()
      end
    else
      ngx_log(ngx_log_ERR, string_format("[librato-analytics] SSL handshake failed: %s", ssl_err))
    end
  else
    retry = true
    ngx_log(ngx_log_ERR, "[librato-analytics] failed to connect to the collector: ", err)
  end

  local next_batch_delay = 0 -- default delay for the next batch sending

  if retry then
    -- could not reach the collector, need to retry
    table_insert(self.sending_queue, 1, batch_to_send)

    local ok, err = dict:add(RETRY_INDEX_KEY, 0)
    if not ok and err ~= "exists" then
      ngx_log(ngx_log_ERR, "[librato-analytics] cannot prepare retry policy: ", err)
    end

    local index, err = dict:incr(RETRY_INDEX_KEY, 1)
    if err then
      ngx_log(ngx_log_ERR, "[librato-analytics] cannot increment retry policy index: ", err)
    elseif index then
      next_batch_delay = math_min(math_pow(index, 2) * RETRY_BASE_DELAY, RETRY_MAX_DELAY)
    end

    ngx_log(ngx.NOTICE, string_format("[librato-analytics] batch was queued for retry. Next retry in: %s seconds", next_batch_delay))
  else

    -- reset retry policy
    local ok, err = dict:set(RETRY_INDEX_KEY, 0)
    if not ok then
      ngx_log(ngx_log_ERR, "[librato-analytics] cannot reset retry policy index: ", err)
    end
  end

  self.lock_sending = false

  -- Keep sendind data if the queue is not yet emptied
  if table_getn(self.sending_queue) > 0 then
    local ok, err = ngx_timer_at(next_batch_delay, self.send_batch, self)
    if not ok then
      ngx_log(ngx_log_ERR, "[librato-analytics] failed to create batch retry timer: ", err)
    end
  end
end

return buffer_mt
