-- Roubo de criaturas.
--
-- REGRAS
-- Começar um roubo (segurar o botão "Roubar" por 1,5s):
--   * não pode ser a própria base;
--   * a base alvo não pode estar trancada;
--   * o ladrão não pode já estar carregando algo e precisa estar vivo;
--   * o ladrão precisa ter uma vaga livre na própria base;
--   * o ladrão precisa estar a até 12 studs da criatura.
-- Durante o roubo: a criatura vai acima da cabeça do ladrão, que anda 30% mais devagar.
-- SUCESSO: o ladrão entra na própria base -> a criatura (mesmo uid) vai para uma vaga livre.
-- FALHA (a criatura volta para a vaga original do dono):
--   * ladrão morre, leva tapa, escorrega na banana ou é expulso por uma base trancada;
--   * ladrão ou dono saem do jogo;
--   * passa do tempo limite (CARRY_TIMEOUT).
-- Uma criatura só pode estar em um lugar: ao começar o roubo ela sai do save do
-- dono e a vaga fica reservada; ao terminar ela é gravada em exatamente um save.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local BrainrotFactory = require(script.Parent.BrainrotFactory)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)

type Plot = PlotService.Plot
type Creature = DataService.Creature

type Carry = {
	thief: Player,
	owner: Player,
	ownerPlot: Plot,
	slot: number,
	creature: Creature,
	model: Model,
	startedAt: number,
	diedConnection: RBXScriptConnection?,
}

local MAX_STEAL_DISTANCE = 12
local CARRY_TIMEOUT = 90
local FAIL_COOLDOWN = 3

local StealService = {}

local carries: { [Player]: Carry } = {}
local cooldownUntil: { [Player]: number } = {}

local carriedFolder = Instance.new("Folder")
carriedFolder.Name = "CriaturasCarregadas"
carriedFolder.Parent = Workspace

function StealService.isCarrying(player: Player): boolean
	return carries[player] ~= nil
end

local function finish(carry: Carry)
	carries[carry.thief] = nil
	if carry.diedConnection then
		carry.diedConnection:Disconnect()
	end
	carry.model:Destroy()
	carry.thief:SetAttribute("Carrying", nil)
	PlayerService.applyMovement(carry.thief)
end

-- Devolve a criatura ao dono (roubo falhou).
function StealService.cancel(thief: Player, reason: string)
	local carry = carries[thief]
	if not carry then
		return
	end
	finish(carry)
	cooldownUntil[thief] = time() + FAIL_COOLDOWN

	local plot = carry.ownerPlot
	if plot.owner == carry.owner then
		PlotService.setReserved(plot, carry.slot, false)
		PlotService.placeCreature(carry.owner, carry.slot, carry.creature, true)
		if carry.owner.Parent then
			Notify.send(carry.owner, "Seu " .. Config.BrainrotById[carry.creature.id].name .. " voltou para a base!", Notify.GOOD)
		end
	else
		warn("[StealService] Dono não encontrado ao devolver", carry.creature.uid)
	end
	if thief.Parent then
		Notify.send(thief, "Roubo falhou: " .. reason, Notify.BAD)
	end
end

local function deliver(carry: Carry)
	local thief = carry.thief
	local thiefPlot = PlotService.getPlot(thief)
	local slot = thiefPlot and PlotService.findFreeSlot(thiefPlot)
	if not slot then
		StealService.cancel(thief, "sem vaga livre na sua base")
		return
	end
	finish(carry)
	PlotService.setReserved(carry.ownerPlot, carry.slot, false)
	PlotService.placeCreature(thief, slot, carry.creature, true)

	local name = Config.BrainrotById[carry.creature.id].name
	Notify.send(thief, "Você roubou " .. name .. "!", Notify.GOOD)
	if carry.owner.Parent then
		Notify.send(carry.owner, thief.DisplayName .. " roubou seu " .. name .. "!", Notify.BAD)
	end
end

