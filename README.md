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

### Environment

* Kong config via environment variables
  * `CASSANDRA_URL`
  * `CASSANDRA_TRUSTED_CERT`
  * `PORT`
  * `KONG_EXPOSE`
* Parses the `CASSANDRA_URL` as a comma-delimited list of contact points with the format:
  ```
  cassandra://username:password@x.x.x.x:port/keyspace,cassandra://username:password@y.y.y.y:port/keyspace
  ```
* Exposes a single service per instance (app/dyno)
  * `KONG_EXPOSE=proxy` for the gateway (default)
  * `KONG_EXPOSE=admin` for the Admin API


### Protecting the Admin API
Kong's Admin API has no built-in authentication. Its exposure must be limited to a restricted, private network.

#### Heroku public cloud
Within a one-off dyno console, start Kong and connect to the localhost-only port.

```bash
$ heroku run bash
> KONG_EXPOSE=admin PORT=8000 kong-12f && kong start -c config/kong.yml &
# …Kong will start in the background, still writing to the console.
> curl localhost:8000
```

#### Heroku Private Space
Run a secondary app with `KONG_EXPOSE=admin` config var, and use inbound IP restrictions (once support is available) to restrict network exposure.


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

*Commands run via the [protected Admin API within Heroku's public cloud](#heroku-public-cloud)*

```bash
curl -i -X POST --url http://localhost:8000/apis/ --data 'name=bay-lights' --data 'upstream_url=https://bay-lights-api-production.herokuapp.com/' --data 'request_path=/bay-lights' --data 'strip_request_path=true'
curl -i -X POST --url http://localhost:8000/apis/bay-lights/plugins/ --data 'name=request-size-limiting' --data "config.allowed_payload_size=8"
curl -i -X POST --url http://localhost:8000/apis/bay-lights/plugins/ --data 'name=rate-limiting' --data "config.minute=5"
```

