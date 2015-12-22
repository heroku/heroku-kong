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
  root_dir = "/app/.apt/usr/local",
  rocks_dir = "/app/.apt/usr/local/lib/luarocks/rocks",
  deploy_bin_dir = "/app/.apt/usr/local/bin",
  deploy_lua_dir = "/app/.apt/usr/local/lib/lua/5.1",
  deploy_lib_dir = "/app/.apt/usr/local/lib"
}
dependencies = {
  "etlua",
  "kong ~> 0.5"
}
