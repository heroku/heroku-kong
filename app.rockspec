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
  rocks_trees = {
    { name = [[system]], root = [[/app/.apt/usr/local]] }
  }
}
dependencies = {
  "etlua",
  "kong ~> 0.5"
}
