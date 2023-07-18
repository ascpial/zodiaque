local blacklisted = {}
blacklisted['client.lua'] = true
blacklisted['server.lua'] = true
blacklisted['snooper.lua'] = true

local function github_get(user, repo, target, blacklist, subfolder)
  print("Downloading Github repository "..user.."/"..repo)
  local github_api = http.get("https://api.github.com/repos/"..user.."/"..repo.."/git/trees/main?recursive=1")
  if github_api == nil then error("The repo "..user.."/"..repo.." does no exists...") end
  local list = textutils.unserialiseJSON(github_api.readAll())
  local ls = {}
  local len = 0
  github_api.close()
  for k,v in pairs(list.tree) do
    if v.type == "blob" and v.path:lower():match(".+%.lua") then
      if blacklist[v.path] ~= true then
        if subfolder == nil then
          ls["https://raw.githubusercontent.com/"..user.."/"..repo.."/main/"..v.path] = v.path
          len = len + 1
        else
          local indexs = string.find(v.path, subfolder)
          if indexs ~= nil and indexs == 1 then
            ls["https://raw.githubusercontent.com/"..user.."/"..repo.."/main/"..v.path] = string.sub(v.path, #subfolder + 1, -1)
            len = len + 1
          end
        end
      end
    end
  end
  local percent = 100/len
  local finished = 0
  for k,v in pairs(ls) do
    local web = http.get(k)
    local file = fs.open(target.."/"..v,"w")
    file.write(web.readAll())
    file.close()
    web.close()
    finished = finished + 1
    print("Downloading "..v.."  "..tostring(math.ceil(finished*percent)).."%")
  end
end

fs.makeDir("/zodiaque")
github_get('ascpial', 'zodiaque', '/zodiaque', blacklisted, 'zodiaque/')
fs.makeDir("/ccryptolib")
fs.makeDir("/ccryptolib/internal")
github_get('migeyel', 'ccryptolib', '/ccryptolib', {}, 'ccryptolib/')

print("The zodiaque project and its dependencies have been correctly installed.")
