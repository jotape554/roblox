-- Carrega e salva os dados de cada jogador no DataStore.
-- Usa uma "trava de sessão": enquanto um servidor estiver com os dados de um
-- jogador, outro servidor não consegue sobrescrevê-los. Isso evita duplicar
-- dinheiro/brainrots trocando de servidor rápido.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

export type Data = {
	cash: number,
	totalEarned: number,
	slotCount: number,
	slots: { [string]: Creature }, -- ["1"] = { uid = "...", id = "sapo" }
	owned: { [string]: boolean }, -- ["speedCoil"] = true
	receipts: { string }, -- últimas compras com Robux já entregues
	settings: { sound: boolean, lowEffects: boolean },
	tutorialDone: boolean,
}

-- Cada exemplar tem um uid único, que acompanha a criatura mesmo quando roubada.
export type Creature = {
	uid: string,
	id: string,
}

type Profile = {
	data: Data,
	canSave: boolean,
	saving: boolean,
}

local MAX_RECEIPTS = 50
local LOAD_ATTEMPTS = 6

local DataService = {}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível:", result)
	end
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy :: any
end

local function defaultData(): Data
	return {
		cash = Config.START_CASH,
		totalEarned = 0,
		slotCount = Config.START_SLOTS,
		slots = {},
		owned = {},
		receipts = {},
		settings = { sound = true, lowEffects = false },
		tutorialDone = false,
	}
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Corrige dados antigos/corrompidos para nunca quebrar o jogo.
local function sanitize(raw: any): Data
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end

	if isFiniteNumber(raw.cash) then
		data.cash = math.max(0, math.floor(raw.cash))
	end
	if isFiniteNumber(raw.totalEarned) then
		data.totalEarned = math.max(0, math.floor(raw.totalEarned))
	end
	if isFiniteNumber(raw.slotCount) then
		data.slotCount = math.clamp(math.floor(raw.slotCount), Config.START_SLOTS, Config.MAX_SLOTS)
	end
	if type(raw.slots) == "table" then
		local seen = {}
		for key, creature in raw.slots do
			local slot = tonumber(key)
			local valid = slot ~= nil
				and slot >= 1
				and slot <= data.slotCount
				and slot % 1 == 0
				and type(creature) == "table"
				and type(creature.uid) == "string"
				and type(creature.id) == "string"
				and Config.BrainrotById[creature.id] ~= nil
				and not seen[creature.uid]
			if valid then
				seen[creature.uid] = true
				data.slots[tostring(slot)] = { uid = creature.uid, id = creature.id }
			end
		end
	end
	if type(raw.settings) == "table" then
		if type(raw.settings.sound) == "boolean" then
			data.settings.sound = raw.settings.sound
		end
		if type(raw.settings.lowEffects) == "boolean" then
			data.settings.lowEffects = raw.settings.lowEffects
		end
	end
	if raw.tutorialDone == true then
		data.tutorialDone = true
	end
	if type(raw.owned) == "table" then
		for id, value in raw.owned do
			if value == true and type(id) == "string" and Config.ShopItemById[id] then
				data.owned[id] = true
			end
		end
	end
	if type(raw.receipts) == "table" then
		for _, receipt in raw.receipts do
			if type(receipt) == "string" and #data.receipts < MAX_RECEIPTS then
				table.insert(data.receipts, receipt)
			end
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Atualiza o placar e os atributos que a interface do cliente lê.
function DataService.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local cashValue = leaderstats:FindFirstChild("Dinheiro")
	if not cashValue then
		cashValue = Instance.new("StringValue")
		cashValue.Name = "Dinheiro"
		cashValue.Parent = leaderstats
	end
	(cashValue :: StringValue).Value = Format.money(data.cash)

	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("SlotCount", data.slotCount)
	player:SetAttribute("TutorialDone", data.tutorialDone)
	player:SetAttribute("SettingSound", data.settings.sound)
	player:SetAttribute("SettingLowEffects", data.settings.lowEffects)
	for _, item in Config.ShopItems do
		player:SetAttribute("Owned_" .. item.id, data.owned[item.id] == true)
	end
end

