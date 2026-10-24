-- Loja com dinheiro do jogo (melhorias, ferramentas e vagas) e venda de criaturas.
-- Tudo validado no servidor; o cliente só pede.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)

type Plot = PlotService.Plot

local REQUEST_COOLDOWN = 0.3

local ShopService = {}

local lastRequest: { [Player]: number } = {}

local function rateLimited(player: Player): boolean
	local t = time()
	if t - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = t
	return false
end

function ShopService.nextSlotPrice(slotCount: number): number?
	if slotCount >= Config.MAX_SLOTS then
		return nil
	end
	return Config.SLOT_PRICES[slotCount + 1]
end

function ShopService.buy(player: Player, itemId: any): (boolean, string)
	if type(itemId) ~= "string" then
		return false, "Pedido inválido."
	end
	if rateLimited(player) then
		return false, "Calma! Tente de novo."
	end
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return false, "Ainda carregando seus dados..."
	end

	if itemId == "slot" then
		local price = ShopService.nextSlotPrice(data.slotCount)
		if not price then
			return false, "Você já tem o máximo de vagas."
		end
		if not DataService.trySpend(player, price) then
			return false, "Dinheiro insuficiente: custa " .. Format.money(price)
		end
		data.slotCount += 1
		DataService.sync(player)
		PlotService.refreshSlots(plot)
		return true, "Nova vaga liberada! (" .. data.slotCount .. "/" .. Config.MAX_SLOTS .. ")"
	end

	local item = Config.ShopItemById[itemId]
	if not item then
		return false, "Item inválido."
	end
	if data.owned[itemId] then
		return false, "Você já tem esse item."
	end
	if not DataService.trySpend(player, item.price) then
		return false, "Dinheiro insuficiente: custa " .. Format.money(item.price)
	end
	data.owned[itemId] = true
	DataService.sync(player)
	PlayerService.applyMovement(player)
	CombatService.giveTools(player)
	return true, "Você comprou " .. item.name .. "!"
end

function ShopService.sell(player: Player, plot: Plot, slot: number, model: Model)
	if plot.owner ~= player or plot.models[slot] ~= model then
		return
	end
	if rateLimited(player) then
		return
	end
	local creature = PlotService.takeCreature(plot, slot)
	if not creature then
		return
	end
	local def = Config.BrainrotById[creature.id]
	local value = math.floor(def.price * Config.SELL_RATIO)
	DataService.addCash(player, value)
	Notify.send(player, "Vendeu " .. def.name .. " por " .. Format.money(value), Notify.GOOD)
end

function ShopService.onPlayerLeaving(player: Player)
	lastRequest[player] = nil
end

function ShopService.start()
	Remotes.ShopBuy.OnServerInvoke = function(player, itemId)
		local ok, message = ShopService.buy(player, itemId)
		return ok, message
	end
end

return ShopService
