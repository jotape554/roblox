-- Cria (no servidor) ou espera (no cliente) os eventos de rede do jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function event(name: string): RemoteEvent
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local function func(name: string): RemoteFunction
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteFunction
	end
	return folder:WaitForChild(name) :: RemoteFunction
end

return {
	Notify = event("Notify"), -- servidor -> cliente: (texto, cor?)
	Effect = event("Effect"), -- servidor -> cliente: ("knockback", velocidade, tempoCaido) | ("cash", valor)
	GoHome = event("GoHome"), -- cliente -> servidor
	ShopBuy = func("ShopBuy"), -- cliente -> servidor: (itemId) -> (ok, mensagem)
	SetSetting = event("SetSetting"), -- cliente -> servidor: (nome, valor)
	TutorialDone = event("TutorialDone"), -- cliente -> servidor
}
