-- Cria o modelo visual de uma criatura.
-- PLACEHOLDER: ainda são peças simples (Part), não malhas esculpidas. Cada
-- criatura tem um corpo genérico (Config.Brainrots[].shape) mais um conjunto
-- de "acessórios" (orelha, focinho, nadadeira...) escolhido por id em
-- VARIANTS, pra dar silhuetas diferentes sem precisar de modelos externos.
-- Para usar modelos 3D de verdade no futuro, troque só a função build()
-- (ou o VARIANTS[id].custom de cada criatura) mantendo "Root" como PrimaryPart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local BrainrotFactory = {}

local SHAPES = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local function addPart(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

export type Options = {
	showPrice: boolean?,
}

-- Acessórios reutilizáveis ----------------------------------------------
-- Só usam Block/Ball/Cylinder (como o resto do arquivo) pra não depender de
-- nenhuma malha externa. headY é a altura da cabeça (ver buildBody).

local function earsRound(model: Model, root: BasePart, headY: number, s: number, color: Color3)
	for _, side in { -1, 1 } do
		addPart(model, root, "Orelha", Vector3.one * 0.6 * s, CFrame.new(side * 0.95 * s, headY + 0.85 * s, 0.1 * s), color, Enum.PartType.Ball)
	end
end

local function earsPointy(model: Model, root: BasePart, headY: number, s: number, color: Color3)
	for _, side in { -1, 1 } do
		addPart(model, root, "Orelha", Vector3.new(0.5, 0.8, 0.3) * s, CFrame.new(side * 0.8 * s, headY + 1 * s, 0.1 * s) * CFrame.Angles(0, 0, math.rad(side * 12)), color)
	end
end

local function snout(model: Model, root: BasePart, headY: number, s: number, color: Color3, len: number)
	addPart(model, root, "Focinho", Vector3.new(0.9, 0.55, len) * s, CFrame.new(0, headY - 0.25 * s, -1.1 * s - len * s / 2), color)
end

local function beak(model: Model, root: BasePart, headY: number, s: number, color: Color3)
	addPart(model, root, "Bico", Vector3.new(0.55, 0.35, 0.6) * s, CFrame.new(0, headY - 0.15 * s, -1.25 * s), color)
end

local function tailThin(model: Model, root: BasePart, s: number, color: Color3)
	addPart(model, root, "Rabo", Vector3.new(0.3, 0.3, 1.3) * s, CFrame.new(0, -0.6 * s, 1.5 * s) * CFrame.Angles(math.rad(35), 0, 0), color)
end

local function tailCurly(model: Model, root: BasePart, s: number, color: Color3)
	for i = 1, 3 do
		local t = i / 3
		addPart(model, root, "Rabo", Vector3.one * (0.45 - t * 0.12) * s, CFrame.new(math.sin(t * 5) * 0.3 * s, -0.4 * s + t * 0.5 * s, 1.3 * s + t * 0.3 * s), color, Enum.PartType.Ball)
	end
end

local function finDorsal(model: Model, root: BasePart, headY: number, s: number, color: Color3)
	addPart(model, root, "Nadadeira", Vector3.new(0.25, 1 * s, 0.9) * s, CFrame.new(0, headY * 0.4, 0.2 * s), color)
end

local function wingsSide(model: Model, root: BasePart, s: number, color: Color3)
	for _, side in { -1, 1 } do
		addPart(model, root, "Asa", Vector3.new(1.4, 0.2, 1) * s, CFrame.new(side * 1.8 * s, 0.3 * s, 0.3 * s) * CFrame.Angles(0, 0, math.rad(side * -18)), color)
	end
end

local function feetShoes(model: Model, root: BasePart, s: number)
	for _, side in { -1, 1 } do
		addPart(model, root, "Tenis", Vector3.new(0.8, 0.6, 1.1) * s, CFrame.new(side * 0.7 * s, -2.1 * s, -0.15 * s), Color3.fromRGB(245, 245, 245))
	end
end

local function glasses(model: Model, root: BasePart, headY: number, s: number)
	for _, side in { -1, 1 } do
		addPart(model, root, "Oculos", Vector3.new(0.6, 0.35, 0.15) * s, CFrame.new(side * 0.45 * s, headY + 0.2 * s, -1.15 * s), Color3.fromRGB(20, 20, 25), nil, Enum.Material.Neon)
	end
end

local function hatFedora(model: Model, root: BasePart, headY: number, s: number, color: Color3)
	addPart(model, root, "AbaChapeu", Vector3.new(0.3, 2.2, 2.2) * s, CFrame.new(0, headY + 1.05 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), color)
	addPart(model, root, "CopaChapeu", Vector3.one * 1.1 * s, CFrame.new(0, headY + 1.3 * s, 0), color)
end

local function bellyPatch(model: Model, root: BasePart, s: number, color: Color3)
	addPart(model, root, "Barriga", Vector3.new(1.8, 2, 0.4) * s, CFrame.new(0, -0.3 * s, -1 * s), color)
end

local function spikesCluster(model: Model, root: BasePart, headY: number, s: number, color: Color3, count: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 0.6 * s, headY + 1.2 * s, math.sin(angle) * 0.6 * s)
		addPart(model, root, "Espinho", Vector3.new(0.3, 0.9, 0.3) * s, CFrame.new(offset) * CFrame.Angles(math.rad(math.cos(angle) * 20), 0, math.rad(math.sin(angle) * -20)), color)
	end
end

-- Corpo padrão ------------------------------------------------------------

export type Variant = {
	legStyle: ("short" | "long" | "none")?,
	bodySize: Vector3?, -- substitui o tamanho padrão do corpo (em unidades locais, multiplicado por `s`)
	bodyOffset: CFrame?, -- substitui a rotação padrão do corpo
	bodyTilt: CFrame?, -- rotação extra aplicada por cima da rotação padrão (ou de bodyOffset)
	extra: ((model: Model, root: BasePart, headY: number, s: number, def: Config.Brainrot) -> ())?,
	custom: ((model: Model, root: BasePart, s: number, def: Config.Brainrot) -> number)?, -- substitui o corpo inteiro; retorna o headY equivalente
}

local function addLegs(model: Model, root: BasePart, s: number, color: Color3, style: "short" | "long" | "none")
	if style == "none" then
		return
	end
	local size = if style == "long" then Vector3.new(0.6, 1.8, 0.6) else Vector3.new(0.7, 1, 0.7)
	local y = if style == "long" then -2.6 else -2
	for _, side in { -1, 1 } do
		addPart(model, root, "Perna", size * s, CFrame.new(side * 0.7 * s, y * s, 0), color)
	end
end

local function buildBody(model: Model, root: BasePart, s: number, def: Config.Brainrot, variant: Variant?): number
	local bodyShape = SHAPES[def.shape] or Enum.PartType.Block
	local defaultSize = if bodyShape == Enum.PartType.Ball then Vector3.one * 3 * s else Vector3.new(3, 3, 2.4) * s
	local defaultOffset = if bodyShape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity

	local bodySize = if variant and variant.bodySize then variant.bodySize * s else defaultSize
	local bodyOffset = if variant and variant.bodyOffset then variant.bodyOffset else defaultOffset
	if variant and variant.bodyTilt then
		bodyOffset = bodyOffset * variant.bodyTilt
	end
	addPart(model, root, "Corpo", bodySize, bodyOffset, def.body, bodyShape)

	local headY = 1.5 * s + 1.1 * s
	addPart(model, root, "Cabeca", Vector3.one * 2.2 * s, CFrame.new(0, headY, 0), def.head, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		addPart(model, root, "Olho", Vector3.one * 0.55 * s, CFrame.new(side * 0.45 * s, headY + 0.2 * s, -0.95 * s), Color3.new(1, 1, 1), Enum.PartType.Ball)
		addPart(model, root, "Pupila", Vector3.one * 0.28 * s, CFrame.new(side * 0.45 * s, headY + 0.2 * s, -1.18 * s), Color3.new(0, 0, 0), Enum.PartType.Ball)
	end
	addLegs(model, root, s, def.body:Lerp(Color3.new(0, 0, 0), 0.3), if variant and variant.legStyle then variant.legStyle else "short")

	if variant and variant.extra then
		variant.extra(model, root, headY, s, def)
	end

	return headY
end

-- O Olho Que Tudo Vê: a criatura inteira é um globo ocular gigante.
local function buildEye(model: Model, root: BasePart, s: number, def: Config.Brainrot): number
	addPart(model, root, "Globo", Vector3.one * 3.2 * s, CFrame.new(), def.body, Enum.PartType.Ball)
	addPart(model, root, "Iris", Vector3.one * 1.9 * s, CFrame.new(0, 0, -1.3 * s), def.head, Enum.PartType.Ball)
	addPart(model, root, "Pupila", Vector3.one * 0.9 * s, CFrame.new(0, 0, -1.9 * s), Color3.new(0, 0, 0), Enum.PartType.Ball)
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), math.sin(angle), 0)
		addPart(model, root, "Cilio", Vector3.new(0.12, 0.7, 0.12) * s, CFrame.new(dir * 1.7 * s) * CFrame.Angles(0, 0, angle), def.body)
	end
	return 1.6 * s
