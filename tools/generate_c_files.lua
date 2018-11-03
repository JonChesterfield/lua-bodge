local lfs = require 'lfs'
local bin2c = require 'tools/bin2c'

local DIRSEP = '/'

local this = {}

function this.listfiles(dir,list)
   list = list or {}	-- use provided list or create a new one
   for entry in lfs.dir(dir) do
      if entry ~= "." and entry ~= ".." then
         local ne = dir .. DIRSEP .. entry
         attr = lfs.attributes(ne)
         if attr then
            if lfs.attributes(ne).mode == 'directory' then
               this.listfiles(ne,list)
            else
               table.insert(list,ne)
            end
         end
      end
   end
      
   return list
end

function this.string_ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

local function get_preloader_header()
   return [[
#ifndef PRELOADER_H_INCLUDED
#define PRELOADER_H_INCLUDED

#include "lua.h"
#include "lauxlib.h"
void preload_modules(lua_State * L);

#endif
]]
end

local function get_preloader_source(script_function_names)
   local res = [[
#include "preloader.h"
]]
   for l,n in ipairs(script_function_names) do
      res = res .. '\n' .. [[void ]]..n..[[(lua_State*L);]]
   end

   res = res .. '\n' .. [[
void preload_modules(lua_State * L)
{
  luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);]]

   for l,n in ipairs(script_function_names) do
      res = res .. '\n  ' ..n..'(L);'
   end
   
  res = res .. '\n' .. [[
  lua_pop(L, 1);  /* remove PRELOAD table */
}
]]
   return res
end

function this.generate()
   assert(lfs.chdir('scripts'))
   local tab = {}
   local script_function_names = {}
   for l,n in ipairs(this.listfiles(".")) do
      if this.string_ends(n,".lua") then
         local bin2ced = bin2c.generate(n)
         local cfn = bin2c.getcname(n) .. ".c"
         tab[cfn] = bin2ced        
         table.insert(script_function_names,bin2c.lua_register_function_name(n))
      end
   end
   tab["preloader.c"] = get_preloader_source(script_function_names)
   tab["preloader.h"] = get_preloader_header()
   assert(lfs.chdir('..'))
   return tab
end

return this



