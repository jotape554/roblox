-- Cria o modelo visual de uma criatura.
-- PLACEHOLDER: as criaturas são montadas com peças simples (corpo, cabeça,
-- olhos, pernas). Para usar modelos 3D próprios no futuro, troque apenas a
-- função build() mantendo o "Root" como PrimaryPart.

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

	local bodyShape = SHAPES[def.shape] or Enum.PartType.Block
	local bodySize = if bodyShape == Enum.PartType.Ball then Vector3.one * 3 * s else Vector3.new(3, 3, 2.4) * s
	local bodyOffset = if bodyShape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity
	addPart(model, root, "Corpo", bodySize, bodyOffset, def.body, bodyShape)

	local headY = 1.5 * s + 1.1 * s
	addPart(model, root, "Cabeca", Vector3.one * 2.2 * s, CFrame.new(0, headY, 0), def.head, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		addPart(model, root, "Olho", Vector3.one * 0.55 * s, CFrame.new(side * 0.45 * s, headY + 0.2 * s, -0.95 * s), Color3.new(1, 1, 1), Enum.PartType.Ball)
		addPart(model, root, "Pupila", Vector3.one * 0.28 * s, CFrame.new(side * 0.45 * s, headY + 0.2 * s, -1.18 * s), Color3.new(0, 0, 0), Enum.PartType.Ball)
		addPart(model, root, "Perna", Vector3.new(0.7, 1, 0.7) * s, CFrame.new(side * 0.7 * s, -2 * s, 0), def.body:Lerp(Color3.new(0, 0, 0), 0.3))
	end

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
