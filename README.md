Kong as a Heroku app
====================
Deploy [Kong 1.0](https://konghq.com/blog/kong-1-0-ga/) clusters to Heroku Common Runtime and Private Spaces using the [Kong buildpack](https://github.com/heroku/heroku-buildpack-kong/).

⏫ **Upgrading from an earlier version?** See [Upgrade Guide](#user-content-upgrade-guide).

🔬 This is a community proof-of-concept, [MIT license](LICENSE), provided "as is", without warranty of any kind.

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

* [Purpose](#user-content-purpose)
* [Usage](#user-content-usage)
  * [Deploy](#user-content-deploy)
  * [Connect local to Heroku app](#user-content-connect-local-to-heroku-app)
  * [Admin console](#user-content-admin-console)
  * [Admin API](#user-content-admin-api)
    * [The API Key](#user-content-admin-api-key)
    * [Accessing](#user-content-accessing-the-external-admin-api)
    * [Disabling](#user-content-disabling-the-external-admin-api)
  * [Terraform](#user-content-terraform)
  * [Upgrade guide](#user-content-upgrade-guide)
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
Kong is an extensible [web proxy](https://en.m.wikipedia.org/wiki/Proxy_server) based on [OpenResty](http://openresty.org/en/), a web app framework built on the embedded [Lua language](http://www.lua.org) capabilities of the [Nginx web server](http://nginx.org/en/).

With Heroku, Kong may be used for a variety of purposes. A few examples:

  * unify access control & observability for a suite of microservices
  * enforce request rate & size limits globally, based on the endpoint, or the authenticated consumer
  * create a single management point for routing requests based on DNS hostnames, URL paths, and HTTP headers

🦍 Visit [Kong HQ](https://konghq.com), the official resource for everything Kong.

Usage
-----

### Deploy

Use the deploy button to create a Kong app in your Heroku account:

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

### Connect local to Heroku app

To make changes to the Kong app's source, clone and connect this repo (or your own fork) to the Heroku app:

```bash
git clone https://github.com/heroku/heroku-kong.git
cd heroku-kong

# Use the name of the Heroku app:
heroku git:remote --app $APP_NAME
heroku info
```

### Admin console

To gain local console access to Kong deployed on Heroku, see [ADMIN](ADMIN.md).

Console access is primarily useful for performing `kong` CLI commands against the deployed app. Most administrative features do not require console access and instead are available through the Kong Admin API.

### Admin API

When this app is deployed to Heroku, it automatically provisions a protected, external-facing [loopback proxy](https://docs.konghq.com/1.0.x/secure-admin-api/#kong-api-loopback) to [Kong's Admin API](https://docs.konghq.com/1.0.x/admin-api/), secured by the `KONG_HEROKU_ADMIN_KEY` config var.

#### Admin API key

`KONG_HEROKU_ADMIN_KEY` is generated automatically when this app is [deployed using the automated app setup](#user-content-deploy).

You can explicitly set a new admin key value:

```bash
heroku config:set KONG_HEROKU_ADMIN_KEY=xxxxx
```

⚠️ **Always set a unique, cryptographically strong key value.** A weak admin key may result in the proxy being compromised and abused by malicious actors.

#### Accessing the external Admin API

Make HTTPS requests using a tool like [`curl`](https://curl.haxx.se) or [Paw.cloud](https://paw.cloud):

1. Base URL of the app's [Kong Admin API](https://docs.konghq.com/1.0.x/admin-api/) is `https://$APP_NAME.herokuapp.com/kong-admin`
2. Set the current [admin key](#user-content-admin-api-key) in the `apikey` HTTP header

For example, set the current admin key into a local shell variable:

```bash
KONG_HEROKU_ADMIN_KEY=`heroku config:get KONG_HEROKU_ADMIN_KEY`
```

Now use the following HTTP request style to interact with the [Kong's Admin API](https://docs.konghq.com/1.0.x/admin-api/):

✏️ *Replace the variable `$APP_NAME` with value for your unique deployment.*

```bash
curl -H "apikey: $KONG_HEROKU_ADMIN_KEY" https://$APP_NAME.herokuapp.com/kong-admin/status
```

#### Disabling the external Admin API

If you prefer to only use the [console-based Admin API](ADMIN.md), then this externally-facing proxy can be disabled:

```bash
curl -H "apikey: $KONG_HEROKU_ADMIN_KEY" https://$APP_NAME.herokuapp.com/kong-admin/services/kong-admin/routes
# For the returned Route's `id`,
curl -H "apikey: $KONG_HEROKU_ADMIN_KEY" -X DELETE https://$APP_NAME.herokuapp.com/kong-admin/routes/$ROUTE_ID
# Now there's no longer admin access!
# Finally, clear out the old admin key value.
heroku config:unset KONG_HEROKU_ADMIN_KEY
```

### Terraform

Kong may be provisioned and configured on Heroku using [Hashicorp Terraform](https://www.terraform.io) and a third-party [Kong provider](https://github.com/kevholditch/terraform-provider-kong).

See these examples of [Using Terraform with Heroku](https://devcenter.heroku.com/articles/using-terraform-with-heroku):

* [Common Runtime microservices with a unified gateway](https://github.com/mars/terraform-heroku-common-kong-microservices)
* [Private Spaces microservices with a unified gateway](https://github.com/mars/terraform-heroku-enterprise-kong-microservices)

### Upgrade guide

🚨 **Potentially breaking changes.** Please attempt upgrades on a staging system before upgrading production.

#### The buildpack

[Buildpack v6.0.0](https://github.com/heroku/heroku-buildpack-kong/releases) supports rapid deployments using a
pre-compiled Kong binary. A pre-existing, customized app may require changes continue functioning, if the app explicitly uses the `/app/.heroku` directory prefix.

[Buildpack v7.0.0-rc\*](https://github.com/heroku/heroku-buildpack-kong/releases) supports Kong 1.0 release candidates. The "rc" releases only support upgrading from Kong 0.14, not earlier versions or other release candidates.

[Buildpack v7.0.0](https://github.com/heroku/heroku-buildpack-kong/releases) supports Kong 1.0.

▶️ See [UPGRADING the buildpack](https://github.com/heroku/heroku-buildpack-kong/blob/master/UPGRADING.md).

#### Kong

First, see [Kong's official upgrade path](https://github.com/Kong/kong/blob/master/UPGRADE.md).

Then, take into account these facts about how this Kong on Heroku app works:

* this app automatically runs `kong migrations up` for every deployment
* you may prevent the previous version of Kong from attempting to use the new database schema during the upgrade (this will cause downtime):
   1. check the current formation size with `heroku ps`
   1. scale the web workers down `heroku ps:scale web=0`
   1. [perform the upgrade](https://github.com/Kong/kong/blob/master/UPGRADE.md)
   1. allow release process to run
   1. finally restart to the original formation size `heroku ps:scale web=$PREVIOUS_SIZE`
* once Kong 1.0 is successfully deployed, execute: `
heroku run "kong migrations finish --conf /app/config/kong.conf"`

🏥 Please [open an issue](https://github.com/heroku/heroku-kong/issues), if you encounter problems or have feedback about this process.


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

👓 See: [Kong 1.0 Configuration Reference](https://docs.konghq.com/1.0.x/configuration/)


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
curl http://localhost:8001/services/ -i -X POST \
  --data 'name=bay-lights' \
  --data 'protocol=https' \
  --data 'port=443' \
  --data 'host=bay-lights-api-production.herokuapp.com'
# Note the Service ID returned in previous response, use it in place of `$SERVICE_ID`.
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=request-size-limiting' \
  --data "config.allowed_payload_size=8" \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=rate-limiting' \
  --data "config.minute=5" \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/routes/ -i -X POST \
  --data 'paths[]=/bay-lights' \
  --data "service.id=$SERVICE_ID"
```

### Demo: custom plugin: hello-world-header

[Custom plugins](https://docs.konghq.com/1.0.x/plugin-development/) allow you to observe and transform HTTP traffic using lightweight, high-performance [Lua](http://www.lua.org) code in Nginx [request processing contexts](https://docs.konghq.com/1.0.x/plugin-development/custom-logic/#available-request-contexts). Building on the [previous example](#user-content-demo-api-rate-limiting), let's add a simple plugin to Kong.

[hello-world-header](lib/kong/plugins/hello-world-header/handler.lua) will add an HTTP response header **X-Hello-World** showing the date and a message from an environment variable.

Activate this plugin for the API:

```bash
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=hello-world-header' \
  --data "service.id=$SERVICE_ID"
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
# Via: kong/0.14.0, 1.1 vegur
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
curl http://localhost:8001/services/ -i -X POST \
  --data 'name=ndfd-max-temps' \
  --data 'protocol=https' \
  --data 'port=443' \
  --data 'host=graphical.weather.gov' \
  --data 'path=/xml/SOAP_server/ndfdXMLserver.php'
# Note the Service ID returned in previous response, use it in place of `$SERVICE_ID`.
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=request-size-limiting' \
  --data "config.allowed_payload_size=8" \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=rate-limiting' \
  --data "config.minute=5" \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=ndfd-xml-as-json' \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/routes/ -i -X POST \
  --data 'paths[]=/ndfd-max-temps' \
  --data "service.id=$SERVICE_ID"
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

* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [Heroku](https://www.heroku.com/home)
  * [command-line tools (CLI)](https://toolbelt.heroku.com)
  * [a free account](https://signup.heroku.com)
* Kong & its dependencies
  * as a single package install
    * [Kong](https://docs.konghq.com/install/macos/) for macOS
  * or, from source
    * [Lua](https://www.lua.org/versions.html) 5.1
    * [LuaRocks](https://github.com/luarocks/luarocks) 2.4.4
    * [OpenSSL](https://www.openssl.org/source/) 1.1.1
    * [OpenResty](https://openresty.org/en/installation.html) 1.13.6.2
      * [Install from source](https://docs.konghq.com/install/source/)
      * `./configure -j2 --with-openssl=~/Downloads/openssl-1.1.1a --with-http_realip_module --with-http_stub_status_module`
    * [Kong](https://github.com/Kong/kong) 1.0.0
      * `luarocks install kong 1.0.0 OPENSSL_DIR=/usr/local/opt/openssl CRYPTO_DIR=/usr/local/opt/openssl`

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
  * [Kong plugin testing guide](https://docs.konghq.com/1.0.x/plugin-development/tests/)
  * [buildpack requirements for testing](https://github.com/heroku/heroku-buildpack-kong/blob/master/README.markdown#user-content-testing)

```bash
bin/test
```