function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.addCash(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or not isFiniteNumber(amount) or amount <= 0 then
		return
	end
	local value = math.floor(amount)
	profile.data.cash += value
	profile.data.totalEarned += value
	DataService.sync(player)
end

function DataService.trySpend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or not isFiniteNumber(amount) or amount < 0 then
		return false
	end
	if profile.data.cash < amount then
		return false
	end
	profile.data.cash -= math.floor(amount)
	DataService.sync(player)
	return true
end

function DataService.hasReceipt(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.data.receipts, purchaseId) ~= nil
end

function DataService.addReceipt(player: Player, purchaseId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	table.insert(profile.data.receipts, purchaseId)
	while #profile.data.receipts > MAX_RECEIPTS do
		table.remove(profile.data.receipts, 1)
	end
end

-- Carrega os dados. Retorna false se o jogador foi expulso por erro.
function DataService.load(player: Player): boolean
	if profiles[player] then
		return true
	end

	if not store then
		if RunService:IsStudio() then
			warn("[DataService] Sem DataStore: usando dados temporários (não serão salvos).")
			profiles[player] = { data = defaultData(), canSave = false, saving = false }
			DataService.sync(player)
			return true
		end
		player:Kick("Não foi possível carregar seus dados. Tente entrar de novo.")
		return false
	end

	local key = keyFor(player)
	local loaded: any = nil
	local success = false
	local lastError: any = nil

	for attempt = 1, LOAD_ATTEMPTS do
		if player.Parent == nil then
			return false
		end
		-- Na última tentativa assume a trava (o servidor antigo provavelmente caiu).
		local forceLock = attempt == LOAD_ATTEMPTS
		local lockedElsewhere = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(record)
				lockedElsewhere = false
				record = if type(record) == "table" then record else {}
				local lock = record.lock
				if not forceLock and type(lock) == "table" and lock.jobId ~= game.JobId then
					lockedElsewhere = true
					return nil -- cancela a escrita
				end
				record.lock = { jobId = game.JobId, time = os.time() }
				loaded = record.data
				return record
			end)
		end)
		if ok and not lockedElsewhere then
			success = true
			break
		end
		lastError = err
		task.wait(attempt * 1.5)
	end

	if not success then
		if RunService:IsStudio() then
			warn("[DataService] Falha ao carregar (ative 'Enable Studio Access to API Services'). Usando dados temporários.", lastError)
			profiles[player] = { data = defaultData(), canSave = false, saving = false }
			DataService.sync(player)
			return true
		end
		warn("[DataService] Falha ao carregar", player.UserId, lastError)
		player:Kick("Não foi possível carregar seus dados. Tente entrar de novo.")
		return false
	end

	profiles[player] = { data = sanitize(loaded), canSave = true, saving = false }

	-- Saiu durante o carregamento: libera a trava e para por aqui.
	if player.Parent == nil then
		DataService.release(player)
		return false
	end

	DataService.sync(player)
	return true
end

-- Salva. Com release = true também libera a trava (o jogador está saindo).
function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return true
	end

	-- Evita dois salvamentos simultâneos do mesmo jogador.
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true

	local snapshot = deepCopy(profile.data)
	local key = keyFor(player)
	local saved = false
	local lostLock = false

	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(record)
				lostLock = false
				record = if type(record) == "table" then record else {}
				local lock = record.lock
				if type(lock) == "table" and lock.jobId ~= game.JobId then
					-- Outro servidor assumiu os dados: não sobrescreve.
					lostLock = true
					return nil
				end
				record.data = snapshot
				record.lock = if release then nil else { jobId = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok then
			saved = not lostLock
			break
		end
		warn("[DataService] Erro ao salvar", player.UserId, err)
		task.wait(attempt)
	end

	profile.saving = false
	if lostLock then
		warn("[DataService] Trava perdida para", player.UserId, "- dados não salvos neste servidor.")
		profile.canSave = false
	end
	return saved
end

-- Salva, libera a trava e esquece o jogador.
function DataService.release(player: Player)
	if not profiles[player] then
		return
	end
	DataService.save(player, true)
	profiles[player] = nil
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player in profiles do
				if player.Parent then
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)
end

function DataService.releaseAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.release(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end

-- Usado ao comprar com Robux: total de renda por segundo (sem multiplicador).
function DataService.baseIncome(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, creature in data.slots do
		local def = Config.BrainrotById[creature.id]
		if def then
			total += def.income
		end
	end
	return total
end

return DataService
