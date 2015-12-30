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

Kong is configured via environment vars:

* `CASSANDRA_URL`
* `CASSANDRA_TRUSTED_CERT`
* `PORT`

### Protecting the Admin API
Kong's Admin API has no built-in authentication. Its exposure must be limited to a restricted, private network.

For Kong on Heroku, the Admin API listens on the dyno's localhost port 8001; set in [`config/kong.yml.etlua`](/heroku/heroku-kong/blob/master/config/kong.yml.etlua) `admin_api_port`.

#### Access via Heroku console
In a one-off dyno console, start Kong, and make requests to the Admin API:

```bash
$ heroku run bash
> kong-12f && kong start -c config/kong.yml &
# …Kong will start in the background, still writing to the console.
> curl localhost:8001
```

#### Authenticated Admin API
Using Kong itself, you may expose an authenticated, rate-limited, proxy to the Admin API.


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
curl -i -X POST --url http://localhost:8001/apis/ --data 'name=bay-lights' --data 'upstream_url=https://bay-lights-api-production.herokuapp.com/' --data 'request_path=/bay-lights' --data 'strip_request_path=true'
curl -i -X POST --url http://localhost:8001/apis/bay-lights/plugins/ --data 'name=request-size-limiting' --data "config.allowed_payload_size=8"
curl -i -X POST --url http://localhost:8001/apis/bay-lights/plugins/ --data 'name=rate-limiting' --data "config.minute=5"
```

