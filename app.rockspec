-- app.rockspec
config = {
  external_deps_dirs = {
   "/app/.apt/usr/lib/x86_64-linux-gnu",
   "/app/.apt/usr/local/lib",
   "/app/.apt/usr/lib",
   "/usr/lib/x86_64-linux-gnu",
   "/usr/lib"
  }
}
dependencies = {
  "etlua",
  "kong ~> 0.5"
}
