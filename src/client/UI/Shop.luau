-- Painel da loja: melhorias e vagas extras (dinheiro do jogo) numa aba, Game
-- Passes e Developer Products (Robux) na outra. Tudo validado no servidor;
-- aqui só mostramos preço/estado e repassamos o pedido.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.Parent.Util.UiKit)

local Theme = Config.Theme
local LocalPlayer = Players.LocalPlayer

export type Handle = {
	frame: Frame,
	toggle: () -> (),
	setVisible: (boolean) -> (),
}

type Row = {
	update: () -> (),
}

local Shop = {}

local function nextSlotPrice(slotCount: number): number?
	if slotCount >= Config.MAX_SLOTS then
		return nil
	end
	return Config.SLOT_PRICES[slotCount + 1]
end

local function makeRow(parent: Instance, title: string, description: string, priceText: string, order: number): (TextLabel, TextButton)
	local card = UiKit.panel(parent, UDim2.new(1, -8, 0, 78), UDim2.new())
	card.BackgroundColor3 = Theme.surfaceHigh
	card.LayoutOrder = order

	UiKit.label(card, title, UDim2.new(1, -140, 0, 24), UDim2.new(0, 14, 0, 8), Theme.text, 17)
	local descLabel = UiKit.label(card, description, UDim2.new(1, -140, 0, 36), UDim2.new(0, 14, 0, 32), Theme.textMuted, 13, false)
	descLabel.TextWrapped = true

	local button = UiKit.button(card, priceText, UDim2.fromOffset(110, 40), UDim2.new(1, -124, 0.5, -20), Theme.primary)
	button.TextColor3 = Theme.background

	return descLabel, button
end

local function mountUpgrades(parent: ScrollingFrame, push: (string, Color3?) -> ()): { Row }
	local rows: { Row } = {}
	local order = 0

	for _, item in Config.ShopItems do
		order += 1
		local _, button = makeRow(parent, item.name, item.description, Format.money(item.price), order)
		local function update()
			local owned = LocalPlayer:GetAttribute("Owned_" .. item.id) == true
			local cash = LocalPlayer:GetAttribute("Cash")
			cash = if typeof(cash) == "number" then cash else 0
			if owned then
				button.Text = "Adquirido"
				button.BackgroundColor3 = Theme.success
			else
				button.Text = Format.money(item.price)
				button.BackgroundColor3 = if cash >= item.price then Theme.primary else Theme.surfaceHigh
			end
		end
		button.MouseButton1Click:Connect(function()
			if LocalPlayer:GetAttribute("Owned_" .. item.id) == true then
				return
			end
			local ok, message = Remotes.ShopBuy:InvokeServer(item.id)
			push(message, if ok then Theme.success else Theme.danger)
		end)
		table.insert(rows, { update = update })
	end

	order += 1
	local slotDesc, slotButton = makeRow(parent, "Nova vaga", "Libera mais um espaço para criaturas na sua base.", "--", order)
	local function updateSlot()
		local slotCount = LocalPlayer:GetAttribute("SlotCount")
		slotCount = if typeof(slotCount) == "number" then slotCount else Config.START_SLOTS
		local price = nextSlotPrice(slotCount)
		local cash = LocalPlayer:GetAttribute("Cash")
		cash = if typeof(cash) == "number" then cash else 0
		if not price then
			slotDesc.Text = "Você já tem o máximo de vagas (" .. Config.MAX_SLOTS .. ")."
			slotButton.Text = "Máximo"
			slotButton.BackgroundColor3 = Theme.success
		else
			slotDesc.Text = string.format("Libera a vaga %d/%d.", slotCount + 1, Config.MAX_SLOTS)
			slotButton.Text = Format.money(price)
			slotButton.BackgroundColor3 = if cash >= price then Theme.primary else Theme.surfaceHigh
		end
	end
	slotButton.MouseButton1Click:Connect(function()
		local ok, message = Remotes.ShopBuy:InvokeServer("slot")
		push(message, if ok then Theme.success else Theme.danger)
	end)
	table.insert(rows, { update = updateSlot })

	return rows
end

local function mountRobux(parent: ScrollingFrame)
	local order = 0
	for _, pass in Config.GamePasses do
		order += 1
		local _, button = makeRow(parent, pass.name, pass.description, if pass.id > 0 then "Comprar" else "Em breve", order)
		if pass.id > 0 then
			button.MouseButton1Click:Connect(function()
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, pass.id)
			end)
		end
	end
	for _, product in Config.Products do
		order += 1
		local _, button = makeRow(parent, product.name, product.description, if product.id > 0 then "Comprar" else "Em breve", order)
		if product.id > 0 then
			button.MouseButton1Click:Connect(function()
				MarketplaceService:PromptProductPurchase(LocalPlayer, product.id)
			end)
		end
	end
end

function Shop.mount(screenGui: ScreenGui, push: (string, Color3?) -> ()): Handle
	local frame = UiKit.panel(screenGui, UDim2.new(0, 460, 0, 460), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	frame.Name = "Shop"
	frame.Visible = false
	frame.ZIndex = 5

	UiKit.label(frame, "LOJA", UDim2.new(1, -60, 0, 40), UDim2.new(0, 18, 0, 8), Theme.text, 22)

	local tabUpgrades = UiKit.button(frame, "Melhorias", UDim2.fromOffset(140, 32), UDim2.new(0, 18, 0, 48), Theme.primary)
	local tabRobux = UiKit.button(frame, "Robux", UDim2.fromOffset(140, 32), UDim2.new(0, 166, 0, 48), Theme.surfaceHigh)
	tabUpgrades.TextColor3 = Theme.background

	local upgradesList = UiKit.scrollList(frame, UDim2.new(1, -36, 1, -140), UDim2.new(0, 18, 0, 92))
	local robuxList = UiKit.scrollList(frame, UDim2.new(1, -36, 1, -140), UDim2.new(0, 18, 0, 92))
	robuxList.Visible = false

	local rows = mountUpgrades(upgradesList, push)
	mountRobux(robuxList)

	local function refreshUpgrades()
		for _, r in rows do
			r.update()
		end
	end
	refreshUpgrades()

	LocalPlayer:GetAttributeChangedSignal("Cash"):Connect(refreshUpgrades)
	LocalPlayer:GetAttributeChangedSignal("SlotCount"):Connect(refreshUpgrades)
	for _, item in Config.ShopItems do
		LocalPlayer:GetAttributeChangedSignal("Owned_" .. item.id):Connect(refreshUpgrades)
	end

	local function selectTab(upgrades: boolean)
		upgradesList.Visible = upgrades
		robuxList.Visible = not upgrades
		tabUpgrades.BackgroundColor3 = if upgrades then Theme.primary else Theme.surfaceHigh
		tabUpgrades.TextColor3 = if upgrades then Theme.background else Theme.text
		tabRobux.BackgroundColor3 = if upgrades then Theme.surfaceHigh else Theme.primary
		tabRobux.TextColor3 = if upgrades then Theme.text else Theme.background
	end
	tabUpgrades.MouseButton1Click:Connect(function()
		selectTab(true)
	end)
	tabRobux.MouseButton1Click:Connect(function()
		selectTab(false)
	end)

	local function setVisible(visible: boolean)
		frame.Visible = visible
	end
	UiKit.closeButton(frame, function()
		setVisible(false)
	end)

	return {
		frame = frame,
		toggle = function()
			setVisible(not frame.Visible)
		end,
		setVisible = setVisible,
	}
end

return Shop
