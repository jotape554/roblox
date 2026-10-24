-- Bases dos jogadores: atribuição, vagas, renda passiva, coleta e tranca.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BrainrotFactory = require(script.Parent.BrainrotFactory)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local WorldBuilder = require(script.Parent.WorldBuilder)

type Creature = DataService.Creature

export type Plot = {
	index: number,
	parts: WorldBuilder.PlotParts,
	owner: Player?,
	models: { [number]: Model },
	pending: { [number]: number },
	reserved: { [number]: boolean }, -- vaga reservada enquanto a criatura está sendo roubada
	lockedUntil: number,
	lockCooldownUntil: number,
}

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

-- Ligados pelo Main para evitar dependência circular.
PlotService.onStealRequested = nil :: ((thief: Player, plot: Plot, slot: number, model: Model) -> ())?
PlotService.onSellRequested = nil :: ((player: Player, plot: Plot, slot: number, model: Model) -> ())?
PlotService.onIntruderEjected = nil :: ((player: Player, plot: Plot) -> ())?

local function now(): number
	return time()
end

function PlotService.getPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.getPlots(): { Plot }
	return plots
end

function PlotService.isLocked(plot: Plot): boolean
	return now() < plot.lockedUntil
end

function PlotService.isInside(plot: Plot, position: Vector3): boolean
	return WorldBuilder.isInside(plot.parts.cf, position)
end

function PlotService.incomeMultiplier(player: Player): number
	return if player:GetAttribute("Pass_doubleCash") then 2 else 1
end

function PlotService.findFreeSlot(plot: Plot): number?
	local owner = plot.owner
	local data = owner and DataService.get(owner)
	if not data then
		return nil
	end
	for slot = 1, data.slotCount do
		if not plot.models[slot] and not plot.reserved[slot] then
			return slot
		end
	end
	return nil
end

local function updateIncomeAttribute(plot: Plot)
	local owner = plot.owner
	if not owner then
		return
	end
	local total = 0
	for _, model in plot.models do
		local def = Config.BrainrotById[model:GetAttribute("BrainrotId") :: string]
		if def then
			total += def.income
		end
	end
	owner:SetAttribute("Income", total * PlotService.incomeMultiplier(owner))
end

function PlotService.refreshSlots(plot: Plot)
	local owner = plot.owner
	local data = owner and DataService.get(owner)
	local unlockedCount = if data then data.slotCount else Config.START_SLOTS
	for i, slot in plot.parts.slots do
		local unlocked = i <= unlockedCount
		slot.podium.Transparency = if unlocked then 0 else 0.6
		slot.ring.Transparency = if unlocked then 0.7 else 1
		slot.pad.Transparency = if unlocked then 0 else 0.85
		if not unlocked then
			slot.padLabel.Text = "Vaga bloqueada"
			slot.padLabel.TextColor3 = Config.Theme.textMuted
		elseif not plot.models[i] then
			slot.padLabel.Text = ""
		end
	end
end

local function updatePadLabel(plot: Plot, slot: number)
	local label = plot.parts.slots[slot].padLabel
	if plot.models[slot] then
		label.Text = "Coletar " .. Format.money(plot.pending[slot] or 0)
		label.TextColor3 = Config.Theme.success
	elseif plot.reserved[slot] then
		label.Text = "SENDO ROUBADO!"
		label.TextColor3 = Config.Theme.danger
	else
		label.Text = ""
	end
end

