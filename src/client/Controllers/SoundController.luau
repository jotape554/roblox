-- Silencia o jogo para este jogador quando a configuração de som está
-- desligada. SoundService não tem um volume mestre controlável pelo cliente,
-- então a gente ajusta o Volume de cada Sound individualmente — funciona
-- porque CombatService.playSound só grava o Volume uma vez na criação, então
-- sobrescrever aqui localmente não é desfeito pelo servidor depois.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local SoundController = {}

local function isEnabled(): boolean
	return LocalPlayer:GetAttribute("SettingSound") ~= false
end

local function apply(sound: Sound)
	local original = sound:GetAttribute("OriginalVolume")
	if typeof(original) ~= "number" then
		original = sound.Volume
		sound:SetAttribute("OriginalVolume", original)
	end
	sound.Volume = if isEnabled() then original else 0
end

function SoundController.start()
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("Sound") then
			apply(instance)
		end
	end
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Sound") then
			apply(instance)
		end
	end)

	LocalPlayer:GetAttributeChangedSignal("SettingSound"):Connect(function()
		for _, instance in Workspace:GetDescendants() do
			if instance:IsA("Sound") then
				apply(instance)
			end
		end
	end)
end

return SoundController
