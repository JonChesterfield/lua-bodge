--[[
 Problems found...
LUAMOD_API is defined in luaconf.h, used in lfs.h, which doesn't include it
lfs.h also requires lua.h, didn't notice because I'm not including lfs.h anywhere
ltests.h has various problems with this compilation strategy, eliding it
my XOPEN_SOURCE 700 to support musl in lfs.c conflicts with a definition in lprefix.h
ltm.h includes lstate.h and lstate.h includes ltm.h
]]

local lfs = require 'lfs'
local bin2c = require 'tools/bin2c'
local gen = require 'tools/generate_c_files'

local filecontents = {}
local subdirs = {'lua', 'luafilesystem', 'libuv', 'luv', 'lsqlite',}
-- Populate with files from within subdirs
for _, subdir in pairs(subdirs) do
   local src = gen.listfiles('./'..subdir)
   for l,n in ipairs(src) do
      if gen.string_ends(n,'.c') or gen.string_ends(n,'.h') then
         if not n:match('ltest') then -- tests do not play nice with the amalgamation
            local f = assert(io.open(n,'rb'))
            local idx = '"'..n:gsub('^./' .. subdir .. '/','')..'"'

            if filecontents[idx] ~= nil then
               print('Error: Cannot handle duplicate file name (yet):' .. idx)
               os.exit(1)
            end
            
            -- print('Storing filecontents of ' .. idx)
            filecontents[idx] = f:read("*all")
            f:close()
         end
      end
   end
end

-- Extend with files generated from within scripts
-- and the files "preloader.c" and "preloader.h"
local cfn = gen.generate()
for filename,contents in pairs(cfn) do
   local k = '"'..filename..'"'
   assert(filecontents[k] == nil)
   filecontents[k] = contents
end


function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end
function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end
function string.trim(s)
  return s:match "^%s*(.-)%s*$"
end


function setContains(set, key)
    return set[key] ~= nil
end


local function get_include_string_from_line(line)
   local include_pattern = '^#%s*include%s*'
   local include_filename_pattern = '\".*\"'

   local function line_contains_include(line)
      return line:match(include_pattern)
   end
      
   local m = line_contains_include(line)
   if m then
      local s = string.trim(line:gsub(include_pattern,''))
      return s:match(include_filename_pattern)
   end
   return nil
end

local includes = {}
for k,v in pairs(filecontents) do
   if not includes[k] then includes[k] = {} end
   for line in v:gmatch("[^\r\n]*") do
      local ik = get_include_string_from_line(line)
      if ik then
         local fc = filecontents[ik]
         if fc then
            includes[k][ik] = true
         end
      end
   end
end

local schedule = {}
local already_scheduled = {}
local function schedule_include(k)
   if not already_scheduled[k] then
      table.insert(schedule,k)
      already_scheduled[k] = true
   end
   -- order unimportant for removing values
   for kn,vn in pairs(includes) do
      if vn[k] then
         vn[k] = nil
      end
   end
end

-- force lprefix.h to come first. luaconf.h needs _XOPEN_SOURCE defined
-- before it includes some standard headers to build with clang
-- luaconf.h is the obvious place for #define LUA_USE_POSIX.
-- This define needs to go before any of the includes
schedule_include('"lprefix.h"')

-- force luaconf.h to come early for convenient editing of the amalgamation
schedule_include('"luaconf.h"')

-- deterministic inclusion order is useful for diff when regenerating
local include_keys = {}
for k in pairs(includes) do table.insert(include_keys, k) end
table.sort(include_keys)

-- this is a minimal-effort ordering algorithm. it may need modification
-- when adding more libraries.
local keep_going = true
while keep_going do
   keep_going = false
   local progress = false   
   for _,k in ipairs(include_keys) do
      local v = includes[k]
      if next(v) == nil then
         if not already_scheduled[k] then
            progress = true
         end
         schedule_include(k)
      end
      if next(includes[k]) ~= nil then
         keep_going = true
      end
   end

   if not progress then
      print("Scheduling failure")
      local inspect = require 'inspect'
      if inspect then
         print(inspect(schedule_include))
         print(inspect(includes))
      end
      os.exit(1)
   end
end

print([[
/* Amalgamation begins */
/* Various licenses, see upstream folder for details */
/* This file was constructed by ./lua rebuild.lua &> lua-amalgamation.c */
/* files are embedded in the following order */]])
for _,v in ipairs(schedule) do
   print('/* '..v..' */')
end
print([[
#ifndef MAKE_LIB
#ifndef MAKE_LUAC
#ifndef MAKE_LUA
#define MAKE_LUA
#endif
#endif
#endif
#define LUA_USE_POSIX
]])

-- Scheduling all headers before all source means that
-- lprefix.h will have been included before any source
-- that #includes <stdio.h>

for _,suffix in ipairs({'.h"', '.c"'}) do
for _,i in ipairs(schedule) do
   if string.ends(i,suffix) then
      print('/* Begin include of ' .. i .. ' */')
      local fc = filecontents[i]
      if fc == nil then
         print('/* Warning: ' .. i .. ' not found, cannot include */')
      else         
         for line in fc:gmatch("[^\r\n]*") do
            local needs_comment = false
            local ik = get_include_string_from_line(line)
            if ik and filecontents[ik] then
               needs_comment = true
            end
            if needs_comment then
               print("#if 0 /* Include disabled by amalagamation script */")
               print(line)
               print("#endif")
            else
               print (line)
            end           
         end
      end
      print('/* Finish include of ' .. i .. ' */')
   end

   if string.ends(i,'.c"') then
   end
end

end

print("/* Amalgamation complete */")
