local bin2c = {
   _description = [[
Derived from a standalone lua program named bin2c.lua found on the lua-users wiki
]],
}  
   
local function getname(filename)
   return filename:gsub("^./",""):gsub(".lua","")
end

function bin2c.getcname(filename)
   return string.gsub(getname(filename),"/","__")
end

function bin2c.getlname(filename)
   return string.gsub(getname(filename),"/",".")
end


local function generate_luacode(filename)
   local cname = bin2c.getcname(filename)
   local lname = bin2c.getlname(filename)

   local header = [[
static const unsigned char luacode_]]..cname..[[[] = {
]]
   local footer = '\n};\n'

   -- Compile the file to assert on syntax errors, but otherwise ignore the bytecode
   local compiled = assert(loadfile(filename))

   -- Embed as source for greater portability
   local content = assert(io.open(filename,"rb")):read"*a"

   local dump do
      local numtab={}; for i=0,255 do numtab[string.char(i)]=("%3d,"):format(i) end
      function dump(str)
         return (str:gsub(".", numtab):gsub(("."):rep(80), "%0\n"))
      end
   end

   return header .. dump(content) .. footer
end


local function generate_luaopen(filename)
   local cname = bin2c.getcname(filename)
   local lname = bin2c.getlname(filename)

   return  [[
static int luaopen_]]..cname..[[(lua_State* L) {
  int arg = lua_gettop(L);
  const size_t sz = sizeof(luacode_]]..cname..[[);
  const char * code = (const char*)luacode_]]..cname..[[;
  if(luaL_loadbuffer(L,code,sz,"]]..lname..[[")) {
    return lua_error(L);
  }
  lua_insert(L,1);
  lua_call(L,arg,1);
  return 1;
}
]]
end

function bin2c.lua_register_function_name(filename)
   local cname = bin2c.getcname(filename)
   return [[luaregister_]]..cname
end

local function generate_luaregister(filename)

   local cname = bin2c.getcname(filename)
   local lname = bin2c.getlname(filename)

   return
      [[
void ]]..bin2c.lua_register_function_name(filename)..[[(lua_State* L)
{
  lua_pushcfunction(L, luaopen_]]..cname..[[);
  lua_setfield(L, -2, "]]..lname..[[");
}
]]
end

function bin2c.generate(filename)
   local res = ''
   res = res .. [[/* Generated from ]]..filename..[[*/]]
   res = res .. '\n' .. '#include "lua.h"'
   res = res .. '\n' .. '#include "lauxlib.h"'
   res = res .. '\n' .. generate_luacode(filename)
   res = res .. '\n' .. generate_luaopen(filename)
   res = res .. '\n' .. generate_luaregister(filename)
   return res
end


return bin2c
