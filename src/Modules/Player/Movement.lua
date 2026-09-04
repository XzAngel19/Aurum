-- src/Modules/Player/Movement.lua | Aurum
-- Speed / Jump / Fly / Noclip / Infinite Jump / AntiAFK / Spin

local Module = {}
Module.Name = "PlayerMovement"

--[[
Speed: Heartbeat loop → Humanoid.WalkSpeed = R("player.movement.speed_value")
Jump:  Humanoid.JumpPower o JumpHeight
Fly:   BodyVelocity (MaxForce 1e9) + BodyGyro (P 9e4), dir = cam.LookVector WASD + Space/Ctrl, speed = FlySpeed*12
Noclip: RunService.Stepped → CanCollide=false por parte
InfiniteJump: UIS.JumpRequest → Hum:ChangeState(Jumping)
AntiAFK: LocalPlayer.Idled → VirtualUser:CaptureController()
Spin:   Heartbeat → Root.CFrame *= CFrame.Angles(0, rad(SpinSpeed*4), 0)
--]]

return Module
