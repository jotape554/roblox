-- Acha a base do jogador local a partir do atributo PlotIndex (colocado pelo
-- PlotService em PlotService.assign) para ler as criaturas sem precisar de
-- um remote novo: elas já são instâncias replicadas em Workspace.Arena.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local PlotLookup = {}

function PlotLookup.getOwnCreatures(): Folder?
	local index = LocalPlayer:GetAttribute("PlotIndex")
	if typeof(index) ~= "number" then
		return nil
	end
	local arena = Workspace:FindFirstChild("Arena")
	local base = arena and arena:FindFirstChild("Base" .. index)
	local creatures = base and base:FindFirstChild("Criaturas")
	if creatures and creatures:IsA("Folder") then
		return creatures
	end
	return nil
end

return PlotLookup
