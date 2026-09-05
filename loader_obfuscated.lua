-- loader_obfuscated.lua | Aurum v1.1 (ofuscado) - RAMA arena/01a06a0a-aurum
-- Pega esto tal cual en tu executor
local a=string.char;local b=loadstring or load;local c=game;local d=c.HttpGet
local function f(g)
 local h,i=pcall(function() return d(c,g) end)
 if h and type(i)=="string" and #i>100 then return i end
 local j=(syn and syn.request) or http_request or request or (fluxus and fluxus.request)
 if type(j)=="function" then
  local k,l=pcall(j,{Url=g,Method="GET"})
  if k and l then local m=l.Body or l.body; if type(m)=="string" and #m>100 then return m end; if type(l)=="string" and #l>100 then return l end end
 end
 return nil
end
local n=a(104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,88,122,65,110,103,101,108,49,57,47,65,117,114,117,109,47,97,114,101,110,97,47,48,49,97,48,54,97,48,97,45,97,117,114,117,109,47,65,117,114,117,109,46,108,117,97)
local o=f(n)
if not o or #o<100 then o=f(a(104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,88,122,65,110,103,101,108,49,57,47,65,117,114,117,109,47,97,114,101,110,97,47,48,49,97,48,54,97,48,97,45,97,117,114,117,109,47,108,111,97,100,101,114,46,108,117,97))
end
if not o or #o<100 then
 if type(readfile)=="function" and type(isfile)=="function" then
  if isfile("Aurum/Aurum.lua") then o=readfile("Aurum/Aurum.lua")
  elseif isfile("Aurum.lua") then o=readfile("Aurum.lua") end
 end
end
if not o or #o<100 then error("[aurum] error") end
local p,q=b(o)
if not p then error(q) end
return p()
