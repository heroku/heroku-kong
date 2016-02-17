local BasePlugin = require "kong.plugins.base_plugin"
local XmlAsJson = BasePlugin:extend()
local json = require "cjson"
local xml = require "xml"
local lub = require "lub"

-- local S = require "serpent"

function XmlAsJson:new()
  XmlAsJson.super.new(self, "ndfd-xml-as-json")
end

function XmlAsJson:access(config)
  XmlAsJson.super.access(self)

  ngx.req.read_body()  -- explicitly read the req body
  local request_body = ngx.req.get_body_data()
  local request_xml = json_to_xml(request_body)

  ngx.req.set_header("Content-Type", "text/xml")
  ngx.req.set_header("Content-Length", #request_xml)
  ngx.req.clear_header("Accept-Encoding")
  -- ngx.log(ngx.DEBUG, S.block(ngx.req.get_headers()))
  ngx.req.set_body_data(request_xml)
end

function XmlAsJson:header_filter(config)
  XmlAsJson.super.header_filter(self)

  ngx.header.content_length = nil
end

function XmlAsJson:body_filter(config)
  XmlAsJson.super.body_filter(self)

  local chunk = ngx.arg[1]
  local eof = ngx.arg[2]

  -- collect chunks in a context variable
  ngx.ctx.response_body = (ngx.ctx.response_body or "")..chunk

  if eof then
    local response_body = ngx.ctx.response_body
    local response_json = xml_to_json(response_body)
    ngx.arg[1] = response_json
  else
    -- Do not pass chunk through; convert the whole response to JSON once EOF
    ngx.arg[1] = nil
  end
end


function xml_to_json(v)
  -- ngx.log(ngx.DEBUG, S.block(v))
  local wrapped_response_xml = xml.load(v)
  -- Unwrap the embedded response data (Double SOAPed!)
  local response_xml = xml.load(unescape(
    xml.find(wrapped_response_xml, 'dwmlOut')[1]
  ))
  local temperature_data = xml.find(response_xml, 'temperature')
  local location_point_data = xml.find(response_xml, 'point')

  local response_data = {
    name = 'temperature',
    type = temperature_data.type,
    units = temperature_data.units,
    latitude = location_point_data.latitude,
    longitude = location_point_data.longitude,
    values = {}
  }

  local times = {}
  lub.search(response_xml, function(node)
    if node.xml == 'start-valid-time' then
      table.insert(times, { time = node[1] }) -- text value
    end
  end)
  lub.deepMerge(response_data, 'values', times)

  local values = {}
  lub.search(xml.find(response_xml, 'temperature'), function(node)
    if node.xml == 'value' then
      table.insert(values, { value = node[1] }) -- text value
    end
  end)
  lub.deepMerge(response_data, 'values', values)

  local response_json = json.encode(response_data)
  return response_json
end


function json_to_xml(v)
  -- ngx.log(ngx.DEBUG, S.block(v))
  local request_json = json.decode(v)
  local request_xml = xml.dump(
    {xml='SOAP-ENV:Envelope',
      ['SOAP-ENV:encodingStyle'] = "http://schemas.xmlsoap.org/soap/encoding/",
      ['xmlns:SOAP-ENV']         = "http://schemas.xmlsoap.org/soap/envelope/",
      ['xmlns:xsd']              = "http://www.w3.org/2001/XMLSchema",
      ['xmlns:xsi']              = "http://www.w3.org/2001/XMLSchema-instance",
      ['xmlns:SOAP-ENC']         = "http://schemas.xmlsoap.org/soap/encoding/",
      {xml = 'SOAP-ENV:Body',
        {xml = 'ns3591:NDFDgen', ['xmlns:ns3591'] = "uri:DWMLgen",
          {xml = 'latitude',  ['xsi:type'] = "xsd:string", string.format("%f", request_json["latitude"])},
          {xml = 'longitude', ['xsi:type'] = "xsd:string", string.format("%f", request_json["longitude"])},
          {xml = 'product',   ['xsi:type'] = "xsd:string", 'time-series'},
          {xml = 'startTime', ['xsi:type'] = "xsd:string", '2004-01-01T00:00:00'},
          {xml = 'endTime',   ['xsi:type'] = "xsd:string", '2020-01-12T00:00:00'},
          {xml = 'unit',      ['xsi:type'] = "xsd:string", 'e'},
          {xml = 'weatherParameters',
            {xml = 'maxt',    ['xsi:type'] = "xsd:boolean", '1'}
          }
        }
      }
    }
  )
  return request_xml
end

function unescape(str)
  str = string.gsub( str, '&lt;', '<' )
  str = string.gsub( str, '&gt;', '>' )
  str = string.gsub( str, '&quot;', '"' )
  str = string.gsub( str, '&apos;', "'" )
  str = string.gsub( str, '&#(%d+);', function(n) return string.char(n) end )
  str = string.gsub( str, '&#x(%d+);', function(n) return string.char(tonumber(n,16)) end )
  str = string.gsub( str, '&amp;', '&' ) -- Be sure to do this after all others
  return str
end

return XmlAsJson
