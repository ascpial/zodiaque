--- This file uses code from the ComputerCraft lua rom, and so this file is licensed under the CCPL.
-- ComputerCraft Public License
-- ============================

-- Version 1.0.0 (Based on Minecraft Mod Public License 1.0.1)

-- 0. Definitions
-- --------------

-- Minecraft: Denotes a copy of the PC Java version of the game “Minecraft” licensed by Mojang AB

-- User: Anybody that interacts with the software in one of the following ways:
--    - play
--    - decompile
--    - recompile or compile
--    - modify
--    - distribute

-- Mod: The mod code designated by the present license, in source form, binary
-- form, as obtained standalone, as part of a wider distribution or resulting from
-- the compilation of the original or modified sources.

-- Dependency: Code required for the mod to work properly. This includes
-- dependencies required to compile the code as well as any file or modification
-- that is explicitly or implicitly required for the mod to be working.

-- 1. Scope
-- --------

-- The present license is granted to any user of the mod. As a prerequisite,
-- a user must own a legally acquired copy of Minecraft

-- 2. Liability
-- ------------

-- This mod is provided 'as is' with no warranties, implied or otherwise. The owner
-- of this mod takes no responsibility for any damages incurred from the use of
-- this mod. This mod alters fundamental parts of the Minecraft game, parts of
-- Minecraft may not work with this mod installed. All damages caused from the use
-- or misuse of this mod fall on the user.

-- 3. Play rights
-- --------------

-- The user is allowed to install this mod on a Minecraft client or server and to play
-- without restriction.

-- 4. Modification rights
-- ----------------------

-- The user has the right to decompile the source code, look at either the
-- decompiled version or the original source code, and to modify it.

-- 5. Distribution of original or modified copy rights
-- ---------------------------------------------------

-- Is subject to distribution rights this entire mod in its various forms. This
-- include:
--    - original binary or source forms of this mod files
--    - modified versions of these binaries or source files, as well as binaries
--      resulting from source modifications
--    - patch to its source or binary files
--    - any copy of a portion of its binary source files

-- The user is allowed to redistribute this mod partially, in totality, or
-- included in a distribution.

-- When distributing binary files, the user must provide means to obtain its
-- entire set of sources or modified sources at no cost.

-- All distributions of this mod must remain licensed under the CCPL.

-- All dependencies that this mod have on other mods or classes must be licensed
-- under conditions comparable to this version of CCPL, with the exception of the
-- Minecraft code and the mod loading framework (e.g. Forge).

-- Modified version of binaries and sources, as well as files containing sections
-- copied from this mod, should be distributed under the terms of the present
-- license.

-- 7. Use of mod code and assets in other projects
-- -----------------------------------------------

-- It is permitted to use the code and assets contained in this mod (and modified
-- versions thereof) in other Minecraft Mods, provided they are non-commercial.
-- However: the code and assets may not be used in commercial mods, mods for other
-- games, other games, other non-game projects, or any commercial projects.

-- When using code covered by this license in other projects, the source code used
-- must be made available at no cost and remain licensed under the CCPL.

-- 8. Contributing
-- ---------------

-- If you choose to contribute code or assets to be included in this mod, you
-- agree that, if added to to the main repository at
-- https://github.com/dan200/ComputerCraft, your contributions will be covered by
-- this license, and that Daniel Ratcliffe will retain the right to re-license the
-- mod, including your contributions, in part or in whole, under other licenses.

local random = require("ccryptolib.random")

--- Initialize ccryptolib random generator form random.org data
local function initRandom()
  random.init(http.get("https://www.random.org/integers/?num=1&min=1&max=100000000&col=5&base=10&format=plain&rnd=new").readAll())
end

--- Returns the keys of a table
--- @param t table
--- @return table keys
local function getKeys(t)
  local keys={}
  local n=0

  for k,v in pairs(t) do
    n=n+1
    keys[n]=k
  end
  return keys
end

--- A version of the ipairs iterator which ignores metamethods
local function inext(tbl, i)
    i = (i or 0) + 1
    local v = rawget(tbl, i)
    if v == nil then return nil else return i, v end
end

local g_tLuaKeywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

--- Function in the same way as next() but the order is always the same
local function orderedNext(t, i)
  local tableKeys = getKeys(t)
  table.sort(tableKeys, function(l, r)
    if type(l) ~= type(r) then
      return true
    end
    return l < r
  end)
  local found = false
  if i == nil then
    found = true
  end
  for key, value in pairs(tableKeys) do
    if found == true then
      return value, t[value]
    end
    if value == i then
      found = true
    end
  end
end

local serialize_infinity = math.huge
--- Return a string representing the specified table
--- @param t table The table to convert
--- @return string payload The converted string
local function serialize(t)
    local sType = type(t)
    if sType == "table" then
        local result
        if next(t) == nil then
            -- Empty tables are simple
            result = "{}"
        else
            -- Other tables take more work
            local open, open_key, close_key, equal, comma = "{", "[", "]=", "=", ","

            result = open
            local seen_keys = {}
            for k, v in inext, t do
                seen_keys[k] = true
                result = result .. serialize(v) .. comma
            end
            for k, v in orderedNext, t do
                if not seen_keys[k] then
                    local sEntry
                    if type(k) == "string" and not g_tLuaKeywords[k] and string.match(k, "^[%a_][%a%d_]*$") then
                        sEntry = k .. equal .. serialize(v) .. comma
                    else
                        sEntry = open_key .. serialize(k) .. close_key .. serialize(v) .. comma
                    end
                    result = result .. sEntry
                end
            end
            result = result .. "}"
        end

        return result

    elseif sType == "string" then
        return string.format("%q", t)

    elseif sType == "number" then
        if t ~= t then --nan
            return "0/0"
        elseif t == serialize_infinity then
            return "1/0"
        elseif t == -serialize_infinity then
            return "-1/0"
        else
            return tostring(t)
        end

    elseif sType == "boolean" or sType == "nil" then
        return tostring(t)

    else
        error("Cannot serialize type " .. sType, 0)

    end
end

--- Return the table contained in a string
--- @param payload string The string to convert
--- @return table t The table container in the string
local function unserialize(payload)
  return textutils.unserialize(payload)
end

--- Copy a table
--- @param t table The table to copy
--- @return table t2 the copy of the table
local function copyTable(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end


return {
  initRandom=initRandom,
  serialize=serialize,
  unserialize=unserialize,
  copyTable=copyTable,
}
