Admin Console for Kong on Heroku
================================
Console access is primarily useful for performing `kong` CLI commands against the deployed app. Most administrative features do not require console access and instead are available through the [Kong Admin API](README.md#user-content-admin-api).

### Admin console

Use Kong CLI and the Admin API in a [one-off dyno](https://devcenter.heroku.com/articles/one-off-dynos):

✏️ *Replace `$APP_NAME` with the Heroku app name.*

```bash
heroku run bash --app $APP_NAME

# Run Kong in the background of the one-off dyno:
~ $ bin/background-start

# Then, use `curl` to issue Admin API commands
# and `jq` to format the output:
# (Note: the `$KONG_ADMIN_LISTEN` variable is already defined)
~ $ curl http://$KONG_ADMIN_LISTEN | jq .

# Example CLI commands:
# (Note: some commands require the config file and others the prefix)
# (Note: the `$KONG_CONF` variable is already defined)
~ $ kong migrations list -c $KONG_CONF
~ $ kong health -p /app/kong-runtime
```

### Proxy & protect the Admin API
Kong's Admin API has no built-in authentication. Its exposure must be limited to a restricted, private network. For Kong on Heroku, the Admin API listens privately on `localhost:8001`.

To make Kong Admin accessible from other locations, let's setup a secure [loopback proxy](https://docs.konghq.com/0.14.x/secure-admin-api/#kong-api-loopback) with key authentication, HTTPS-enforcement, and request rate & size limiting.

⚠️ **This [Admin API proxy is generated automatically](README.md#user-content-admin-api) during the initial deployment's release**, if the `KONG_HEROKU_ADMIN_KEY` config var is set, such as when [using the automated app setup](README.md#user-content-deploy).

From the [admin console](#user-content-admin-console):
```bash
# Create the authenticated `/kong-admin` API, targeting the localhost port:
curl http://localhost:8001/services/ -i -X POST \
  --data 'name=kong-admin' \
  --data 'protocol=http' \
  --data 'port=8001' \
  --data 'host=localhost'
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
  --data 'name=key-auth' \
  --data "config.hide_credentials=true" \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/plugins/ -i -X POST \
  --data 'name=acl' \
  --data "config.whitelist=kong-admin" \
  --data "service.id=$SERVICE_ID"
curl http://localhost:8001/routes/ -i -X POST \
  --data 'paths[]=/kong-admin' \
  --data 'protocols[]=https' \
  --data "service.id=$SERVICE_ID"

# Create a consumer with username and authentication credentials:
curl http://localhost:8001/consumers/ -i -X POST \
  --data 'username=heroku-admin'
curl http://localhost:8001/consumers/heroku-admin/acls -i -X POST \
  --data 'group=kong-admin'
curl http://localhost:8001/consumers/heroku-admin/key-auth -i -X POST -d ''
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
