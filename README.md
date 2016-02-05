Kong Heroku app
===============
[Kong](https://getkong.org) as a [12-factor](http://12factor.net) app.

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/heroku/heroku-kong)

Requires configuring a Cassandra datastore such as [Instaclustr](https://elements.heroku.com/addons/instaclustr). See: [Cassandra notes](#cassandra)

Uses the [Kong buildpack](https://github.com/heroku/heroku-buildpack-kong) via [multi buildpack](https://github.com/heroku/heroku-buildpack-multi).

Deploying
---------
Requires a [Heroku Private Space](https://www.heroku.com/private-spaces) to scale beyond a signle Kong dyno. (The new clustering behavior requires private dyno-to-dyno networking.)

```bash
heroku create my-proxy-app --buildpack https://github.com/heroku/heroku-buildpack-multi.git --space my-private-space
git clone https://github.com/heroku/heroku-kong.git
cd heroku-kong
git push heroku master
```

Running
-------
The [Procfile](Procfile) & [Procfile.web](Procfile.web) will start & supervise all of Kong's process.

### Commands

To use Kong CLI in a console:
```
$ heroku run bash

# Run Kong in the background, so you can issue commands:
~ $ kong start -c $KONG_CONF &
# …Kong will start in the background, still writing to the console.

# Example commands:
~ $ kong --help
~ $ kong migrations list -c $KONG_CONF
```

### Configuration

First, [config vars are setup in the buildpack](https://github.com/heroku/heroku-buildpack-kong#usage).

Kong is automatically configured at runtime with the `.profile.d/kong-12f.sh` script, which:

  * renders the `kong.yml` config file
  * exports environment variables (see: `.profile.d/kong-env` in a running dyno)

Revise [`config/kong.yml.etlua`](config/kong.yml.etlua) to suite your application.

See: [Kong 0.6 Configuration Reference](https://getkong.org/docs/0.6.x/configuration/)

### Cassandra

You may connect to any Cassandra datastore accessible to your Heroku app using the `CASSANDRA_URL` config var as [documented in the buildpack](https://github.com/heroku/heroku-buildpack-kong#usage).

For the [Instaclustr add-on](https://elements.heroku.com/addons/instaclustr), initial keyspace setup is required. To get started, use [`cqlsh`](http://docs.datastax.com/en/cql/3.1/cql/cql_reference/cqlsh.html) to run [CQL](https://cassandra.apache.org/doc/cql3/CQL-2.1.html) queries:

  ```shell
$ CQLSH_HOST={SINGLE_IC_CONTACT_POINT} cqlsh --cqlversion 3.2.1 -u {IC_USER} -p {IC_PASSWORD}
> CREATE KEYSPACE IF NOT EXISTS kong WITH replication = {'class':'NetworkTopologyStrategy', 'US_EAST_1':3};
> GRANT ALL ON KEYSPACE kong TO iccassandra;
> exit
  ```

Then, initialize DB schema [using a console](#commands):
```bash
~ $ kong migrations reset -c $KONG_CONF
```

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
> kong-12f && source .profile.d/kong-env.sh
> kong start -c config/kong.yml &
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

### Demo: API analytics, [Librato](https://elements.heroku.com/addons/librato)

Collect per-API metrics, explore, and set alerts on them with Librato. This [`librato-analytics`](lib/kong/plugins/librato-analytics) plugin demonstrates near-realtime (~1-minute delay), batch-oriented (up 300 metrics/post), asynchronous (non-blocking to proxy traffic) pushes of Kong/Nginx metrics to [Librato's Metrics API](http://dev.librato.com/v1/metrics).

![Screenshot of Librato Kong metrics](http://marsikai.s3.amazonaws.com/librato-kong-bay-lights.png)

The per-API metrics are sent by source, named "kong-{API-NAME}":
  * request size (bytes)
  * response size (bytes)
  * kong latency (milliseconds)
  * upstream latency (milliseconds)
  * response latency (milliseconds)

*This demo requires your own Heroku Kong instance with the Librato add-on. Kong sends custom metrics, so a paid plan of any level is required.*

Here's the plugin configuration. Example based on the Bay Lights API example above:

```bash
curl -X POST -v http://localhost:8001/apis/bay-lights/plugins/ --data 'name=librato-analytics' --data "config.verify_ssl=false"
```

The `LIBRATO_*` config vars set-up by the add-on will be used for authorization, but can be overridden by explicitly setting `config.username` & `config.token` for specific instances of the Kong plugin.

### Dev Notes

#### Learning the Language of Kong

* [Definitely an openresty guide](http://www.staticshin.com/programming/definitely-an-open-resty-guide/)
* [An Introduction To OpenResty - Part 1](http://openmymind.net/An-Introduction-To-OpenResty-Nginx-Lua/), [2](http://openmymind.net/An-Introduction-To-OpenResty-Part-2/), & [3](http://openmymind.net/An-Introduction-To-OpenResty-Part-3/)
* [Nginx API for Lua](https://github.com/openresty/lua-nginx-module#nginx-api-for-lua), `ngx` reference, for use in Kong plugins
  * [Nginx variables](http://nginx.org/en/docs/http/ngx_http_upstream_module.html#var_upstream_status), accessible through `ngx.var`

#### Programming with Lua

* [Lua 5.1](http://www.lua.org/manual/5.1/), Note: Kong is not compatible with the newest Lua version
* [Classic Objects](https://github.com/rxi/classic), the basis of Kong's plugins
* [Moses](http://yonaba.github.io/Moses/doc/), functional programming
* [Lubyk](http://doc.lubyk.org), realtime programming (performance- & game-oriented)
* [resty-http](https://github.com/pintsized/lua-resty-http), Nginx-Lua co-routine based HTTP client
* [Serpent](http://notebook.kulchenko.com/programming/serpent-lua-serializer-pretty-printer), inspect values
* [Busted](http://olivinelabs.com/busted/), testing framework

#### Using Environment Variables in Plugins

As a [12-factor](http://12factor.net) app, Heroku Kong already uses environment variables for configuration. Here's how to use those vars within your own code.

1. Whitelist the variable name for use within Nginx 
  * In the [**kong.yml** config files](config/) `nginx:` property add `env MY_VARIABLE;`
2. Access the variable in Lua plugins
  * Use `os.getenv('MY_VARIABLE')` to retrieve the value

#### Local Development

To work with Kong locally on Mac OS X.

##### Setup

1. [Install Kong using the .pkg](https://getkong.org/install/osx/)
1. [Install Cassandra](https://gist.github.com/mars/a303a2616f27b46d72da)
1. Execute `./bin/setup`

##### Running

* Cassandra needs to be running
  * start `launchctl load ~/Library/LaunchAgents/homebrew.mxcl.cassandra.plist`
  * stop `launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.cassandra.plist`
* Execute `./bin/start`
* Logs in `/usr/local/var/kong/logs/` 

##### Testing

Any test-specific Lua rocks should be specified in `.luarocks_test` file, so that they are not installed when the app is deployed.

1. Add tests in `spec/`
  * Uses the [Busted testing framework](http://olivinelabs.com/busted)
  * See also [Kong integration testing](https://getkong.org/docs/0.5.x/plugin-development/tests/)
1. Execute `source .profile.local`
1. Execute `busted` to run the tests

