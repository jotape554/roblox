-- Velocidade e pulo do personagem, considerando melhorias e se está roubando.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local PlayerService = {}

function PlayerService.getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

function PlayerService.getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function PlayerService.applyMovement(player: Player)
	local humanoid = PlayerService.getHumanoid(player)
	if not humanoid then
		return
	end
	local data = DataService.get(player)
	local owned = if data then data.owned else {}

	local speed = if owned.speedCoil then Config.SPEED_COIL_WALKSPEED else Config.BASE_WALKSPEED
	if player:GetAttribute("Carrying") then
		speed *= Config.CARRY_SPEED_MULT
	end
	humanoid.WalkSpeed = speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if owned.gravityCoil then Config.GRAVITY_COIL_JUMPPOWER else Config.BASE_JUMPPOWER
end

return PlayerService
