-- app.rockspec
config = {
  external_deps_dirs = {
   "/app/.apt/usr/local",
   "/app/.apt/usr",
   "/usr",
   "/"
  },
  external_deps_subdirs = {
    bin = "bin",
    include = "include",
    lib = {"lib", "lib/x86_64-linux-gnu"}
  },
  rocks_trees = {{
    root = "/app/.apt/usr/local",
    bin_dir = "/app/.apt/usr/local/bin",
    lib_dir = "/app/.apt/usr/local/lib",
    lua_dir = "/app/.apt/usr/local/share/lua/5.1"
  }}
}
dependencies = {
  "etlua",
  "kong ~> 0.5"
}
