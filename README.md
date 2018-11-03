# lua-bodge

This is lua 5.4 with some additional libraries included
- luafilesystem
- libuv + luv bindings
- sqlite3 + lsqlite bindings
- inspect.lua
- PenLight

Compiling lua-amalgamation.c on Linux should yield a lua interpreter with the above libraries available via require. Other platforms are left as an exercise for the reader.

The scripts that cobble these files together are neither idiomatic nor robust. This represents an existence proof that it is ridiculously easy to embed C or lua libraries into the lua interpreter, even if one hasn't taken the time to learn any lua before attempting to do so. Running rebuild.lua with an interpreter that has luafilesystem available (e.g. from the host OS, from luarocks, from an existing amalgamation) should write the contents of lua-amalgamation.c to stdout.

A number of minor changes were needed to get the libraries to coexist in a single source file, e.g. renaming functions and types. The upstream folder contains a copy of the unmodified source for use with diff. The upstream code has various permissive licenses. The single source file is broadly equivalent to separately compiling each library then linking them together - AFAIU this doesn't require it's own license.

TODO: Add a script that runs the various test suites.
