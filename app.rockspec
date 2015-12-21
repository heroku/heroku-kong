-- app.rockspec
config = {
  external_deps_dirs = {
   "/app/.apt/usr/local",
   "/app/.apt/usr",
   "/usr"
  },
  external_deps_subdirs = {
    "bin",
    "include",
    "lib",
    "lib/x86_64-linux-gnu"
  }
}
dependencies = {
  "etlua",
  "kong ~> 0.5"
}
