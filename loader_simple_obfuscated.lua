-- Aurum Loader (ofuscado) - RAMA arena/01a06a0a-aurum - Pega en executor
-- URL de TU RAMA ofuscada via string.char (main está vacía)
(loadstring or load)(game:HttpGet(string.char(104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,88,122,65,110,103,101,108,49,57,47,65,117,114,117,109,47,97,114,101,110,97,47,48,49,97,48,54,97,48,97,45,97,117,114,117,109,47,65,117,114,117,109,46,108,117,97)))()
-- universal fallback:
--[[
local u=string.char(104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,88,122,65,110,103,101,108,49,57,47,65,117,114,117,109,47,97,114,101,110,97,47,48,49,97,48,54,97,48,97,45,97,117,114,117,109,47,65,117,114,117,109,46,108,117,97)
local s; local ok=pcall(function() s=game:HttpGet(u) end)
if not ok or #s<100 then local r=(syn and syn.request) or http_request or request; if r then local o=r({Url=u,Method="GET"}) s=o.Body or o.body or o end end
if s and #s>100 then loadstring(s)() end
--]]