end

-- Silhuetas por criatura ---------------------------------------------------

local VARIANTS: { [string]: Variant } = {
	sapo = { legStyle = "long" },
	torradeira = {
		extra = function(model, root, headY, s, def)
			addPart(model, root, "Fenda", Vector3.new(1.6, 0.2, 0.5) * s, CFrame.new(0, 1.6 * s, -1 * s), Color3.fromRGB(40, 40, 40))
			addPart(model, root, "Torrada", Vector3.new(1.2, 0.9, 0.3) * s, CFrame.new(0, 2.2 * s, -1 * s), Color3.fromRGB(210, 160, 80))
		end,
	},
	cafezinho = {
		extra = function(model, root, headY, s, def)
			addPart(model, root, "Alca", Vector3.new(0.25, 1.2, 0.25) * s, CFrame.new(1.7 * s, 0.3 * s, 0), def.body)
			addPart(model, root, "Vapor", Vector3.one * 0.6 * s, CFrame.new(0, headY + 1.6 * s, 0), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, Enum.Material.ForceField)
		end,
	},
	pato = {
		extra = function(model, root, headY, s, def)
			beak(model, root, headY, s, Color3.fromRGB(255, 160, 40))
		end,
	},
	bananini = {
		bodyTilt = CFrame.Angles(0, 0, math.rad(12)),
		extra = function(model, root, headY, s, def)
			glasses(model, root, headY, s)
		end,
	},
	capivara = {
		legStyle = "long",
		extra = function(model, root, headY, s, def)
			earsRound(model, root, headY, s, def.body)
		end,
	},
	pizzarino = {
		bodySize = Vector3.new(0.8, 4, 4),
		extra = function(model, root, headY, s, def)
			wingsSide(model, root, s, def.head)
		end,
	},
	melancia = {
		extra = function(model, root, headY, s, def)
			hatFedora(model, root, headY, s, Color3.fromRGB(30, 30, 35))
			glasses(model, root, headY, s)
		end,
	},
	gatao = {
		extra = function(model, root, headY, s, def)
			earsPointy(model, root, headY, s, def.body)
			tailThin(model, root, s, def.body)
		end,
	},
	tubarao = {
		bodySize = Vector3.new(4.2, 1.8, 1.8),
		bodyOffset = CFrame.Angles(0, math.rad(90), 0),
		legStyle = "none",
		extra = function(model, root, headY, s, def)
			finDorsal(model, root, headY, s, def.body)
			feetShoes(model, root, s)
		end,
	},
	cocoporco = {
		extra = function(model, root, headY, s, def)
			snout(model, root, headY, s, def.body, 0.4)
			tailCurly(model, root, s, def.body)
		end,
	},
	abacaxi = {
		extra = function(model, root, headY, s, def)
			spikesCluster(model, root, headY, s, Color3.fromRGB(60, 150, 70), 5)
		end,
	},
	chinelo = {
		bodySize = Vector3.new(2.2, 0.5, 4.2),
		extra = function(model, root, headY, s, def)
			addPart(model, root, "Tira", Vector3.new(0.3, 0.3, 2.6) * s, CFrame.new(0.6 * s, 0.5 * s, -0.4 * s) * CFrame.Angles(0, 0, math.rad(25)), def.head)
			addPart(model, root, "Tira", Vector3.new(0.3, 0.3, 2.6) * s, CFrame.new(-0.6 * s, 0.5 * s, -0.4 * s) * CFrame.Angles(0, 0, math.rad(-25)), def.head)
		end,
	},
	brocolis = {
		extra = function(model, root, headY, s, def)
			spikesCluster(model, root, headY, s, def.body, 6)
		end,
	},
	pinguim = {
		extra = function(model, root, headY, s, def)
			bellyPatch(model, root, s, Color3.fromRGB(235, 240, 245))
			beak(model, root, headY, s, Color3.fromRGB(255, 160, 40))
			wingsSide(model, root, s, def.body)
		end,
	},
	olho = {
		custom = buildEye,
	},
}

