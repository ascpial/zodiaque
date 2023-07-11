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
--- Returns a string representing the specified table
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

--- Returns the table contained in a string
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
