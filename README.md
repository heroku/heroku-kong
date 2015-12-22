Kong
====

**Non-functional**: reference only.

This was an experiment using the existing Lua buildpack to run Kong. Unfortunately the prebuilt Lua & LuaRocks binaries' were built with the prefix `/usr/local` which is not compatible with the dynos' read-only root filesystem.