-- Retorna o modelo e a altura do Root em relação ao chão.
-- O Root fica ancorado; mova o modelo alterando Root.CFrame.
function BrainrotFactory.create(id: string, uid: string, options: Options?): (Model, number)
	local def = Config.BrainrotById[id]
	assert(def, "Brainrot desconhecido: " .. tostring(id))
	local rarity = Config.RarityById[def.rarity]
	local s = def.scale

	local model = Instance.new("Model")
	model.Name = def.name
	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("Uid", uid)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2) * s
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	local variant = VARIANTS[id]
	local headY = if variant and variant.custom then variant.custom(model, root, s, def) else buildBody(model, root, s, def, variant)

	-- Detalhes por raridade
	if rarity.tier >= 3 then
		-- cilindro deitado no eixo X; girado 90° vira um disco horizontal
		local crownOffset = CFrame.new(0, headY + 1.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
		addPart(model, root, "Coroa", Vector3.new(0.5, 1.6, 1.6) * s, crownOffset, rarity.color, Enum.PartType.Cylinder, Enum.Material.Neon)
	end
	if rarity.tier >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = root
	end
	if rarity.tier >= 6 then
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(rarity.color)
		particles.LightEmission = 1
		particles.Size = NumberSequence.new(0.3, 0)
		particles.Lifetime = NumberRange.new(0.8, 1.4)
		particles.Rate = 8
		particles.Speed = NumberRange.new(1, 2)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = attachment
	end

	-- Etiqueta com nome, raridade e renda
	local gui = Instance.new("BillboardGui")
	gui.Name = "Etiqueta"
	gui.Size = UDim2.fromScale(7, 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, headY + 2.6 * s, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = root

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local function line(order: number, text: string, color: Color3, height: number)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, height)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeColor3 = Config.Theme.background
		label.TextStrokeTransparency = 0.1
		label.Parent = gui
	end

	line(1, def.name, Config.Theme.text, 0.3)
	line(2, def.rarity, rarity.color, 0.22)
	line(3, Format.money(def.income) .. "/s", Config.Theme.success, 0.24)
	if options and options.showPrice then
		line(4, Format.money(def.price), Config.Theme.warning, 0.24)
	end
	gui.Parent = root

	local rootHeight = 2.5 * s
	return model, rootHeight
end

return BrainrotFactory
