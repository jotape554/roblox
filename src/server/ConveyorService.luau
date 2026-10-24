-- Esteira central: criaturas aparecem numa ponta, andam até a outra e podem
-- ser compradas no caminho. A compra é validada no servidor e só acontece uma vez.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local BrainrotFactory = require(script.Parent.BrainrotFactory)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MAX_BUY_DISTANCE = 14

local ConveyorService = {}

local rng = Random.new()
local folder = Instance.new("Folder")
folder.Name = "Esteira"
folder.Parent = Workspace

local totalRarityWeight = 0
for _, rarity in Config.Rarities do
	totalRarityWeight += rarity.weight
end

local byRarity: { [string]: { Config.Brainrot } } = {}
for _, def in Config.Brainrots do
	byRarity[def.rarity] = byRarity[def.rarity] or {}
	table.insert(byRarity[def.rarity], def)
end

-- Sorteia raridade pelo peso e depois uma criatura dessa raridade.
function ConveyorService.pickRandom(): Config.Brainrot
	local roll = rng:NextNumber(0, totalRarityWeight)
	local chosen = Config.Rarities[1]
	for _, rarity in Config.Rarities do
		roll -= rarity.weight
		if roll <= 0 then
			chosen = rarity
			break
		end
	end
	local pool = byRarity[chosen.id] or byRarity[Config.Rarities[1].id]
	return pool[rng:NextInteger(1, #pool)]
end

local function spawnOne()
	local def = ConveyorService.pickRandom()
	local uid = HttpService:GenerateGUID(false)
	local model, rootHeight = BrainrotFactory.create(def.id, uid, { showPrice = true })
	local root = model.PrimaryPart :: BasePart

	local up = Vector3.new(0, rootHeight, 0)
	local startPos = WorldBuilder.CONVEYOR_START + up
	local endPos = WorldBuilder.CONVEYOR_END + up
	root.CFrame = CFrame.lookAt(startPos, endPos)
	local endCF = CFrame.lookAt(endPos, endPos + (endPos - startPos).Unit)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar " .. Format.money(def.price)
	prompt.ObjectText = def.name .. " (" .. def.rarity .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local sold = false
	local tween = TweenService:Create(root, TweenInfo.new(Config.CONVEYOR_TRAVEL_TIME, Enum.EasingStyle.Linear), { CFrame = endCF })

	prompt.Triggered:Connect(function(player)
		if sold or model.Parent == nil then
			return
		end
		local data = DataService.get(player)
		local plot = PlotService.getPlot(player)
		local playerRoot = PlayerService.getRoot(player)
		if not data or not plot or not playerRoot then
			return
		end
		if (playerRoot.Position - root.Position).Magnitude > MAX_BUY_DISTANCE then
			return
		end
		local slot = PlotService.findFreeSlot(plot)
		if not slot then
			Notify.send(player, "Sua base está cheia! Venda uma criatura ou compre mais vagas.", Notify.WARN)
			return
		end
		if not DataService.trySpend(player, def.price) then
			Notify.send(player, "Dinheiro insuficiente: custa " .. Format.money(def.price), Notify.BAD)
			return
		end
		sold = true
		tween:Cancel()
		model:Destroy()
		if PlotService.placeCreature(player, slot, { uid = uid, id = def.id }, true) then
			Notify.send(player, "Você comprou " .. def.name .. "! Ela já está na sua base.", Notify.GOOD)
		else
			-- Não deveria acontecer, mas nunca cobre sem entregar.
			data.cash += def.price
			DataService.sync(player)
			Notify.send(player, "Não foi possível colocar a criatura. Dinheiro devolvido.", Notify.BAD)
		end
	end)

	tween.Completed:Connect(function()
		if not sold and model.Parent then
			model:Destroy()
		end
	end)

	model.Parent = folder
	tween:Play()
end

function ConveyorService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(spawnOne)
			if not ok then
				warn("[ConveyorService] Erro ao criar criatura:", err)
			end
			task.wait(Config.CONVEYOR_SPAWN_INTERVAL)
		end
	end)
end

return ConveyorService