function StealService.tryStart(thief: Player, plot: Plot, slot: number, model: Model)
	local owner = plot.owner
	if not owner or owner == thief or plot.models[slot] ~= model then
		return
	end
	if carries[thief] then
		Notify.send(thief, "Você já está carregando uma criatura.", Notify.WARN)
		return
	end
	if time() < (cooldownUntil[thief] or 0) then
		return
	end
	if PlotService.isLocked(plot) then
		Notify.send(thief, "Essa base está trancada!", Notify.BAD)
		return
	end
	local thiefPlot = PlotService.getPlot(thief)
	if not thiefPlot or not PlotService.findFreeSlot(thiefPlot) then
		Notify.send(thief, "Você não tem vaga livre na sua base.", Notify.WARN)
		return
	end
	local humanoid = PlayerService.getHumanoid(thief)
	local root = PlayerService.getRoot(thief)
	local modelRoot = model.PrimaryPart
	if not humanoid or not root or not modelRoot then
		return
	end
	if (root.Position - modelRoot.Position).Magnitude > MAX_STEAL_DISTANCE then
		return
	end

	local creature = PlotService.takeCreature(plot, slot)
	if not creature then
		return
	end
	PlotService.setReserved(plot, slot, true)

	-- Modelo carregado acima da cabeça
	local carried, rootHeight = BrainrotFactory.create(creature.id, creature.uid)
	local carriedRoot = carried.PrimaryPart :: BasePart
	carriedRoot.CFrame = root.CFrame * CFrame.new(0, 3 + rootHeight, 0)
	carriedRoot.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = carriedRoot
	weld.Parent = carriedRoot
	carried.Parent = carriedFolder

	local carry: Carry = {
		thief = thief,
		owner = owner,
		ownerPlot = plot,
		slot = slot,
		creature = creature,
		model = carried,
		startedAt = time(),
		diedConnection = nil,
	}
	carries[thief] = carry
	carry.diedConnection = humanoid.Died:Connect(function()
		StealService.cancel(thief, "você foi derrotado")
	end)

	thief:SetAttribute("Carrying", true)
	PlayerService.applyMovement(thief)

	local name = Config.BrainrotById[creature.id].name
	Notify.send(thief, "Leve " .. name .. " até a SUA base!", Notify.WARN)
	Notify.send(owner, thief.DisplayName .. " está roubando seu " .. name .. "! Dê um tapa nele!", Notify.BAD)
end

-- Chamado quando qualquer jogador sai: devolve tudo que envolve esse jogador
-- ANTES do save, para nada ser perdido nem duplicado.
function StealService.onPlayerLeaving(player: Player)
	if carries[player] then
		StealService.cancel(player, "saiu do jogo")
	end
	local toCancel = {}
	for thief, carry in carries do
		if carry.owner == player then
			table.insert(toCancel, thief)
		end
	end
	for _, thief in toCancel do
		StealService.cancel(thief, "o dono saiu do jogo")
	end
	cooldownUntil[player] = nil
end

function StealService.onIntruderEjected(player: Player, plot: Plot)
	local carry = carries[player]
	if carry and carry.ownerPlot == plot then
		StealService.cancel(player, "a base foi trancada")
	end
end

function StealService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0

		local toDeliver: { Carry } = {}
		local toCancel: { [Player]: string } = {}
		for thief, carry in carries do
			local root = PlayerService.getRoot(thief)
			local thiefPlot = PlotService.getPlot(thief)
			if not root or not PlayerService.getHumanoid(thief) or carry.model.Parent == nil then
				toCancel[thief] = "você foi derrotado"
			elseif time() - carry.startedAt > CARRY_TIMEOUT then
				toCancel[thief] = "demorou demais"
			elseif thiefPlot and PlotService.isInside(thiefPlot, root.Position) then
				table.insert(toDeliver, carry)
			end
		end
		for thief, reason in toCancel do
			StealService.cancel(thief, reason)
		end
		for _, carry in toDeliver do
			if carries[carry.thief] == carry then
				deliver(carry)
			end
		end
	end)
end

-- Chamado pelo Main para cada jogador que entra.
function StealService.trackPlayer(player: Player)
	player.CharacterRemoving:Connect(function()
		if carries[player] then
			StealService.cancel(player, "você foi derrotado")
		end
	end)
end

return StealService
