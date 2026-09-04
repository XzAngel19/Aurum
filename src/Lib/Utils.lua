-- src/Lib/Utils.lua | Aurum
-- Helpers compartidos por todos los módulos (ESP, Aim, Player, World)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Utils = {}

function Utils.isAlive(plr)
    local c = plr.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

function Utils.getChar(plr) return plr.Character end

function Utils.getRoot(plr)
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utils.getHead(plr)
    local c = plr.Character
    return c and c:FindFirstChild("Head")
end

-- pref: "Head" | "Torso" | "Closest" | "Random"
function Utils.getTargetPart(plr, pref)
    local c = plr.Character
    if not c then return nil end
    if pref == "Head" then return c:FindFirstChild("Head") end
    if pref == "Torso" then return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart") end
    if pref == "Closest" then
        local best, bestDist = nil, math.huge
        local camPos = Workspace.CurrentCamera.CFrame.Position
        for _, part in ipairs(c:GetChildren()) do
            if part:IsA("BasePart") then
                local d = (part.Position - camPos).Magnitude
                if d < bestDist then bestDist=d best=part end
            end
        end
        return best
    end
    if pref == "Random" then
        local parts={}
        for _,p in ipairs(c:GetChildren()) do if p:IsA("BasePart") then table.insert(parts,p) end end
        return parts[math.random(1,#parts)]
    end
    return c:FindFirstChild("HumanoidRootPart")
end

function Utils.isVisible(origin, targetPart)
    if not targetPart then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    params.IgnoreWater = true
    local dir = targetPart.Position - origin
    local res = Workspace:Raycast(origin, dir, params)
    if not res then return true end
    return res.Instance:IsDescendantOf(targetPart.Parent)
end

function Utils.isOnScreen(pos)
    local v, on = Workspace.CurrentCamera:WorldToViewportPoint(pos)
    return on, Vector2.new(v.X, v.Y), v.Z
end

function Utils.distance(a,b) return (a-b).Magnitude end

return Utils
