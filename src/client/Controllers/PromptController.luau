-- Mostra "Roubar" só para quem NÃO é dono da base e "Vender" só para o dono,
-- usando os atributos Audience/OwnerId que o PlotService grava em cada
-- ProximityPrompt (ver PlotService.makePrompt). Esta é a regra de esconder
-- os botões Roubar/Vender citada no README.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local PromptController = {}

local function configure(prompt: ProximityPrompt)
	local audience = prompt:GetAttribute("Audience")
	if audience == nil then
		return -- prompt sem regra de audiência (ex: comprar na esteira) continua visível para todos
	end
	local ownerId = prompt:GetAttribute("OwnerId")
	local isOwner = ownerId == LocalPlayer.UserId
	if audience == "owner" then
		prompt.Enabled = isOwner
	elseif audience == "others" then
		prompt.Enabled = not isOwner
	end
end

function PromptController.start()
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("ProximityPrompt") then
			configure(instance)
		end
	end
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("ProximityPrompt") then
			configure(instance)
		end
	end)
end

return PromptController
