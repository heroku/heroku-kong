local handler = require "kong.plugins.ndfd-xml-as-json.handler"
local json = require "cjson"
local xml = require "xml"

describe("kong.plugins.ndfd-xml-as-json.handler", function()

  it("should return a table", function()
    assert.is.equal("table", type(handler))
  end)

  describe("#new", function()
    it("is a function", function()
      assert.is.equal("function", type(handler.new))
    end)
  end)

  describe("#access", function()
    it("is a function", function()
      assert.is.equal("function", type(handler.access))
    end)

    it("should transform request JSON to XML", function()
      local params = {
        latitude = 38.99,
        longitude = -77.01
      }
      local body_data = json.encode(params)
      local headers = {}

      ngx.req.read_body = function() return nil end
      ngx.req.get_body_data = function() return body_data end
      ngx.req.set_body_data = function(new_data) body_data = new_data end
      ngx.req.set_header = function(k,v) headers[k] = v end
      ngx.req.clear_header = function(k) headers[k] = nil end

      local subject = handler()
      subject:access()

      local req_xml = xml.load(body_data)

      assert.is.equal(string.format("%f", params.latitude), xml.find(req_xml, 'latitude')[1])
      assert.is.equal(string.format("%f", params.longitude), xml.find(req_xml, 'longitude')[1])
      assert.is.equal("1", xml.find(req_xml, 'maxt')[1])

      assert.is.equal("text/xml", headers["Content-Type"])
    end)
  end)

  describe("#header_filter", function()
    it("is a function", function()
      assert.is.equal("function", type(handler.header_filter))
    end)
  end)

  describe("#body_filter", function()
    it("is a function", function()
      assert.is.equal("function", type(handler.body_filter))
    end)

    describe("for a typical XML response", function()
      before_each(function()
        local data_file = io.open("./spec/data/ndfd-response.xml", "r")
        local body_data = data_file:read("*a")
        data_file:close()

        ngx.arg = {}
        ngx.arg[1] = body_data
        ngx.arg[2] = true -- EOF flag

        subject = handler()
      end)

      it("should transform response XML to JSON", function()
        subject:body_filter()

        local res_json = json.decode(ngx.arg[1])

        assert.is.equal('temperature', res_json.name)
        assert.is.equal('maximum', res_json.type)
        assert.is.equal('Fahrenheit', res_json.units)
        assert.is.equal('38.99', res_json.latitude)
        assert.is.equal('-77.01', res_json.longitude)
        assert.is.equal("table", type(res_json.values))
      end)

      it("returns a list of merged values & times", function()
        subject:body_filter()

        local res_json = json.decode(ngx.arg[1])

        assert.is.equal("46", res_json.values[1].value)
        assert.is.equal("2016-01-14T07:00:00-05:00", res_json.values[1].time)
        assert.is.equal("49", res_json.values[2].value)
        assert.is.equal("2016-01-15T07:00:00-05:00", res_json.values[2].time)
        assert.is.equal("48", res_json.values[3].value)
        assert.is.equal("2016-01-16T07:00:00-05:00", res_json.values[3].time)
        assert.is.equal("38", res_json.values[4].value)
        assert.is.equal("2016-01-17T07:00:00-05:00", res_json.values[4].time)
        assert.is.equal("28", res_json.values[5].value)
        assert.is.equal("2016-01-18T07:00:00-05:00", res_json.values[5].time)
        assert.is.equal("30", res_json.values[6].value)
        assert.is.equal("2016-01-19T07:00:00-05:00", res_json.values[6].time)
        assert.is.equal("35", res_json.values[7].value)
        assert.is.equal("2016-01-20T07:00:00-05:00", res_json.values[7].time)
      end)
    end)

    it("should collect chunked response", function()
      data_file = io.open("./spec/data/ndfd-response.xml", "r")

      local subject = handler()
      ngx.arg = {}

      -- Chunk by line in the data file

      ngx.arg[1] = data_file:read("*l")
      subject:body_filter()

      ngx.arg[1] = data_file:read("*l")
      subject:body_filter()

      ngx.arg[1] = data_file:read("*l")
      subject:body_filter()

      ngx.arg[1] = data_file:read("*l")
      subject:body_filter()

      ngx.arg[1] = data_file:read("*l")
      subject:body_filter()

      -- All the remaining content
      ngx.arg[1] = data_file:read("*a")
      ngx.arg[2] = true -- EOF flag
      subject:body_filter()

      data_file:close()

      local res_json = json.decode(ngx.arg[1])

      assert.is.equal('maximum', res_json.type)
    end)
  end)

end)
