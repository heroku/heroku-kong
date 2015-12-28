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

* web (start Kong): `kong-12f && kong start -c config/kong.yml`
* shell (interactive CLI): `heroku run kong-12f && bash`
* initialize DB schema (interactive CLI): `heroku run kong-12f && kong migrations reset -c config/kong.yml`

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
