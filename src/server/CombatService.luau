-- Ferramentas de defesa e trollagem: Bastão (tapa), Casca de Banana e Corneta.
-- O servidor decide quem foi atingido. O empurrão é aplicado no cliente da
-- vítima (dono da física do próprio personagem) e quem leva tapa larga o que roubou.
--
-- As ferramentas ficam em StarterGear (o Roblox entrega de novo a cada respawn)
-- e são reconhecidas pela tag "HeistTool", então funcionam mesmo depois de clonadas.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local StealService = require(script.Parent.StealService)

local TAG = "HeistTool"

local CombatService = {}

local cooldowns: { [Player]: { [string]: number } } = {}
local activeBananas: { [Player]: number } = {}
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local bananaFolder = Instance.new("Folder")
bananaFolder.Name = "Bananas"
bananaFolder.Parent = Workspace

local function playSound(parent: Instance, soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.8
	sound.Parent = parent
	sound:Play()
	task.delay(3, function()
		sound:Destroy()
	end)
end

local function onCooldown(player: Player, kind: string, duration: number): boolean
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local t = time()
	if t < (list[kind] or 0) then
		return true
	end
	list[kind] = t + duration
	return false
end

-- Empurra a vítima e faz ela largar a criatura roubada.
function CombatService.knockback(victim: Player, velocity: Vector3, tripTime: number, reason: string)
	if not PlayerService.getHumanoid(victim) then
		return
	end
	Remotes.Effect:FireClient(victim, "knockback", velocity, tripTime)
	if StealService.isCarrying(victim) then
		StealService.cancel(victim, reason)
	end
end

local function horizontal(v: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function slap(player: Player, tool: Tool, giant: boolean)
	local root = PlayerService.getRoot(player)
	if not root then
		return
	end
	local range = if giant then Config.Slap.giantRange else Config.Slap.range
	local force = if giant then Config.Slap.giantForce else Config.Slap.force
	local up = if giant then Config.Slap.giantUp else Config.Slap.up

	-- Animação simples: gira o bastão rapidamente
	local originalGrip = tool.Grip
	tool.Grip = originalGrip * CFrame.Angles(math.rad(-90), 0, 0)
	task.delay(0.15, function()
		if tool.Parent then
			tool.Grip = originalGrip
		end
	end)
	playSound(root, Config.Sounds.slap)

	local look = root.CFrame.LookVector
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = PlayerService.getRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local inFront = distance < 3 or look:Dot(offset.Unit) > 0.3
				if distance <= range and inFront then
					local dir = horizontal(offset)
					CombatService.knockback(other, dir * force + Vector3.new(0, up, 0), Config.Slap.trip, "você levou um tapa")
				end
			end
		end
	end
end

-- immune: quem não escorrega nessa banana. counted: conta no limite de bananas do jogador.
local function placeBanana(position: Vector3, immune: Player, lifetime: number, counted: boolean)
	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Size = Vector3.new(1.6, 0.4, 1.2)
	banana.Color = Color3.fromRGB(255, 225, 60)
	banana.Material = Enum.Material.Neon
	banana.Anchored = true
	banana.CanCollide = false
	banana.CanQuery = false
	banana.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	banana.Parent = bananaFolder

	if counted then
		activeBananas[immune] = (activeBananas[immune] or 0) + 1
	end
	local removed = false
	local function remove()
		if removed then
			return
		end
		removed = true
		banana:Destroy()
		if counted and activeBananas[immune] then
			activeBananas[immune] = math.max(0, activeBananas[immune] - 1)
		end
	end

	banana.Touched:Connect(function(hit)
		if removed then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model)
		if not victim or victim == immune then
			return
		end
		local victimRoot = PlayerService.getRoot(victim)
		if not victimRoot then
			return
		end
		remove()
		playSound(victimRoot, Config.Sounds.banana)
		CombatService.knockback(victim, victimRoot.CFrame.LookVector * 30 + Vector3.new(0, 30, 0), Config.Banana.trip, "você escorregou numa banana")
	end)
	task.delay(lifetime, remove)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(origin: Vector3, ignore: { Instance }): Vector3?
	groundParams.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(origin, Vector3.new(0, -60, 0), groundParams)
	return result and result.Position
end

local function dropBanana(player: Player)
	local root = PlayerService.getRoot(player)
	local character = player.Character
	if not root or not character then
		return
	end
	if (activeBananas[player] or 0) >= Config.Banana.maxActive then
		Notify.send(player, "Máximo de " .. Config.Banana.maxActive .. " bananas ao mesmo tempo.", Notify.WARN)
		return
	end
	local behind = root.Position - root.CFrame.LookVector * 3
	local ground = groundBelow(behind + Vector3.new(0, 2, 0), { character, bananaFolder })
	if ground then
		placeBanana(ground, player, Config.Banana.lifetime, true)
	end
end

local function airhorn(player: Player)
	local root = PlayerService.getRoot(player)
	if not root then
		return
	end
	playSound(root, Config.Sounds.horn, 1)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = PlayerService.getRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				if offset.Magnitude <= Config.Airhorn.radius then
					CombatService.knockback(other, horizontal(offset) * Config.Airhorn.force + Vector3.new(0, Config.Airhorn.up, 0), Config.Airhorn.trip, "BUZINADA!")
				end
			end
		end
	end
end

-- Produtos de Robux ---------------------------------------------------------

function CombatService.globalSlap(buyer: Player)
	for _, other in Players:GetPlayers() do
		if other ~= buyer then
			local angle = math.random() * math.pi * 2
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			CombatService.knockback(other, dir * 120 + Vector3.new(0, 80, 0), 1.5, "TAPA GLOBAL!")
		end
	end
	Notify.all(buyer.DisplayName .. " usou o TAPA GLOBAL!", Config.Theme.accent)
end

function CombatService.bananaRain(buyer: Player)
	for _ = 1, Config.Banana.rainCount do
		local x = math.random(-110, 110)
		local z = math.random(-160, 160)
		local ground = groundBelow(Vector3.new(x, 50, z), { bananaFolder })
		if ground then
			placeBanana(ground, buyer, Config.Banana.rainLifetime, false)
		end
	end
	Notify.all(buyer.DisplayName .. " fez chover BANANAS!", Config.Theme.warning)
end

-- Ferramentas ---------------------------------------------------------------

local function makeTool(kind: string, name: string, handleSize: Vector3, color: Color3, giant: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = name
	tool:SetAttribute("Kind", kind)
	tool:SetAttribute("Giant", giant)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = handleSize
	handle.Color = color
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Grip = CFrame.new(0, -handleSize.Y / 2 + 0.6, 0)
	CollectionService:AddTag(tool, TAG)
	return tool
end

local function buildTool(kind: string, giant: boolean): Tool
	if kind == "bat" then
		if giant then
			return makeTool("bat", "Bastão Gigante", Vector3.new(1.1, 6.5, 1.1), Config.Theme.secondary, true)
		end
		return makeTool("bat", "Bastão", Vector3.new(0.6, 4, 0.6), Config.Theme.primary, false)
	elseif kind == "banana" then
		return makeTool("banana", "Casca de Banana", Vector3.new(1.2, 0.4, 1.2), Color3.fromRGB(255, 225, 60), false)
	else
		return makeTool("airhorn", "Corneta Troll", Vector3.new(0.8, 0.8, 2), Config.Theme.accent, false)
	end
end

local function ownerOf(tool: Tool): Player?
	local parent = tool.Parent
	if not parent then
		return nil
	end
	if parent:IsA("Backpack") then
		local player = parent.Parent
		return if player and player:IsA("Player") then player else nil
	end
	if parent:IsA("Model") then
		return Players:GetPlayerFromCharacter(parent)
	end
	return nil
end

local function onActivated(tool: Tool)
	local player = ownerOf(tool)
	if not player or tool.Parent ~= player.Character then
		return
	end
	local kind = tool:GetAttribute("Kind")
	if kind == "bat" then
		if not onCooldown(player, "bat", Config.Slap.cooldown) then
			slap(player, tool, tool:GetAttribute("Giant") == true)
		end
	elseif kind == "banana" then
		if not onCooldown(player, "banana", Config.Banana.cooldown) then
			dropBanana(player)
		end
	elseif kind == "airhorn" then
		if not onCooldown(player, "airhorn", Config.Airhorn.cooldown) then
			airhorn(player)
		else
			Notify.send(player, "Corneta recarregando...", Notify.WARN)
		end
	end
end

local function hook(instance: Instance)
	if instance:IsA("Tool") and not hooked[instance] then
		hooked[instance] = true
		instance.Activated:Connect(function()
			onActivated(instance)
		end)
	end
end

local function desiredTools(player: Player): { [string]: boolean }
	local data = DataService.get(player)
	local owned = if data then data.owned else {}
	local vip = player:GetAttribute("Pass_vipTroll") == true
	return {
		bat = true,
		banana = owned.banana == true or vip,
		airhorn = owned.airhorn == true or vip,
	}
end

-- Garante que o jogador tem exatamente as ferramentas que comprou.
function CombatService.giveTools(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local giant = data.owned.giantBat == true
	local wanted = desiredTools(player)

	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, child in starterGear:GetChildren() do
			if CollectionService:HasTag(child, TAG) then
				child:Destroy()
			end
		end
		for kind, want in wanted do
			if want then
				buildTool(kind, giant).Parent = starterGear
			end
		end
	end

	-- Ferramentas que o jogador já tem agora (mochila ou na mão)
	local have: { [string]: boolean } = {}
	local containers: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and CollectionService:HasTag(child, TAG) then
				local kind = child:GetAttribute("Kind") :: string
				local outdated = kind == "bat" and (child:GetAttribute("Giant") == true) ~= giant
				if have[kind] or outdated or not wanted[kind] then
					child:Destroy()
				else
					have[kind] = true
				end
			end
		end
	end
	if backpack then
		for kind, want in wanted do
			if want and not have[kind] then
				buildTool(kind, giant).Parent = backpack
			end
		end
	end
end

function CombatService.onPlayerLeaving(player: Player)
	cooldowns[player] = nil
	activeBananas[player] = nil
end

function CombatService.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		hook(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)
end

return CombatService
