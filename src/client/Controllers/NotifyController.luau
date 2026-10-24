-- Fila de avisos no topo da tela. O servidor manda pelo Remotes.Notify, mas
-- qualquer painel local também pode chamar NotifyController.push diretamente
-- (ex: a loja mostra a mensagem que o RemoteFunction ShopBuy devolveu).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.Parent.Util.UiKit)

local Theme = Config.Theme
local LocalPlayer = Players.LocalPlayer

local WIDTH = 380
local FONT = Enum.Font.Gotham
local TEXT_SIZE = 15

local NotifyController = {}

local container: Frame? = nil
local order = 0

local function lowEffects(): boolean
	return LocalPlayer:GetAttribute("SettingLowEffects") == true
end

function NotifyController.push(text: string, color: Color3?)
	local holder = container
	if not holder then
		return
	end
	local accent = color or Theme.text

	local innerWidth = WIDTH - 34
	local textSize = TextService:GetTextSize(text, TEXT_SIZE, FONT, Vector2.new(innerWidth, 1000))
	local height = math.max(40, textSize.Y + 18)

	order += 1
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, WIDTH, 0, height)
	toast.BackgroundColor3 = Theme.surface
	toast.BorderSizePixel = 0
	toast.LayoutOrder = order
	toast.Parent = holder
	UiKit.corner(toast, 10)
	local stroke = UiKit.stroke(toast, accent, 1.5)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, -12)
	bar.Position = UDim2.new(0, 6, 0, 6)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = toast
	UiKit.corner(bar, 2)

	local label = UiKit.label(toast, text, UDim2.new(1, -30, 1, -12), UDim2.new(0, 20, 0, 6), Theme.text, TEXT_SIZE, false)
	label.Font = FONT
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top

	if lowEffects() then
		task.delay(2.6, function()
			toast:Destroy()
		end)
		return
	end

	toast.BackgroundTransparency = 1
	stroke.Transparency = 1
	label.TextTransparency = 1
	bar.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.15 }):Play()
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	TweenService:Create(bar, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()

	task.delay(3.6, function()
		if not toast.Parent then
			return
		end
		local fadeOut = TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(bar, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

function NotifyController.start(screenGui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "Notifications"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 80)
	holder.Size = UDim2.new(0, WIDTH, 1, -80)
	holder.BackgroundTransparency = 1
	holder.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = holder

	container = holder

	Remotes.Notify.OnClientEvent:Connect(function(text, color)
		NotifyController.push(text, color)
	end)
end

return NotifyController
