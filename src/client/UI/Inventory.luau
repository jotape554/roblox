-- Painel de inventário: criaturas que estão na sua base agora e quais
-- melhorias da loja você já comprou. Lido direto das instâncias replicadas
-- (Workspace.Arena) e dos atributos Owned_*, sem precisar de remote novo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlotLookup = require(script.Parent.Parent.Util.PlotLookup)
local UiKit = require(script.Parent.Parent.Util.UiKit)

local Theme = Config.Theme
local LocalPlayer = Players.LocalPlayer

export type Handle = {
	frame: Frame,
	toggle: () -> (),
	setVisible: (boolean) -> (),
}

local Inventory = {}

local function clearList(scroll: ScrollingFrame)
	for _, child in scroll:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function creatureRow(parent: Instance, order: number): (TextLabel, TextLabel, TextLabel)
	local card = UiKit.panel(parent, UDim2.new(1, -8, 0, 52), UDim2.new())
	card.BackgroundColor3 = Theme.surfaceHigh
	card.LayoutOrder = order

	local nameLabel = UiKit.label(card, "", UDim2.new(0.55, 0, 1, 0), UDim2.new(0, 14, 0, 0), Theme.text, 16)
	local rarityLabel = UiKit.label(card, "", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.55, 0, 0, 0), Theme.textMuted, 14)
	local incomeLabel = UiKit.label(card, "", UDim2.new(0.2, -14, 1, 0), UDim2.new(0.8, 0, 0, 0), Theme.success, 14)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Right

	return nameLabel, rarityLabel, incomeLabel
end

local function upgradeRow(parent: Instance, text: string, owned: boolean, order: number)
	local card = UiKit.panel(parent, UDim2.new(1, -8, 0, 36), UDim2.new())
	card.BackgroundColor3 = Theme.surfaceHigh
	card.LayoutOrder = order
	UiKit.label(card, text, UDim2.new(1, -90, 1, 0), UDim2.new(0, 14, 0, 0), Theme.text, 14)
	local stateLabel = UiKit.label(
		card,
		if owned then "Comprado" else "Bloqueado",
		UDim2.fromOffset(80, 36),
		UDim2.new(1, -86, 0, 0),
		if owned then Theme.success else Theme.textMuted,
		13
	)
	stateLabel.TextXAlignment = Enum.TextXAlignment.Right
end

function Inventory.mount(screenGui: ScreenGui): Handle
	local frame = UiKit.panel(screenGui, UDim2.new(0, 420, 0, 460), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	frame.Name = "Inventory"
	frame.Visible = false
	frame.ZIndex = 5

	UiKit.label(frame, "SUAS CRIATURAS", UDim2.new(1, -60, 0, 32), UDim2.new(0, 18, 0, 10), Theme.text, 20)
	local creatureList = UiKit.scrollList(frame, UDim2.new(1, -36, 0, 220), UDim2.new(0, 18, 0, 48))

	UiKit.label(frame, "MELHORIAS", UDim2.new(1, -60, 0, 24), UDim2.new(0, 18, 0, 278), Theme.text, 16)
	local upgradeList = UiKit.scrollList(frame, UDim2.new(1, -36, 1, -316), UDim2.new(0, 18, 0, 306))

	local function rebuildCreatures()
		clearList(creatureList)
		local creatures = PlotLookup.getOwnCreatures()
		if not creatures then
			return
		end

		local defs: { Config.Brainrot } = {}
		for _, model in creatures:GetChildren() do
			local id = model:GetAttribute("BrainrotId")
			if typeof(id) == "string" then
				local def = Config.BrainrotById[id]
				if def then
					table.insert(defs, def)
				end
			end
		end
		table.sort(defs, function(a, b)
			local ra = Config.RarityById[a.rarity]
			local rb = Config.RarityById[b.rarity]
			if ra.tier ~= rb.tier then
				return ra.tier > rb.tier
			end
			return a.income > b.income
		end)

		if #defs == 0 then
			local empty = UiKit.label(creatureList, "Sua base está vazia. Compre na esteira!", UDim2.new(1, -8, 0, 40), UDim2.new(), Theme.textMuted, 14)
			empty.TextWrapped = true
			return
		end

		for i, def in defs do
			local rarity = Config.RarityById[def.rarity]
			local nameLabel, rarityLabel, incomeLabel = creatureRow(creatureList, i)
			nameLabel.Text = def.name
			rarityLabel.Text = def.rarity
			rarityLabel.TextColor3 = rarity.color
			incomeLabel.Text = Format.money(def.income) .. "/s"
		end
	end

	local function rebuildUpgrades()
		clearList(upgradeList)
		for i, item in Config.ShopItems do
			upgradeRow(upgradeList, item.name, LocalPlayer:GetAttribute("Owned_" .. item.id) == true, i)
		end
	end

	rebuildUpgrades()
	for _, item in Config.ShopItems do
		LocalPlayer:GetAttributeChangedSignal("Owned_" .. item.id):Connect(rebuildUpgrades)
	end

	task.spawn(function()
		while LocalPlayer:GetAttribute("PlotIndex") == nil and LocalPlayer.Parent do
			task.wait(0.25)
		end
		local creatures = PlotLookup.getOwnCreatures()
		if creatures then
			creatures.ChildAdded:Connect(rebuildCreatures)
			creatures.ChildRemoved:Connect(rebuildCreatures)
		end
		rebuildCreatures()
	end)

	local function setVisible(visible: boolean)
		frame.Visible = visible
		if visible then
			rebuildCreatures()
		end
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

return Inventory
