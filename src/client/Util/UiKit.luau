-- Blocos de interface reutilizáveis que seguem a paleta de Config.Theme.
-- Todo painel do cliente (HUD, loja, inventário, configurações, tutorial) é
-- montado com estas funções para manter a identidade visual consistente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme

local UiKit = {}

function UiKit.corner(instance: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

function UiKit.stroke(instance: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.15
	stroke.Parent = instance
	return stroke
end

function UiKit.panel(parent: Instance, size: UDim2, position: UDim2, anchorPoint: Vector2?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchorPoint or Vector2.zero
	frame.BackgroundColor3 = Theme.surface
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UiKit.corner(frame, 14)
	UiKit.stroke(frame)
	return frame
end

function UiKit.label(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2?,
	color: Color3?,
	textSize: number?,
	bold: boolean?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.new()
	label.Font = if bold == false then Enum.Font.Gotham else Enum.Font.GothamBold
	label.TextSize = textSize or 18
	label.TextColor3 = color or Theme.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text
	label.Parent = parent
	return label
end

function UiKit.button(parent: Instance, text: string, size: UDim2, position: UDim2?, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Size = size
	button.Position = position or UDim2.new()
	button.BackgroundColor3 = color or Theme.surfaceHigh
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Theme.text
	button.Text = text
	button.Parent = parent
	UiKit.corner(button, 10)
	UiKit.stroke(button)

	local base = button.BackgroundColor3
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.12)
	local press = base:Lerp(Color3.new(0, 0, 0), 0.12)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = hover }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), { BackgroundColor3 = base }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = press
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = hover
	end)
	return button
end

-- Retorna o controle e uma função para mudar o estado dele por fora (ex: se o
-- servidor corrigir o valor porque os dados ainda não tinham carregado).
function UiKit.toggle(parent: Instance, position: UDim2, initial: boolean, onChanged: (boolean) -> ()): (Frame, (boolean) -> ())
	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(52, 28)
	track.Position = position
	track.BackgroundColor3 = if initial then Theme.success else Theme.surfaceHigh
	track.BorderSizePixel = 0
	track.Parent = parent
	UiKit.corner(track, 14)
	UiKit.stroke(track)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(22, 22)
	knob.Position = if initial then UDim2.new(1, -25, 0.5, -11) else UDim2.new(0, 3, 0.5, -11)
	knob.BackgroundColor3 = Theme.text
	knob.BorderSizePixel = 0
	knob.Parent = track
	UiKit.corner(knob, 11)

	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.Parent = track

	local state = initial
	local function set(value: boolean)
		state = value
		TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = if value then Theme.success else Theme.surfaceHigh }):Play()
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = if value then UDim2.new(1, -25, 0.5, -11) else UDim2.new(0, 3, 0.5, -11) }):Play()
	end

	button.MouseButton1Click:Connect(function()
		set(not state)
		onChanged(state)
	end)

	return track, set
end

function UiKit.closeButton(parent: Instance, onClick: () -> ()): TextButton
	local button = UiKit.button(parent, "X", UDim2.fromOffset(28, 28), UDim2.new(1, -36, 0, 8), Theme.danger)
	button.TextSize = 14
	button.MouseButton1Click:Connect(onClick)
	return button
end

function UiKit.scrollList(parent: Instance, size: UDim2, position: UDim2?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = size
	scroll.Position = position or UDim2.new()
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.primary
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	return scroll
end

return UiKit
