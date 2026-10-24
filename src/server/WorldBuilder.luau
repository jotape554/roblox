-- Constrói a arena futurista e as bases quando o servidor inicia.
-- Tudo é gerado por código para o mapa nunca ficar diferente da lógica.
--
-- Layout (visto de cima):
--   esteira central ao longo do eixo Z (x = 0)
--   4 bases à esquerda (x = -50) e 4 à direita (x = +50), com a entrada virada para a esteira.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme

local WorldBuilder = {}

-- Medidas da base em coordenadas locais (-Z aponta para a entrada/esteira).
WorldBuilder.PLOT_HALF_WIDTH = 30 -- eixo X local
WorldBuilder.PLOT_HALF_DEPTH = 24 -- eixo Z local
WorldBuilder.CONVEYOR_START = Vector3.new(0, 1, -145)
WorldBuilder.CONVEYOR_END = Vector3.new(0, 1, 145)

export type SlotParts = {
	podium: Part,
	ring: Part,
	pad: Part,
	padLabel: TextLabel,
	standCF: CFrame,
}

export type PlotParts = {
	index: number,
	cf: CFrame,
	model: Model,
	creatures: Folder,
	slots: { SlotParts },
	barrier: Part,
	lockButton: Part,
	lockLabel: TextLabel,
	signLabel: TextLabel,
	accent: Color3,
	spawnCF: CFrame,
}

local PLOT_ACCENTS = {
	Theme.primary,
	Theme.secondary,
	Color3.fromRGB(0, 255, 170),
	Color3.fromRGB(255, 140, 40),
	Theme.accent,
	Color3.fromRGB(80, 120, 255),
	Theme.success,
	Theme.warning,
}

