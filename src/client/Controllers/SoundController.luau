-- Silencia o jogo para este jogador quando a configuração de som está
-- desligada. O volume é ajustado só no cliente (cada jogador ouve o próprio
-- SoundService), então não precisa de nenhum remote.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

local SoundController = {}

function SoundController.start()
	local function apply()
		SoundService.Volume = if LocalPlayer:GetAttribute("SettingSound") == false then 0 else 1
	end
	apply()
	LocalPlayer:GetAttributeChangedSignal("SettingSound"):Connect(apply)
end

return SoundController
