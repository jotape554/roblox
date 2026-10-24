-- Barra superior: dinheiro, renda por segundo, vagas usadas e os botões para
-- abrir Loja/Itens/Configurações e voltar para a base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlotLookup = require(script.Parent.Parent.Util.PlotLookup)
local UiKit = require(script.Parent.Parent.Util.UiKit)

local Theme = Config.Theme
local LocalPlayer = Players.LocalPlayer

export type Handles = {
	root: Frame,
	cashLabel: TextLabel,
	shopButton: TextButton,
	inventoryButton: TextButton,
	settingsButton: TextButton,
}

local Hud = {}

local function row(parent: Instance, position: UDim2, anchorPoint: Vector2, padding: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.new(0, 0, 1, 0)
	frame.Position = position
	frame.AnchorPoint = anchorPoint
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	return frame
end

local function refreshSlots(label: TextLabel)
	local used = 0
	local creatures = PlotLookup.getOwnCreatures()
	if creatures then
		used = #creatures:GetChildren()
	end
	local total = LocalPlayer:GetAttribute("SlotCount")
	label.Text = string.format("Vagas %d/%d", used, if typeof(total) == "number" then total else Config.START_SLOTS)
end

function Hud.mount(screenGui: ScreenGui): Handles
	local root = UiKit.panel(screenGui, UDim2.new(0, 620, 0, 56), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
	root.Name = "Hud"

	local stats = row(root, UDim2.new(0, 18, 0.5, 0), Vector2.new(0, 0.5), 22)
	local cashLabel = UiKit.label(stats, "$0", UDim2.fromOffset(130, 36), nil, Theme.success, 22)
	local incomeLabel = UiKit.label(stats, "+$0/s", UDim2.fromOffset(110, 36), nil, Theme.textMuted, 15)
	local slotsLabel = UiKit.label(stats, "Vagas 0/0", UDim2.fromOffset(110, 36), nil, Theme.textMuted, 15)

	local buttons = row(root, UDim2.new(1, -16, 0.5, 0), Vector2.new(1, 0.5), 10)
	local homeButton = UiKit.button(buttons, "Base", UDim2.fromOffset(72, 36), nil, Theme.surfaceHigh)
	local shopButton = UiKit.button(buttons, "Loja", UDim2.fromOffset(72, 36), nil, Theme.primary)
	local inventoryButton = UiKit.button(buttons, "Itens", UDim2.fromOffset(72, 36), nil, Theme.secondary)
	local settingsButton = UiKit.button(buttons, "Config", UDim2.fromOffset(78, 36), nil, Theme.surfaceHigh)
	shopButton.TextColor3 = Theme.background

	homeButton.MouseButton1Click:Connect(function()
		Remotes.GoHome:FireServer()
	end)

	local function refreshCash()
		local cash = LocalPlayer:GetAttribute("Cash")
		cashLabel.Text = Format.money(if typeof(cash) == "number" then cash else 0)
	end
	local function refreshIncome()
		local income = LocalPlayer:GetAttribute("Income")
		incomeLabel.Text = "+" .. Format.money(if typeof(income) == "number" then income else 0) .. "/s"
	end

	refreshCash()
	refreshIncome()
	refreshSlots(slotsLabel)

	LocalPlayer:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
	LocalPlayer:GetAttributeChangedSignal("Income"):Connect(refreshIncome)
	LocalPlayer:GetAttributeChangedSignal("SlotCount"):Connect(function()
		refreshSlots(slotsLabel)
	end)

	-- A base só existe depois que o PlotService atribui o jogador (PlotIndex
	-- chega um pouco depois do join), então espera antes de escutar a pasta.
	task.spawn(function()
		while LocalPlayer:GetAttribute("PlotIndex") == nil and LocalPlayer.Parent do
			task.wait(0.25)
		end
		local creatures = PlotLookup.getOwnCreatures()
		if creatures then
			creatures.ChildAdded:Connect(function()
				refreshSlots(slotsLabel)
			end)
			creatures.ChildRemoved:Connect(function()
				refreshSlots(slotsLabel)
			end)
		end
		refreshSlots(slotsLabel)
	end)

	return {
		root = root,
		cashLabel = cashLabel,
		shopButton = shopButton,
		inventoryButton = inventoryButton,
		settingsButton = settingsButton,
	}
end

return Hud
