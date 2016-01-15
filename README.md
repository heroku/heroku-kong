Kong Heroku app
===============
[Kong](https://getkong.org) as a [12-factor](http://12factor.net) app.

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/heroku/heroku-kong)

Uses the custom [Kong buildpack](https://github.com/heroku/heroku-buildpack-kong).

Running
-------

Execute `kong-12f` before every run, to configure using environment variables.

For example, the [Kong buildpack release](https://github.com/heroku/heroku-buildpack-kong/bin/release) runs:
```
kong-12f && kong start -c config/kong.yml
```

### Commands

* web (start Kong): `heroku run "kong-12f && kong start -c config/kong.yml"`
* shell (interactive CLI): `heroku run "kong-12f && bash"`
* initialize DB schema (interactive CLI): `heroku run "kong-12f && kong migrations reset -c config/kong.yml"`

### Configuration

Kong is configured at runtime with the `kong-12f` command, which renders the config file [`config/kong.yml.etlua`](config/kong.yml.etlua) each time.

Revise `config/kong.yml.etlua` to suite your application. See: [Kong 0.5 Configuration Reference](https://getkong.org/docs/0.5.x/configuration/)

`kong-12f` uses environment vars:

* `CASSANDRA_URL`
* `CASSANDRA_TRUSTED_CERT`
* `PORT`
* `KONG_EXPOSE`

### Kong plugins & additional Lua modules

  * Lua source
    * [Kong plugins](https://getkong.org/docs/0.5.x/plugin-development/):
      * `lib/kong/plugins/{NAME}`
      * See: [Plugin File Structure](https://getkong.org/docs/0.5.x/plugin-development/file-structure/)
    * Other Lua modules:
      * `lib/{NAME}.lua` or
      * `lib/{NAME}/init.lua`
  * Lua rocks: specify in the app's `.luarocks` file.

    Each line is passed as args to `luarocks install`. Example:

    ```
date 2.1.2-1
    ```
  * Add each Kong plugin name to the `plugins_available` list in `config/kong.yml.etlua` 

### Protecting the Admin API
Kong's Admin API has no built-in authentication. Its exposure must be limited to a restricted, private network.

For Kong on Heroku, the Admin API listens on the dyno's localhost port 8001.

That's the `admin_api_port` set in [`config/kong.yml.etlua`](config/kong.yml.etlua).

#### Access via Heroku console
In a one-off dyno console, start Kong, and make requests to the Admin API:

```bash
$ heroku run bash
> kong-12f && kong start -c config/kong.yml &
# …Kong will start in the background, still writing to the console.
> curl localhost:8001
```

#### Authenticated Admin API
Using Kong itself, you may expose the Admin API with authentication & rate limiting.

From the Heroku console:
```bash
# Create the authenticated `/kong-admin` API, targeting the localhost port:
curl -i -X POST --url http://localhost:8001/apis/ --data 'name=kong-admin' --data 'upstream_url=http://localhost:8001/' --data 'request_path=/kong-admin' --data 'strip_request_path=true'
curl -i -X POST --url http://localhost:8001/apis/kong-admin/plugins/ --data 'name=request-size-limiting' --data "config.allowed_payload_size=8"
curl -i -X POST --url http://localhost:8001/apis/kong-admin/plugins/ --data 'name=rate-limiting' --data "config.minute=12"
curl -i -X POST --url http://localhost:8001/apis/kong-admin/plugins/ --data 'name=key-auth' --data "config.hide_credentials=true"
curl -i -X POST --url http://localhost:8001/apis/kong-admin/plugins/ --data 'name=acl' --data "config.whitelist=kong-admin"

# Create a consumer with username and authentication credentials:
curl -i -X POST --url http://localhost:8001/consumers/ --data 'username=8th-wonder'
curl -i -X POST --url http://localhost:8001/consumers/8th-wonder/acls --data 'group=kong-admin'
curl -i -X POST --url http://localhost:8001/consumers/8th-wonder/key-auth
# …this response contains the `"key"`.
```

Now, access Kong's Admin API via the protected, public-facing proxy:
```bash
# Set the request header:
curl -H 'apikey: {kong-admin key}' https://kong-proxy-public.herokuapp.com/kong-admin/status
# or use query params:
curl https://kong-proxy-public.herokuapp.com/kong-admin/status?apikey={kong-admin key}
```


### Demo: [API Rate Limiting](https://getkong.org/plugins/rate-limiting/)

Request [this Bay Lights API](https://kong-proxy-public.herokuapp.com/bay-lights/lights) more than five times in a minute, and you'll get **HTTP Status 429: API rate limit exceeded**, along with `X-Ratelimit-Limit-Minute` & `X-Ratelimit-Remaining-Minute` headers to help the API consumers regulate their usage.

Try it in your shell terminal:
```bash
curl -I https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl -I https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl -I https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl -I https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl -I https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl -I https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 429
```

Here's the whole configuration for this API rate limiter:

```bash
curl -i -X POST --url http://localhost:8001/apis/ --data 'name=bay-lights' --data 'upstream_url=https://bay-lights-api-production.herokuapp.com/' --data 'request_path=/bay-lights' --data 'strip_request_path=true'
curl -i -X POST --url http://localhost:8001/apis/bay-lights/plugins/ --data 'name=request-size-limiting' --data "config.allowed_payload_size=8"
curl -i -X POST --url http://localhost:8001/apis/bay-lights/plugins/ --data 'name=rate-limiting' --data "config.minute=5"
# Demo loading app-specific Kong plugins & Lua modules.
curl -i -X POST --url http://localhost:8001/apis/bay-lights/plugins/ --data 'name=hello-world-header'
```

### Demo: API translation, XML as JSON

JSON/REST has taken over as the internet API lingua franca, shedding the complexity of XML/SOAP. The [National Digital Forecast Database [NDFD]](http://graphical.weather.gov/xml/) is a legacy XML/SOAP service.

Here we demonstrate a custom plugin [ndfd-xml-as-json](lib/kong/plugins/ndfd-xml-as-json) to expose an JSON/REST API that fetches the maximum temperatures forecast for a location from the NDFD SOAP service. Using the single-resource concept of REST, the many variations of a SOAP interface may be broken out into elegant, individual JSON APIs.

Try it in your shell terminal:
```bash
curl --data '{"latitude":37.733795,"longitude":-122.446747}' https://kong-proxy-public.herokuapp.com/ndfd-max-temps
# Response contains max temperatures forecast for San Francisco, CA
curl --data '{"latitude":27.964157,"longitude":-82.452606}' https://kong-proxy-public.herokuapp.com/ndfd-max-temps
# Response contains max temperatures forecast for Tampa, FL
curl --data '{"latitude":41.696629,"longitude":-71.149994}' https://kong-proxy-public.herokuapp.com/ndfd-max-temps
# Response contains max temperatures forecast for Fall River, MA
```

Much more elegant than the legacy API. See the [sample request body](spec/data/ndfd-request.xml):
```bash
curl --data @spec/data/ndfd-request.xml -H 'Content-Type:text/xml' -X POST http://graphical.weather.gov/xml/SOAP_server/ndfdXMLserver.php
# Response contains wrapped XML data. Enjoy decoding that.
```

This technique may be used to create a suite of cohesive JSON APIs out of various legacy APIs.

Here's the configuration for this API translator:

```bash
curl -X POST -v http://localhost:8001/apis --data 'name=ndfd-max-temps' --data 'upstream_url=http://graphical.weather.gov/xml/SOAP_server/ndfdXMLserver.php' --data 'request_path=/ndfd-max-temps' --data 'strip_request_path=true'
curl -X POST -v http://localhost:8001/apis/ndfd-max-temps/plugins/ --data 'name=request-size-limiting' --data "config.allowed_payload_size=8"
curl -X POST -v http://localhost:8001/apis/ndfd-max-temps/plugins/ --data 'name=rate-limiting' --data "config.minute=5"
curl -X POST -v http://localhost:8001/apis/ndfd-max-temps/plugins/ --data 'name=ndfd-xml-as-json'
```

### Demo: API analytics, Librato

This demo requires your own Heroku Kong instance with the Librato add-on.

Here's the plugin configuration. Example based on the Bay Lights API example above:

```bash
curl -X POST -v http://localhost:8001/apis/bay-lights/plugins/ --data 'name=librato-analytics' --data "config.verify_ssl=false"
```

The `LIBRATO_*` config vars set-up by the add-on will be used for authorization, but can be overridden by explicitly setting `config.username` & `config.token` for specific instances of the Kong plugin.

### Notes

Plugins are implemented as [classic objects](https://github.com/rxi/classic).

### Local Development

To work with Kong locally on Mac OS X.

#### Setup

1. [Install Kong using the .pkg](https://getkong.org/install/osx/)
1. [Install Cassandra](https://gist.github.com/mars/a303a2616f27b46d72da)
1. Execute `./bin/setup`

#### Running

* Cassandra needs to be running
  * start `launchctl load ~/Library/LaunchAgents/homebrew.mxcl.cassandra.plist`
  * stop `launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.cassandra.plist`
* Execute `./bin/start`
* Logs in `/usr/local/var/kong/logs/` 

#### Testing

Any test-specific Lua rocks should be specified in `.luarocks_test` file, so that they are not installed when the app is deployed.

1. Add tests in `spec/`
  * Uses the [Busted testing framework](http://olivinelabs.com/busted)
  * See also [Kong integration testing](https://getkong.org/docs/0.5.x/plugin-development/tests/)
1. Execute `source .profile.local`
1. Execute `busted` to run the tests
