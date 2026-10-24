-- Efeitos que o servidor manda pelo Remotes.Effect: o empurrão do tapa (ou
-- banana/corneta) e o "+dinheiro" flutuante quando o jogador coleta uma vaga.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LocalPlayer = Players.LocalPlayer

local EffectsController = {}

-- Cada empurrão invalida o anterior: só o último hit reassume o controle do
-- personagem, senão um tapa curto logo depois de um comprido devolveria o
-- controle cedo demais.
local tripToken = 0

local function applyKnockback(velocity: Vector3, tripTime: number)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	tripToken += 1
	local myToken = tripToken

	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity

	task.delay(tripTime, function()
		if humanoid and tripToken == myToken and humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

local function popCash(anchor: TextLabel, amount: number)
	if LocalPlayer:GetAttribute("SettingLowEffects") == true then
		return
	end
	local parent = anchor.Parent
	if not parent then
		return
	end

	local popup = anchor:Clone()
	popup.Text = "+" .. Format.money(amount)
	popup.TextColor3 = Config.Theme.success
	popup.TextTransparency = 0
	popup.ZIndex = anchor.ZIndex + 1

	local startPos = anchor.Position + UDim2.fromOffset(0, anchor.AbsoluteSize.Y + 4)
	popup.Position = startPos
	popup.Parent = parent

	local tween = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = startPos + UDim2.fromOffset(0, -34),
		TextTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end

function EffectsController.start(cashLabel: TextLabel?)
	Remotes.Effect.OnClientEvent:Connect(function(kind, a, b)
		if kind == "knockback" then
			applyKnockback(a :: Vector3, b :: number)
		elseif kind == "cash" and cashLabel then
			popCash(cashLabel, a :: number)
		end
	end)
end

return EffectsController
