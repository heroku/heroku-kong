Kong Heroku app
===============
Deploy [Kong 0.11 Community Edition](https://konghq.com/kong-community-edition/) clusters to Heroku Common Runtime and Private Spaces using the [Kong buildpack](https://github.com/heroku/heroku-buildpack-kong).

🔬 This is a community proof-of-concept: [MIT license](LICENSE)

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

* [Purpose](#user-content-purpose)
* [Usage](#user-content-usage)
  * [Deploy](#user-content-deploy)
  * [Connect local to Heroku app](#user-content-connect-local-to-heroku-app)
  * [Admin console](#user-content-admin-console)
  * [Proxy & protect the Admin API](#user-content-proxy--protect-the-admin-api)
* [Customization](#user-content-customization)
  * [Configuration](#user-content-configuration)
  * [Kong plugins & additional Lua modules](#user-content-kong-plugins--additional-lua-modules)
* [Demos](#user-content-demos)
  * [API Rate Limiting](#user-content-demo-api-rate-limiting)
  * [Custom plugin: hello-world-header](#user-content-demo-custom-plugin-hello-world-header)
  * [Custom plugin: API translation, JSON→XML](#user-content-demo-custom-plugin-api-translation-jsonxml)
* [Development Notes](#user-content-dev-notes)
  * [Learning the Language of Kong](#user-content-learning-the-language-of-kong)
  * [Programming with Lua](#user-content-programming-with-lua)
  * [Local Development](#user-content-local-development)
    * [Requirements](#user-content-requirements)
    * [Clone & connect](#user-content-clone--connect)
    * [Setup](#user-content-setup)
    * [Running](#user-content-running)
    * [Testing](#user-content-testing)

Purpose
-------
Kong is an extensible HTTP gateway/proxy application based on [OpenResty](http://openresty.org/en/), a web app framework built on the embedded [Lua language](http://www.lua.org) capabilities of the [Nginx web server](http://nginx.org/en/).

With Heroku, Kong may be used for a variety of purposes. A few examples:

  * implemenent unified authentication for a suite of apps
  * enforce rate-limiting & request-size limits
  * create a single management point for domains & hostnames of public APIs.

👓 See: [main Kong site](https://getkong.org) for more about this powerful API gateway.

Usage
-----

### Deploy

Use the deploy button to create a Kong app in your Heroku account:

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

### Connect local to Heroku app

To use Admin console on a freshly-deployed app, clone and connect this repo (or your own fork) to the Heroku app:

```bash
git clone https://github.com/heroku/heroku-kong.git
cd heroku-kong

# Use the name of the Heroku app:
heroku git:remote --app $APP_NAME
heroku info
```

### Admin console

Use Kong CLI and the Admin API in a [one-off dyno](https://devcenter.heroku.com/articles/one-off-dynos):

```bash
heroku run bash

# Run Kong in the background of the one-off dyno:
~ $ bin/background-start

# Then, use `curl` to issue Admin API commands
# and `jq` to format the output:
~ $ curl http://$KONG_ADMIN_LISTEN | jq .

# Example CLI commands:
# (note some commands require the config file and others the prefix)
~ $ kong migrations list -c $KONG_CONF
~ $ kong health -p /app/.heroku
```

### Proxy & protect the Admin API
Kong's Admin API has no built-in authentication. Its exposure must be limited to a restricted, private network. For Kong on Heroku, the Admin API listens privately on `localhost:8001`.

To make Kong Admin accessible from other locations, let's setup Kong itself to proxy its Admin API with key authentication, HTTPS-enforcement, and request rate & size limiting.

From the [admin console](#user-content-admin-console):
```bash
# Create the authenticated `/kong-admin` API, targeting the localhost port:
curl http://localhost:8001/apis -i -X POST \
  --data name=kong-admin \
  --data uris=/kong-admin \
  --data upstream_url=http://localhost:8001 \
  --data https_only=true \
  --data http_if_terminated=true
curl http://localhost:8001/apis/kong-admin/plugins/ -i -X POST \
  --data 'name=request-size-limiting' \
  --data "config.allowed_payload_size=8"
curl http://localhost:8001/apis/kong-admin/plugins/ -i -X POST \
  --data 'name=rate-limiting' \
  --data "config.second=5"
curl http://localhost:8001/apis/kong-admin/plugins/ -i -X POST \
  --data 'name=key-auth' \
  --data "config.hide_credentials=true"
curl http://localhost:8001/apis/kong-admin/plugins/ -i -X POST \
  --data 'name=acl' \
  --data "config.whitelist=kong-admin"

# Create a consumer with username and authentication credentials:
curl http://localhost:8001/consumers/ -i -X POST \
  --data 'username=8th-wonder'
curl http://localhost:8001/consumers/8th-wonder/acls -i -X POST \
  --data 'group=kong-admin'
curl http://localhost:8001/consumers/8th-wonder/key-auth -i -X POST -d ''
# …this response contains the `"key"`, use it for `$ADMIN_KEY` below.
```

Now, access Kong's Admin API via the protected, public-facing proxy:

✏️ *Replace variables such as `$APP_NAME` with values for your unique deployment.*

```bash
# Set the request header:
curl -H "apikey: $ADMIN_KEY" https://$APP_NAME.herokuapp.com/kong-admin/status
# or use query params:
curl https://$APP_NAME.herokuapp.com/kong-admin/status?apikey=$ADMIN_KEY
```

Customization
-------------
Kong may be customized through configuration and plugins.

### Configuration

Kong is automatically configured at runtime with a `.profile.d` script:

  * renders the `config/kong.conf` file based on:
    * the customizable [`config/kong.conf.etlua`](config/kong.conf.etlua) template
    * values of [config vars, as defined in the buildpack](https://github.com/heroku/heroku-buildpack-kong#user-content-environment-variables)
  * exports environment variables
    * see: `.profile.d/kong-env` in a running dyno

All file-based config may be overridden by setting `KONG_`-prefixed config vars, e.g. `heroku config:set KONG_LOG_LEVEL=debug`

👓 See: [Kong 0.11 Configuration Reference](https://getkong.org/docs/0.11.x/configuration/)


### Kong plugins & additional Lua modules

👓 See: [buildpack usage](https://github.com/heroku/heroku-buildpack-kong#user-content-usage)


Demos
-----
Usage examples and sample plugins are includes with this Heroku Kong app.

### Demo: [API Rate Limiting](https://getkong.org/plugins/rate-limiting/)

Request [this Bay Lights API](https://kong-proxy-public.herokuapp.com/bay-lights/lights) more than five times in a minute, and you'll get **HTTP Status 429: API rate limit exceeded**, along with `X-Ratelimit-Limit-Minute` & `X-Ratelimit-Remaining-Minute` headers to help the API consumers regulate their usage.

Try it in your shell terminal:
```bash
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 200 OK
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# HTTP/1.1 429
```

Here's the whole configuration for this API rate limiter:

```bash
curl http://localhost:8001/apis/ -i -X POST \
  --data 'name=bay-lights' \
  --data 'uris=/bay-lights' \
  --data 'upstream_url=https://bay-lights-api-production.herokuapp.com/'
curl http://localhost:8001/apis/bay-lights/plugins/ -i -X POST \
  --data 'name=request-size-limiting' \
  --data "config.allowed_payload_size=8"
curl http://localhost:8001/apis/bay-lights/plugins/ -i -X POST \
  --data 'name=rate-limiting' \
  --data "config.minute=5"
```

### Demo: custom plugin: hello-world-header

[Custom plugins](https://getkong.org/docs/0.11.x/plugin-development/) allow you to observe and transform HTTP traffic using lightweight, high-performance [Lua](http://www.lua.org) code in Nginx [request processing contexts](https://getkong.org/docs/0.11.x/plugin-development/custom-logic/#available-request-contexts). Building on the [previous example](#user-content-demo-api-rate-limiting), let's add a simple plugin to Kong.

[hello-world-header](lib/kong/plugins/hello-world-header/handler.lua) will add an HTTP response header **X-Hello-World** showing the date and a message from an environment variable.

Activate this plugin for the API:

```bash
curl http://localhost:8001/apis/bay-lights/plugins/ -i -X POST \
  --data 'name=hello-world-header'
```

Then, set a message through the Heroku config var:

```bash
heroku config:set HELLO_WORLD_MESSAGE='🌈🙈'
# …the app will restart.
```

Now, when fetching an API response, notice the **X-Hello-World** header:

```bash
curl --head https://kong-proxy-public.herokuapp.com/bay-lights/lights
# ↩︎
# HTTP/1.1 200 OK
# Connection: keep-alive
# Content-Type: application/json;charset=utf-8
# Content-Length: 9204
# X-Ratelimit-Limit-Minute: 5
# X-Ratelimit-Remaining-Minute: 4
# Server: Cowboy
# Date: Mon, 28 Aug 2017 23:14:47 GMT
# Strict-Transport-Security: max-age=31536000
# X-Content-Type-Options: nosniff
# Vary: Accept-Encoding
# Request-Id: 6c815aae-a5e9-496f-b731-dc72bbe2b63e
# Via: kong/0.11.0, 1.1 vegur
# X-Hello-World: Today is 2017-08-28. 🌈🙈  <--- The injected header
# X-Kong-Upstream-Latency: 49
# X-Kong-Proxy-Latency: 161
```


### Demo: custom plugin: API translation, JSON→XML

JSON/REST has taken over as the internet API lingua franca, shedding the complexity of XML/SOAP. The [National Digital Forecast Database [NDFD]](http://graphical.weather.gov/xml/) is a legacy XML/SOAP service.

This app includes a sample, custom plugin [ndfd-xml-as-json](lib/kong/plugins/ndfd-xml-as-json). This plugin exposes a JSON API that returns the maximum temperatures forecast for a location from the NDFD SOAP service. Using the single-resource concept of REST, the many variations of a SOAP or other legacy interfaces may be broken out into elegant, individual JSON APIs.

Try it in your shell terminal:
```bash
curl https://kong-proxy-public.herokuapp.com/ndfd-max-temps \
  --data '{"latitude":37.733795,"longitude":-122.446747}'
# Response contains max temperatures forecast for San Francisco, CA

curl https://kong-proxy-public.herokuapp.com/ndfd-max-temps \
 --data '{"latitude":27.964157,"longitude":-82.452606}'
# Response contains max temperatures forecast for Tampa, FL

curl https://kong-proxy-public.herokuapp.com/ndfd-max-temps \
  --data '{"latitude":41.696629,"longitude":-71.149994}'
# Response contains max temperatures forecast for Fall River, MA
```

Much more elegant than the legacy API. See the [sample request body](spec/data/ndfd-request.xml):
```bash
curl --data @spec/data/ndfd-request.xml -H 'Content-Type:text/xml' -X POST https://graphical.weather.gov/xml/SOAP_server/ndfdXMLserver.php
# Response contains wrapped XML data. Enjoy decoding that.
```

This technique may be used to create a suite of cohesive JSON APIs out of various legacy APIs.

Here's the configuration for this API translator:

```bash
curl http://localhost:8001/apis -i -X POST \
  --data 'name=ndfd-max-temps' \
  --data 'upstream_url=https://graphical.weather.gov/xml/SOAP_server/ndfdXMLserver.php' \
  --data 'uris=/ndfd-max-temps'
curl http://localhost:8001/apis/ndfd-max-temps/plugins/ -i -X POST \
  --data 'name=request-size-limiting' \
  --data "config.allowed_payload_size=8"
curl http://localhost:8001/apis/ndfd-max-temps/plugins/ -i -X POST \
  --data 'name=rate-limiting' \
  --data 'config.minute=5'
curl http://localhost:8001/apis/ndfd-max-temps/plugins/ -i -X POST \
  --data 'name=ndfd-xml-as-json'
```

👓 See the implementation of the custom plugin's [Lua source code](lib/kong/plugins/ndfd-xml-as-json), [unit tests](spec/unit/kong/plugins/ndfd-xml-as-json/handler_spec.lua), and [integration tests](spec/integration/kong/plugins/ndfd-xml-as-json_spec.lua).


## Dev notes

### Learning the language of Kong

* [Definitely an openresty guide](http://www.staticshin.com/programming/definitely-an-open-resty-guide/)
* [An Introduction To OpenResty - Part 1](http://openmymind.net/An-Introduction-To-OpenResty-Nginx-Lua/), [2](http://openmymind.net/An-Introduction-To-OpenResty-Part-2/), & [3](http://openmymind.net/An-Introduction-To-OpenResty-Part-3/)
* [Nginx API for Lua](https://github.com/openresty/lua-nginx-module#nginx-api-for-lua), `ngx` reference, for use in Kong plugins
  * [Nginx variables](http://nginx.org/en/docs/http/ngx_http_upstream_module.html#var_upstream_status), accessible through `ngx.var`

### Programming with Lua

* [Lua 5.1](http://www.lua.org/manual/5.1/), Note: Kong is not compatible with the newest Lua version
* [Classic Objects](https://github.com/rxi/classic), the basis of Kong's plugins
* [Moses](http://yonaba.github.io/Moses/doc/), functional programming
* [Lubyk](http://doc.lubyk.org), realtime programming (performance- & game-oriented)
* [resty-http](https://github.com/pintsized/lua-resty-http), Nginx-Lua co-routine based HTTP client
* [Serpent](http://notebook.kulchenko.com/programming/serpent-lua-serializer-pretty-printer), inspect values
* [Busted](http://olivinelabs.com/busted/), testing framework

### Local development

To work with Kong locally on macOS X.

#### Requirements

* [kong](https://getkong.org/install/osx/) for macOS via Homebrew
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [Heroku](https://www.heroku.com/home)
  * [command-line tools (CLI)](https://toolbelt.heroku.com)
  * [a free account](https://signup.heroku.com)

#### Clone & connect

If you haven't already, clone and connect your own fork of this repo to the Heroku app:

```bash
# Replace the main repo with your own fork:
git clone https://github.com/heroku/heroku-kong.git
cd heroku-kong

# Use the name of the Heroku app:
heroku git:remote --app $APP_NAME
heroku info
```

##### Setup

1. Ensure [requirements](#user-content-requirements) are met
1. Create the Postgres user & databases:
    
    ```bash
    createuser --pwprompt kong
    # set the password "kong"

    createdb --owner=kong kong_dev
    createdb --owner=kong kong_tests
    ```
1. Execute `./bin/setup`

##### Running

```bash
bin/start
```

* Logs in `/usr/local/var/kong/logs/` 
* Prefix is `/usr/local/var/kong` for commands like:
  * `kong health -p /usr/local/var/kong`
  * `kong stop -p /usr/local/var/kong`

##### Testing

Any test-specific Lua rocks should be specified in `Rockfile_test` file, so that they are not installed when the app is deployed.

Add tests in `spec/`:

  * Uses the [Busted testing framework](http://olivinelabs.com/busted)
  * [Kong plugin testing guide](https://getkong.org/docs/0.11.x/plugin-development/tests/)
  * [buildpack requirements for testing](https://github.com/heroku/heroku-buildpack-kong/blob/master/README.markdown#user-content-testing)

```bash
bin/test
```
