-- BRAINROT HEIST: inicialização do servidor.
-- Ordem importa: mundo -> serviços -> jogadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local StealService = require(script.Parent.StealService)
local WorldBuilder = require(script.Parent.WorldBuilder)

print("[" .. Config.GAME_NAME .. "] Iniciando servidor...")

PlotService.init(WorldBuilder.build())
PlotService.onStealRequested = StealService.tryStart
PlotService.onSellRequested = ShopService.sell
PlotService.onIntruderEjected = StealService.onIntruderEjected

DataService.start()
PlotService.start()
StealService.start()
CombatService.start()
ShopService.start()
MonetizationService.start()
ConveyorService.start()

-- Jogadores ------------------------------------------------------------------

local lastGoHome: { [Player]: number } = {}

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or character.Parent == nil then
		return
	end
	task.wait() -- deixa o Roblox terminar de posicionar o personagem
	if player.Parent and player.Character == character then
		PlotService.teleportHome(player)
		PlayerService.applyMovement(player)
	end
end

local function onPlayerAdded(player: Player)
	StealService.trackPlayer(player)

	if not DataService.load(player) then
		return -- foi expulso ou saiu durante o carregamento
	end

	local plot = PlotService.assign(player)
	if not plot then
		warn("[Main] Sem base livre para", player.Name)
		player:Kick("Servidor cheio. Entre em outro servidor!")
		return
	end

	MonetizationService.loadPasses(player)
	CombatService.giveTools(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	local data = DataService.get(player)
	if data and data.tutorialDone then
		Notify.send(player, "Bem-vindo de volta ao " .. Config.GAME_NAME .. "!", Notify.GOOD)
	end
	print(string.format("[Main] %s entrou na base %d", player.Name, plot.index))
end

local function onPlayerRemoving(player: Player)
	-- 1) devolve roubos em andamento (antes de salvar)
	StealService.onPlayerLeaving(player)
	-- 2) coleta o dinheiro pendente e libera a base
	PlotService.unassign(player)
	-- 3) salva e libera a trava de sessão
	DataService.release(player)

	CombatService.onPlayerLeaving(player)
	ShopService.onPlayerLeaving(player)
	lastGoHome[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		StealService.onPlayerLeaving(player)
		PlotService.unassign(player)
	end
	DataService.releaseAll()
end)

-- Pedidos do cliente ---------------------------------------------------------

Remotes.GoHome.OnServerEvent:Connect(function(player)
	local t = time()
	if t - (lastGoHome[player] or -math.huge) < Config.GO_HOME_COOLDOWN then
		Notify.send(player, "Aguarde para voltar à base de novo.", Notify.WARN)
		return
	end
	if StealService.isCarrying(player) then
		Notify.send(player, "Não dá para teleportar carregando uma criatura!", Notify.BAD)
		return
	end
	lastGoHome[player] = t
	PlotService.teleportHome(player)
end)

Remotes.SetSetting.OnServerEvent:Connect(function(player, name, value)
	local data = DataService.get(player)
	if not data or type(value) ~= "boolean" then
		return
	end
	if name == "sound" then
		data.settings.sound = value
	elseif name == "lowEffects" then
		data.settings.lowEffects = value
	else
		return
	end
	DataService.sync(player)
end)

Remotes.TutorialDone.OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if data and not data.tutorialDone then
		data.tutorialDone = true
		DataService.sync(player)
	end
end)

print("[" .. Config.GAME_NAME .. "] Servidor pronto.")
