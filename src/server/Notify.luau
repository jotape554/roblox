local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

Notify.GOOD = Color3.fromRGB(90, 230, 120)
Notify.BAD = Color3.fromRGB(255, 90, 90)
Notify.INFO = Color3.fromRGB(255, 255, 255)
Notify.WARN = Color3.fromRGB(255, 200, 60)

function Notify.send(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color or Notify.INFO)
end

function Notify.all(text: string, color: Color3?)
	for _, player in Players:GetPlayers() do
		Notify.send(player, text, color)
	end
end

return Notify
