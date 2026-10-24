-- Tutorial rápido mostrado na primeira vez que o jogador entra (controlado
-- pelo atributo TutorialDone, gravado pelo DataService). Também pode ser
-- reaberto a qualquer momento pelo botão "Rever tutorial" das Configurações.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.Parent.Util.UiKit)

local Theme = Config.Theme

export type Handle = {
	show: () -> (),
}

type Step = {
	title: string,
	body: string,
}

local STEPS: { Step } = {
	{ title = "Bem-vindo ao " .. Config.GAME_NAME, body = "Colete brainrots, defenda sua base e roube dos outros jogadores!" },
	{ title = "Compre na esteira", body = 'Ande até a esteira central e segure "E" perto de uma criatura para comprá-la. Ela vai direto para a sua base.' },
	{ title = "Colete sua renda", body = "Cada criatura rende dinheiro com o tempo. Pise na placa verde da vaga dela para coletar." },
	{
		title = "Roube e se defenda",
		body = 'Segure "E" na criatura de outra base para roubá-la e levar até a sua. Use o Bastão para dar um tapa em quem estiver te roubando!',
	},
	{ title = "Tranque sua base", body = 'Pise no botão vermelho "Trancar" na entrada da sua base para impedir roubos por um tempo.' },
	{ title = "Loja e melhorias", body = "Abra a Loja no topo da tela para comprar vagas extras, velocidade, pulo e ferramentas de trollagem." },
}

local Tutorial = {}

function Tutorial.mount(screenGui: ScreenGui): Handle
	local overlay = Instance.new("Frame")
	overlay.Name = "Tutorial"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = screenGui

	local card = UiKit.panel(overlay, UDim2.new(0, 460, 0, 240), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	card.ZIndex = 11

	local stepLabel = UiKit.label(card, "", UDim2.new(1, -36, 0, 20), UDim2.new(0, 18, 0, 12), Theme.primary, 14)
	local titleLabel = UiKit.label(card, "", UDim2.new(1, -36, 0, 30), UDim2.new(0, 18, 0, 36), Theme.text, 22)
	local bodyLabel = UiKit.label(card, "", UDim2.new(1, -36, 0, 100), UDim2.new(0, 18, 0, 74), Theme.textMuted, 15)
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top

	local skipButton = UiKit.button(card, "Pular", UDim2.fromOffset(100, 36), UDim2.new(0, 18, 1, -52), Theme.surfaceHigh)
	local nextButton = UiKit.button(card, "Próximo", UDim2.fromOffset(120, 36), UDim2.new(1, -138, 1, -52), Theme.primary)
	nextButton.TextColor3 = Theme.background

	local index = 1

	local function finish()
		overlay.Visible = false
		Remotes.TutorialDone:FireServer()
	end

	local function renderStep()
		local step = STEPS[index]
		stepLabel.Text = string.format("PASSO %d/%d", index, #STEPS)
		titleLabel.Text = step.title
		bodyLabel.Text = step.body
		nextButton.Text = if index == #STEPS then "Começar!" else "Próximo"
	end

	nextButton.MouseButton1Click:Connect(function()
		if index >= #STEPS then
			finish()
			return
		end
		index += 1
		renderStep()
	end)
	skipButton.MouseButton1Click:Connect(finish)

	return {
		show = function()
			index = 1
			renderStep()
			overlay.Visible = true
		end,
	}
end

return Tutorial