local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeNeon(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local part = makePart(parent, name, size, cf, color, Enum.Material.Neon)
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

function WorldBuilder.billboard(adornee: BasePart, offset: Vector3, studs: Vector2, maxDistance: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs.X, studs.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Theme.text
	label.TextStrokeColor3 = Theme.background
	label.TextStrokeTransparency = 0.2
	label.Text = ""
	label.Parent = gui

	gui.Parent = adornee
	return gui, label
end

local function setupLighting()
	-- Clima noturno de neon, mas claro o bastante pra enxergar tudo sem apertar os olhos.
	Lighting.ClockTime = 19.3
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(95, 100, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 120, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.FogColor = Theme.background
	Lighting.FogStart = 350
	Lighting.FogEnd = 900

	if not Lighting:FindFirstChild("HeistBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "HeistBloom"
		bloom.Intensity = 0.5
		bloom.Size = 20
		bloom.Threshold = 1.8
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChild("HeistColor") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "HeistColor"
		color.Brightness = 0.06
		color.Contrast = 0.08
		color.Saturation = 0.12
		color.TintColor = Color3.fromRGB(235, 240, 255)
		color.Parent = Lighting
	end
end

local function buildArena(map: Folder)
	local ground = makePart(map, "Chao", Vector3.new(260, 2, 360), CFrame.new(0, -1, 0), Theme.background, Enum.Material.SmoothPlastic)
	ground.Reflectance = 0.05

	-- Grade neon discreta no chão
	for x = -120, 120, 40 do
		makeNeon(map, "Grade", Vector3.new(0.2, 0.05, 360), CFrame.new(x, 0.03, 0), Theme.stroke)
	end
	for z = -160, 160, 40 do
		makeNeon(map, "Grade", Vector3.new(260, 0.05, 0.2), CFrame.new(0, 0.03, z), Theme.stroke)
	end

	-- Bordas da arena (impedem cair do mapa)
	local wallHeight = 30
	makePart(map, "Borda", Vector3.new(2, wallHeight, 360), CFrame.new(-131, wallHeight / 2, 0), Theme.surface).Transparency = 0.6
	makePart(map, "Borda", Vector3.new(2, wallHeight, 360), CFrame.new(131, wallHeight / 2, 0), Theme.surface).Transparency = 0.6
	makePart(map, "Borda", Vector3.new(260, wallHeight, 2), CFrame.new(0, wallHeight / 2, -181), Theme.surface).Transparency = 0.6
	makePart(map, "Borda", Vector3.new(260, wallHeight, 2), CFrame.new(0, wallHeight / 2, 181), Theme.surface).Transparency = 0.6

	-- Esteira central
	local conveyor = makePart(map, "Esteira", Vector3.new(12, 1, 300), CFrame.new(0, 0.5, 0), Theme.surfaceHigh, Enum.Material.Metal)
	conveyor.Reflectance = 0.1
	makeNeon(map, "EsteiraLuz", Vector3.new(0.4, 0.3, 300), CFrame.new(-6.2, 1.05, 0), Theme.primary)
	makeNeon(map, "EsteiraLuz", Vector3.new(0.4, 0.3, 300), CFrame.new(6.2, 1.05, 0), Theme.primary)
	for z = -140, 140, 20 do
		-- setas apontando o sentido da esteira
		makeNeon(map, "Seta", Vector3.new(4, 0.1, 0.5), CFrame.new(0, 1.02, z) * CFrame.Angles(0, math.rad(35), 0), Theme.secondary)
		makeNeon(map, "Seta", Vector3.new(4, 0.1, 0.5), CFrame.new(0, 1.02, z) * CFrame.Angles(0, math.rad(-35), 0), Theme.secondary)
	end

	-- Portais de entrada e saída da esteira
	for _, z in { -150, 150 } do
		makePart(map, "Portal", Vector3.new(2, 14, 2), CFrame.new(-8, 7, z), Theme.surface)
		makePart(map, "Portal", Vector3.new(2, 14, 2), CFrame.new(8, 7, z), Theme.surface)
		makePart(map, "Portal", Vector3.new(18, 2, 2), CFrame.new(0, 15, z), Theme.surface)
		makeNeon(map, "PortalLuz", Vector3.new(14, 0.4, 0.4), CFrame.new(0, 13.8, z), Theme.secondary)
	end

	-- Spawn central
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnCentral"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, -168)
	spawn.Color = Theme.surfaceHigh
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	makeNeon(map, "SpawnLuz", Vector3.new(15, 0.2, 15), CFrame.new(0, 0.95, -168), Theme.primary).Transparency = 0.6
end

local function buildPlot(map: Folder, index: number, cf: CFrame): PlotParts
	local accent = PLOT_ACCENTS[index] or Theme.primary
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = map

	local hw, hd = WorldBuilder.PLOT_HALF_WIDTH, WorldBuilder.PLOT_HALF_DEPTH

	-- Piso e contorno neon
	makePart(model, "Piso", Vector3.new(hw * 2, 1, hd * 2), cf * CFrame.new(0, 0.5, 0), Theme.surface)
	makeNeon(model, "Contorno", Vector3.new(hw * 2, 0.15, 0.4), cf * CFrame.new(0, 1.05, -hd + 0.2), accent)

	-- Paredes laterais e do fundo
	local wallH = 12
	makePart(model, "Parede", Vector3.new(1, wallH, hd * 2), cf * CFrame.new(-hw + 0.5, 1 + wallH / 2, 0), Theme.surfaceHigh)
	makePart(model, "Parede", Vector3.new(1, wallH, hd * 2), cf * CFrame.new(hw - 0.5, 1 + wallH / 2, 0), Theme.surfaceHigh)
	makePart(model, "Parede", Vector3.new(hw * 2, wallH, 1), cf * CFrame.new(0, 1 + wallH / 2, hd - 0.5), Theme.surfaceHigh)
	makeNeon(model, "Faixa", Vector3.new(0.3, 0.4, hd * 2), cf * CFrame.new(-hw + 1.1, 1 + wallH - 1, 0), accent)
	makeNeon(model, "Faixa", Vector3.new(0.3, 0.4, hd * 2), cf * CFrame.new(hw - 1.1, 1 + wallH - 1, 0), accent)
	makeNeon(model, "Faixa", Vector3.new(hw * 2, 0.4, 0.3), cf * CFrame.new(0, 1 + wallH - 1, hd - 1.1), accent)

	-- Barreira laser da entrada (visível apenas com a base trancada)
	local barrier = makePart(model, "Barreira", Vector3.new(hw * 2 - 2, wallH, 0.4), cf * CFrame.new(0, 1 + wallH / 2, -hd + 0.5), Theme.danger, Enum.Material.ForceField)
	barrier.CanCollide = false
	barrier.CanQuery = false
	barrier.CanTouch = false
	barrier.CastShadow = false
	barrier.Transparency = 1

	-- Vagas: 5 de cada lado
	local creatures = Instance.new("Folder")
	creatures.Name = "Criaturas"
	creatures.Parent = model

	local slots: { SlotParts } = {}
	for i = 1, Config.MAX_SLOTS do
		local side = if i <= 5 then -1 else 1
		local row = (i - 1) % 5
		local x = side * 23
		local z = -15 + row * 7.5
		local podium = makePart(model, "Vaga" .. i, Vector3.new(6, 1, 6), cf * CFrame.new(x, 1.5, z), Theme.surfaceHigh)
		local ring = makeNeon(model, "VagaLuz" .. i, Vector3.new(6.3, 0.2, 6.3), cf * CFrame.new(x, 1.95, z), accent)
		ring.Transparency = 0.7

		local padX = side * 16.5
		local pad = makePart(model, "Coletar" .. i, Vector3.new(4, 0.4, 4), cf * CFrame.new(padX, 1.2, z), Theme.success, Enum.Material.Neon)
		pad.CanQuery = false
		pad.CastShadow = false
		local _, padLabel = WorldBuilder.billboard(pad, Vector3.new(0, 2.6, 0), Vector2.new(6, 1.6), 45)

		local standPos = Vector3.new(x, 2, z)
		local standCF = cf * CFrame.lookAt(standPos, standPos - Vector3.new(side, 0, 0))

		slots[i] = { podium = podium, ring = ring, pad = pad, padLabel = padLabel, standCF = standCF }
	end

	-- Botão de trancar a base
	local lockButton = makePart(model, "Trancar", Vector3.new(5, 0.4, 5), cf * CFrame.new(0, 1.2, 18), Theme.danger, Enum.Material.Neon)
	lockButton.CanQuery = false
	local _, lockLabel = WorldBuilder.billboard(lockButton, Vector3.new(0, 3, 0), Vector2.new(9, 2.2), 60)

	-- Placa com o nome do dono
	local signPart = makePart(model, "Placa", Vector3.new(1, 1, 1), cf * CFrame.new(0, 17, hd - 0.5), Theme.surface)
	signPart.Transparency = 1
	signPart.CanCollide = false
	signPart.CanQuery = false
	signPart.CanTouch = false
	local _, signLabel = WorldBuilder.billboard(signPart, Vector3.zero, Vector2.new(24, 4), 300)
	signLabel.TextColor3 = accent

	return {
		index = index,
		cf = cf,
		model = model,
		creatures = creatures,
		slots = slots,
		barrier = barrier,
		lockButton = lockButton,
		lockLabel = lockLabel,
		signLabel = signLabel,
		accent = accent,
		spawnCF = cf * CFrame.new(0, 4, 6),
	}
end

function WorldBuilder.build(): { PlotParts }
	setupLighting()

	local old = Workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Arena"
	map.Parent = Workspace

	buildArena(map)

	local plots: { PlotParts } = {}
	local zs = { -105, -35, 35, 105 }
	for i = 1, Config.MAX_PLAYERS do
		local left = i <= 4
		local z = zs[((i - 1) % 4) + 1]
		local x = if left then -50 else 50
		local center = Vector3.new(x, 0, z)
		local cf = CFrame.lookAt(center, Vector3.new(0, 0, z))
		plots[i] = buildPlot(map, i, cf)
	end
	return plots
end

-- true se a posição está dentro da área da base
function WorldBuilder.isInside(cf: CFrame, position: Vector3): boolean
	local p = cf:PointToObjectSpace(position)
	return math.abs(p.X) <= WorldBuilder.PLOT_HALF_WIDTH and math.abs(p.Z) <= WorldBuilder.PLOT_HALF_DEPTH and p.Y > -5 and p.Y < 40
end

return WorldBuilder
