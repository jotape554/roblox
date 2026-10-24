-- Compras com Robux: Game Passes e Developer Products.
-- ProcessReceipt garante que cada compra é entregue exatamente uma vez:
-- o id da compra fica salvo junto com os dados do jogador.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local PlayerService = require(script.Parent.PlayerService)
local PlotService = require(script.Parent.PlotService)

local MonetizationService = {}

local productById: { [number]: Config.Product } = {}
for _, product in Config.Products do
	if product.id > 0 then
		productById[product.id] = product
	end
end

local passById: { [number]: Config.GamePass } = {}
for _, pass in Config.GamePasses do
	if pass.id > 0 then
		passById[pass.id] = pass
	end
end

local function grantPass(player: Player, pass: Config.GamePass)
	player:SetAttribute("Pass_" .. pass.key, true)
	CombatService.giveTools(player)
	PlayerService.applyMovement(player)
end

function MonetizationService.loadPasses(player: Player)
	for _, pass in Config.GamePasses do
		if pass.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				grantPass(player, pass)
			elseif not ok then
				warn("[Monetization] Falha ao checar passe", pass.key, owns)
			end
		end
	end
end

-- Entrega o produto. Retorna false se não deu para entregar agora.
local function grantProduct(player: Player, product: Config.Product): boolean
	if product.cashSeconds then
		local amount = math.max(product.cashMin or 0, DataService.baseIncome(player) * product.cashSeconds)
		DataService.addCash(player, amount)
		Notify.send(player, "+" .. Format.money(amount) .. " adicionados!", Notify.GOOD)
		return true
	elseif product.key == "globalSlap" then
		CombatService.globalSlap(player)
		return true
	elseif product.key == "shield" then
		local plot = PlotService.getPlot(player)
		if not plot then
			return false
		end
		PlotService.lock(plot, Config.SHIELD_DURATION, true)
		return true
	elseif product.key == "bananaRain" then
		CombatService.bananaRain(player)
		return true
	end
	warn("[Monetization] Produto sem entrega:", product.key)
	return false
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService.isLoaded(player) then
		-- O Roblox tenta de novo depois (por exemplo, quando o jogador voltar).
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.hasReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById[receipt.ProductId]
	if not product then
		warn("[Monetization] Produto desconhecido:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(grantProduct, player, product)
	if not ok or not granted then
		warn("[Monetization] Falha ao entregar", product.key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Marca como entregue e salva. Se o save falhar, o Roblox reenvia; como o
	-- recibo já está na memória deste servidor, não entregamos duas vezes.
	DataService.addReceipt(player, purchaseId)
	if not DataService.save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if purchased and pass then
			grantPass(player, pass)
			Notify.send(player, "Obrigado! " .. pass.name .. " ativado.", Notify.GOOD)
		end
	end)
end

return MonetizationService
