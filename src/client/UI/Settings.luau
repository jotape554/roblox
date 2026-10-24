-- Painel de configurações: som, menos efeitos e reabrir o tutorial. Os
-- valores ficam salvos no DataService (atributos SettingSound/SettingLowEffects).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.Parent.Util.UiKit)

local Theme = Config.Theme
local LocalPlayer = Players.LocalPlayer

export type Handle = {
	frame: Frame,
	toggle: () -> (),
	setVisible: (boolean) -> (),
}

local Settings = {}

local function optionRow(parent: Instance, position: UDim2, label: string, attribute: string, default: boolean)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -36, 0, 40)
	row.Position = position
	row.Parent = parent

	UiKit.label(row, label, UDim2.new(1, -70, 1, 0), UDim2.new(), Theme.text, 16)

	local initial = LocalPlayer:GetAttribute(attribute)
	local value = if typeof(initial) == "boolean" then initial else default

	local _, setToggle = UiKit.toggle(row, UDim2.new(1, -52, 0.5, -14), value, function(newValue)
		Remotes.SetSetting:FireServer(attribute, newValue)
	end)

	LocalPlayer:GetAttributeChangedSignal(attribute):Connect(function()
		local current = LocalPlayer:GetAttribute(attribute)
		setToggle(if typeof(current) == "boolean" then current else default)
	end)
end

function Settings.mount(screenGui: ScreenGui, onReplayTutorial: () -> ()): Handle
	local frame = UiKit.panel(screenGui, UDim2.new(0, 360, 0, 240), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	frame.Name = "Settings"
	frame.Visible = false
	frame.ZIndex = 5

	UiKit.label(frame, "CONFIGURAÇÕES", UDim2.new(1, -60, 0, 32), UDim2.new(0, 18, 0, 10), Theme.text, 20)

	optionRow(frame, UDim2.new(0, 18, 0, 54), "Som", "SettingSound", true)
	optionRow(frame, UDim2.new(0, 18, 0, 100), "Menos efeitos", "SettingLowEffects", false)

	local replayButton = UiKit.button(frame, "Rever tutorial", UDim2.new(1, -36, 0, 40), UDim2.new(0, 18, 0, 160), Theme.surfaceHigh)
	replayButton.MouseButton1Click:Connect(onReplayTutorial)

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

return Settings
