etlua = require "etlua"

-- 12-factor config generator for Kong
-- execute with `lua kong-12f.lua`

-- Reads envirnoment variables for runtime config
cassandra_url     = os.getenv("CASSANDRA_URL")
cassandra_cert    = os.getenv("CASSANDRA_TRUSTED_CERT")
assignedPort      = os.getenv("PORT")
exposeService     = os.getenv("KONG_EXPOSE") -- `proxy` (default), `admin`, `proxyssl`, `dnsmasq`

-- Dependent on Dockerfile placing config template in the same directory
templateFilename  = "kong.yml.etlua"
configFilename    = "kong.yml"
certFilename      = "cassandra.cert"

-- Configure the service to expose on PORT
if exposeService == "admin" then
  print("Configuring as Kong admin API")
  proxy_port = 1 + assignedPort
  proxy_ssl_port = 2 + assignedPort
  admin_api_port = assignedPort
  dnsmasq_port = 3 + assignedPort
elseif exposeService == "proxyssl" then
  print("Configuring as Kong SSL proxy")
  proxy_port = 1 + assignedPort
  proxy_ssl_port = assignedPort
  admin_api_port = 2 + assignedPort
  dnsmasq_port = 3 + assignedPort
elseif exposeService == "dnsmasq" then
  print("Configuring as Kong dnsmasq")
  proxy_port = 1 + assignedPort
  proxy_ssl_port = 2 + assignedPort
  admin_api_port = 3 + assignedPort
  dnsmasq_port = assignedPort
else
  print("Configuring as Kong proxy")
  proxy_port = assignedPort
  proxy_ssl_port = 1 + assignedPort
  admin_api_port = 2 + assignedPort
  dnsmasq_port = 3 + assignedPort
end

-- Expand the comma-delimited list of Cassandra nodes
cassandra_hosts     = {}
for user, password, host, keyspace in string.gmatch(cassandra_url, "cassandra://([^:]+):([^@]+)@([^/]+)/([^,]+)") do
  cassandra_user      = user
  cassandra_password  = password
  cassandra_keyspace  = keyspace
  table.insert(cassandra_hosts, host)
end

-- Render the Kong configuration file
templateFile = io.open(templateFilename, "r")
template = etlua.compile(templateFile:read("*a"))
templateFile:close()

config = template({
  proxy_port          = proxy_port,
  proxy_ssl_port      = proxy_ssl_port,
  admin_api_port      = admin_api_port,
  dnsmasq_port        = dnsmasq_port,
  cassandra_hosts     = cassandra_hosts,
  cassandra_user      = cassandra_user,
  cassandra_password  = cassandra_password,
  cassandra_keyspace  = cassandra_keyspace,
  cassandra_cert      = certFilename
})

file = io.open(configFilename, "w")
file:write(config)
file:close()

file = io.open(certFilename, "w")
file:write(cassandra_cert)
file:close()
