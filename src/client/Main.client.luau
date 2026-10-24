-- BRAINROT HEIST: ponto de entrada do cliente.
-- Monta a interface (HUD, loja, inventário, configurações, tutorial) e liga
-- os controladores que não têm UI própria (avisos, empurrão/tapa, esconder
-- Roubar/Vender, som).

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local EffectsController = require(script.Parent.Controllers.EffectsController)
local NotifyController = require(script.Parent.Controllers.NotifyController)
local PromptController = require(script.Parent.Controllers.PromptController)
local SoundController = require(script.Parent.Controllers.SoundController)
local Hud = require(script.Parent.UI.Hud)
local Inventory = require(script.Parent.UI.Inventory)
local Settings = require(script.Parent.UI.Settings)
local Shop = require(script.Parent.UI.Shop)
local Tutorial = require(script.Parent.UI.Tutorial)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HeistUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local hud = Hud.mount(screenGui)
NotifyController.start(screenGui)
EffectsController.start(hud.cashLabel)
PromptController.start()
SoundController.start()

local shop = Shop.mount(screenGui, NotifyController.push)
local inventory = Inventory.mount(screenGui)
local tutorial = Tutorial.mount(screenGui)
local settings = Settings.mount(screenGui, tutorial.show)

hud.shopButton.MouseButton1Click:Connect(function()
	inventory.setVisible(false)
	settings.setVisible(false)
	shop.toggle()
end)
hud.inventoryButton.MouseButton1Click:Connect(function()
	shop.setVisible(false)
	settings.setVisible(false)
	inventory.toggle()
end)
hud.settingsButton.MouseButton1Click:Connect(function()
	shop.setVisible(false)
	inventory.setVisible(false)
	settings.toggle()
end)

-- Os atributos de dados (incluindo TutorialDone) só chegam depois que
-- DataService.load termina no servidor, um pouco depois do PlayerAdded.
task.spawn(function()
	local done = LocalPlayer:GetAttribute("TutorialDone")
	if done == nil then
		LocalPlayer:GetAttributeChangedSignal("TutorialDone"):Wait()
		done = LocalPlayer:GetAttribute("TutorialDone")
	end
	if done ~= true then
		tutorial.show()
	end
end)