local function makePrompt(root: BasePart, action: string, objectText: string, key: Enum.KeyCode, hold: number, audience: string, ownerId: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	-- O cliente usa estes atributos para mostrar o botão só para quem pode usá-lo.
	prompt:SetAttribute("Audience", audience)
	prompt:SetAttribute("OwnerId", ownerId)
	prompt.Parent = root
	return prompt
end

-- Coloca uma criatura numa vaga. writeData = false ao recriar a partir do save.
function PlotService.placeCreature(player: Player, slot: number, creature: Creature, writeData: boolean): boolean
	local plot = plotByPlayer[player]
	local data = DataService.get(player)
	if not plot or not data then
		return false
	end
	if slot < 1 or slot > data.slotCount or plot.models[slot] then
		return false
	end
	local def = Config.BrainrotById[creature.id]
	if not def then
		return false
	end

	local model, rootHeight = BrainrotFactory.create(creature.id, creature.uid)
	local root = model.PrimaryPart :: BasePart
	root.CFrame = plot.parts.slots[slot].standCF * CFrame.new(0, rootHeight, 0)

	local sellPrice = math.floor(def.price * Config.SELL_RATIO)
	local steal = makePrompt(root, "Roubar", def.name, Enum.KeyCode.E, 1.5, "others", player.UserId)
	local sell = makePrompt(root, "Vender " .. Format.money(sellPrice), def.name, Enum.KeyCode.F, 1, "owner", player.UserId)

	steal.Triggered:Connect(function(thief)
		local callback = PlotService.onStealRequested
		if callback then
			callback(thief, plot, slot, model)
		end
	end)
	sell.Triggered:Connect(function(seller)
		local callback = PlotService.onSellRequested
		if callback then
			callback(seller, plot, slot, model)
		end
	end)

	model.Parent = plot.parts.creatures
	plot.models[slot] = model
	plot.pending[slot] = plot.pending[slot] or 0
	plot.reserved[slot] = nil
	if writeData then
		data.slots[tostring(slot)] = { uid = creature.uid, id = creature.id }
	end
	updatePadLabel(plot, slot)
	updateIncomeAttribute(plot)
	return true
end

-- Coleta o dinheiro acumulado de uma vaga.
function PlotService.collect(plot: Plot, slot: number)
	local owner = plot.owner
	if not owner then
		return
	end
	local amount = math.floor(plot.pending[slot] or 0)
	if amount <= 0 then
		return
	end
	plot.pending[slot] = (plot.pending[slot] or 0) - amount
	DataService.addCash(owner, amount)
	if owner.Parent then
		Remotes.Effect:FireClient(owner, "cash", amount)
	end
	updatePadLabel(plot, slot)
end

-- Remove a criatura da vaga (venda ou roubo). Coleta antes o que estava pendente.
function PlotService.takeCreature(plot: Plot, slot: number): Creature?
	local model = plot.models[slot]
	local owner = plot.owner
	if not model or not owner then
		return nil
	end
	PlotService.collect(plot, slot)

	local creature: Creature = {
		uid = model:GetAttribute("Uid") :: string,
		id = model:GetAttribute("BrainrotId") :: string,
	}
	model:Destroy()
	plot.models[slot] = nil
	plot.pending[slot] = 0

	local data = DataService.get(owner)
	if data then
		data.slots[tostring(slot)] = nil
	end
	updatePadLabel(plot, slot)
	updateIncomeAttribute(plot)
	return creature
end

function PlotService.setReserved(plot: Plot, slot: number, reserved: boolean)
	plot.reserved[slot] = if reserved then true else nil
	updatePadLabel(plot, slot)
end

function PlotService.lock(plot: Plot, duration: number, ignoreCooldown: boolean): boolean
	local t = now()
	if not ignoreCooldown and (t < plot.lockedUntil or t < plot.lockCooldownUntil) then
		return false
	end
	plot.lockedUntil = math.max(plot.lockedUntil, t + duration)
	plot.lockCooldownUntil = plot.lockedUntil + Config.LOCK_COOLDOWN
	plot.parts.barrier.Transparency = 0.35
	local owner = plot.owner
	if owner then
		Notify.send(owner, "Base trancada por " .. Format.time(plot.lockedUntil - t), Notify.GOOD)
	end
	return true
end

function PlotService.assign(player: Player): Plot?
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.parts.signLabel.Text = "Base de " .. player.DisplayName
			player:SetAttribute("PlotIndex", plot.index)

			for key, creature in data.slots do
				local slot = tonumber(key)
				if slot then
					PlotService.placeCreature(player, slot, creature, false)
				end
			end
			PlotService.refreshSlots(plot)
			updateIncomeAttribute(plot)
			return plot
		end
	end
	return nil
end

-- Libera a base. Antes, coleta o dinheiro pendente para não perder nada.
function PlotService.unassign(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for slot in plot.models do
		PlotService.collect(plot, slot)
	end
	for _, model in plot.models do
		model:Destroy()
	end
	plot.models = {}
	plot.pending = {}
	plot.reserved = {}
	plot.lockedUntil = 0
	plot.lockCooldownUntil = 0
	plot.parts.barrier.Transparency = 1
	plot.owner = nil
	plotByPlayer[player] = nil
	plot.parts.signLabel.Text = "Base livre"
	plot.parts.lockLabel.Text = ""
	PlotService.refreshSlots(plot)
	for i in plot.parts.slots do
		updatePadLabel(plot, i)
	end
end

function PlotService.teleportHome(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(plot.parts.spawnCF)
	end
end

local function characterPlayer(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function updateLockLabel(plot: Plot)
	local label = plot.parts.lockLabel
	if not plot.owner then
		label.Text = ""
		return
	end
	local t = now()
	if t < plot.lockedUntil then
		label.Text = "TRANCADA " .. Format.time(plot.lockedUntil - t)
		label.TextColor3 = Config.Theme.success
	elseif t < plot.lockCooldownUntil then
		label.Text = "Recarga " .. Format.time(plot.lockCooldownUntil - t)
		label.TextColor3 = Config.Theme.textMuted
	else
		label.Text = "Pise para TRANCAR"
		label.TextColor3 = Config.Theme.danger
	end
end

local function ejectIntruders(plot: Plot)
	local owner = plot.owner
	for _, player in Players:GetPlayers() do
		if player ~= owner then
			local root = PlayerService.getRoot(player)
			if root and PlotService.isInside(plot, root.Position) then
				local callback = PlotService.onIntruderEjected
				if callback then
					callback(player, plot)
				end
				local character = player.Character
				if character then
					character:PivotTo(plot.parts.cf * CFrame.new(0, 4, -(WorldBuilder.PLOT_HALF_DEPTH + 8)) * CFrame.Angles(0, math.pi, 0))
				end
				Notify.send(player, "Base trancada! Você foi expulso.", Notify.BAD)
			end
		end
	end
end

function PlotService.init(plotParts: { WorldBuilder.PlotParts })
	for _, parts in plotParts do
		local plot: Plot = {
			index = parts.index,
			parts = parts,
			owner = nil,
			models = {},
			pending = {},
			reserved = {},
			lockedUntil = 0,
			lockCooldownUntil = 0,
		}
		table.insert(plots, plot)
		parts.signLabel.Text = "Base livre"

		for i, slot in parts.slots do
			slot.pad.Touched:Connect(function(hit)
				local player = characterPlayer(hit)
				if player and player == plot.owner then
					PlotService.collect(plot, i)
				end
			end)
		end

		parts.lockButton.Touched:Connect(function(hit)
			local player = characterPlayer(hit)
			if player and player == plot.owner and not PlotService.isLocked(plot) and now() >= plot.lockCooldownUntil then
				PlotService.lock(plot, Config.LOCK_DURATION, false)
			end
		end)
		PlotService.refreshSlots(plot)
	end
end

function PlotService.start()
	-- Renda passiva: 1x por segundo, calculada só no servidor.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in plots do
				local owner = plot.owner
				if owner then
					local mult = PlotService.incomeMultiplier(owner)
					for slot, model in plot.models do
						local def = Config.BrainrotById[model:GetAttribute("BrainrotId") :: string]
						if def then
							plot.pending[slot] = (plot.pending[slot] or 0) + def.income * mult
							updatePadLabel(plot, slot)
						end
					end
				end
			end
		end
	end)

	-- Tranca: rótulos, barreira e expulsão de invasores (4x por segundo).
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		for _, plot in plots do
			if plot.owner then
				if PlotService.isLocked(plot) then
					ejectIntruders(plot)
				elseif plot.parts.barrier.Transparency < 1 then
					plot.parts.barrier.Transparency = 1
					Notify.send(plot.owner, "Sua base foi destrancada!", Notify.WARN)
				end
			end
			updateLockLabel(plot)
		end
	end)
end

return PlotService
