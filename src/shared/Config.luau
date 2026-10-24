-- BRAINROT HEIST: configuração central. Quase tudo que você quiser balancear está aqui.

local Config = {}

Config.GAME_NAME = "BRAINROT HEIST"

-- Paleta da identidade visual (usada no mapa e na interface)
Config.Theme = {
	background = Color3.fromRGB(8, 11, 24), -- azul-marinho quase preto
	surface = Color3.fromRGB(22, 28, 44), -- grafite azulado
	surfaceHigh = Color3.fromRGB(34, 42, 64),
	stroke = Color3.fromRGB(56, 68, 100),
	primary = Color3.fromRGB(0, 230, 255), -- ciano neon
	secondary = Color3.fromRGB(150, 70, 255), -- roxo elétrico
	accent = Color3.fromRGB(255, 50, 190), -- magenta (com moderação)
	success = Color3.fromRGB(150, 255, 60), -- verde-lima
	warning = Color3.fromRGB(255, 205, 50),
	danger = Color3.fromRGB(255, 70, 80),
	text = Color3.fromRGB(235, 242, 255),
	textMuted = Color3.fromRGB(140, 152, 185),
}

-- Geral ---------------------------------------------------------------------

Config.MAX_PLAYERS = 8 -- uma base por jogador; ajuste também em Game Settings > Places
Config.START_CASH = 100
Config.START_SLOTS = 6
Config.MAX_SLOTS = 10
Config.SELL_RATIO = 0.5 -- vender devolve 50% do preço

Config.BASE_WALKSPEED = 16
Config.SPEED_COIL_WALKSPEED = 26
Config.BASE_JUMPPOWER = 50
Config.GRAVITY_COIL_JUMPPOWER = 85
Config.CARRY_SPEED_MULT = 0.7 -- quem está roubando anda mais devagar

Config.LOCK_DURATION = 60 -- segundos que a base fica trancada
Config.LOCK_COOLDOWN = 30 -- espera depois que a tranca acaba
Config.SHIELD_DURATION = 300 -- escudo comprado com Robux

Config.CONVEYOR_SPAWN_INTERVAL = 2.5
Config.CONVEYOR_TRAVEL_TIME = 45

Config.GO_HOME_COOLDOWN = 8

Config.DATASTORE_NAME = "BrainrotHeist_v1"
Config.AUTOSAVE_INTERVAL = 90

-- Raridades -----------------------------------------------------------------

export type Rarity = {
	id: string,
	color: Color3,
	weight: number,
	tier: number,
}

Config.Rarities = {
	{ id = "Comum", color = Color3.fromRGB(190, 200, 220), weight = 60, tier = 1 },
	{ id = "Raro", color = Color3.fromRGB(0, 200, 255), weight = 25, tier = 2 },
	{ id = "Épico", color = Color3.fromRGB(160, 80, 255), weight = 10, tier = 3 },
	{ id = "Lendário", color = Color3.fromRGB(255, 205, 50), weight = 3.5, tier = 4 },
	{ id = "Mítico", color = Color3.fromRGB(255, 70, 80), weight = 1.2, tier = 5 },
	{ id = "Deus Brainrot", color = Color3.fromRGB(150, 255, 60), weight = 0.25, tier = 6 },
	{ id = "Secreto", color = Color3.fromRGB(255, 50, 190), weight = 0.05, tier = 7 },
} :: { Rarity }

Config.RarityById = {} :: { [string]: Rarity }
for _, rarity in Config.Rarities do
	Config.RarityById[rarity.id] = rarity
end

-- Brainrots -----------------------------------------------------------------

export type Brainrot = {
	id: string,
	name: string,
	rarity: string,
	price: number,
	income: number, -- dinheiro por segundo
	body: Color3,
	head: Color3,
	shape: string, -- "Block", "Ball" ou "Cylinder"
	scale: number,
}

Config.Brainrots = {
	{ id = "sapo", name = "Sapo Dançarino", rarity = "Comum", price = 25, income = 1, body = Color3.fromRGB(90, 200, 90), head = Color3.fromRGB(120, 230, 120), shape = "Ball", scale = 0.8 },
	{ id = "torradeira", name = "Torradeira Rebelde", rarity = "Comum", price = 60, income = 3, body = Color3.fromRGB(170, 170, 180), head = Color3.fromRGB(210, 150, 80), shape = "Block", scale = 0.85 },
	{ id = "cafezinho", name = "Cafezinho Ninja", rarity = "Comum", price = 150, income = 7, body = Color3.fromRGB(110, 70, 40), head = Color3.fromRGB(30, 30, 30), shape = "Cylinder", scale = 0.9 },
	{ id = "pato", name = "Patito Skibidi", rarity = "Raro", price = 500, income = 20, body = Color3.fromRGB(255, 220, 60), head = Color3.fromRGB(255, 140, 30), shape = "Ball", scale = 0.95 },
	{ id = "bananini", name = "Bananini Patrão", rarity = "Raro", price = 1200, income = 45, body = Color3.fromRGB(255, 230, 90), head = Color3.fromRGB(40, 40, 40), shape = "Cylinder", scale = 1 },
	{ id = "capivara", name = "Capivara Turbo", rarity = "Raro", price = 2500, income = 90, body = Color3.fromRGB(140, 100, 60), head = Color3.fromRGB(110, 80, 50), shape = "Block", scale = 1.05 },
	{ id = "pizzarino", name = "Pizzarino Voador", rarity = "Épico", price = 8000, income = 250, body = Color3.fromRGB(240, 180, 80), head = Color3.fromRGB(220, 50, 40), shape = "Cylinder", scale = 1.1 },
	{ id = "melancia", name = "Melancia Mafiosa", rarity = "Épico", price = 20000, income = 600, body = Color3.fromRGB(40, 150, 60), head = Color3.fromRGB(240, 70, 90), shape = "Ball", scale = 1.15 },
	{ id = "gatao", name = "Gatão Sigma", rarity = "Épico", price = 45000, income = 1200, body = Color3.fromRGB(60, 60, 70), head = Color3.fromRGB(240, 240, 240), shape = "Block", scale = 1.15 },
	{ id = "tubarao", name = "Tubarãozito de Tênis", rarity = "Lendário", price = 150000, income = 3500, body = Color3.fromRGB(70, 130, 200), head = Color3.fromRGB(230, 240, 255), shape = "Cylinder", scale = 1.25 },
	{ id = "cocoporco", name = "Cocoporco Galáctico", rarity = "Lendário", price = 400000, income = 9000, body = Color3.fromRGB(255, 150, 190), head = Color3.fromRGB(120, 80, 50), shape = "Ball", scale = 1.3 },
	{ id = "abacaxi", name = "Abacaxi Astronauta", rarity = "Mítico", price = 1500000, income = 30000, body = Color3.fromRGB(240, 200, 40), head = Color3.fromRGB(240, 240, 255), shape = "Block", scale = 1.35 },
	{ id = "chinelo", name = "Chinelo Supremo", rarity = "Mítico", price = 5000000, income = 90000, body = Color3.fromRGB(30, 120, 220), head = Color3.fromRGB(255, 255, 255), shape = "Block", scale = 1.4 },
	{ id = "brocolis", name = "Brócolis Imperador", rarity = "Deus Brainrot", price = 25000000, income = 400000, body = Color3.fromRGB(30, 140, 50), head = Color3.fromRGB(255, 215, 0), shape = "Ball", scale = 1.5 },
	{ id = "pinguim", name = "Pinguim do Caos", rarity = "Deus Brainrot", price = 80000000, income = 1100000, body = Color3.fromRGB(20, 20, 30), head = Color3.fromRGB(255, 120, 0), shape = "Cylinder", scale = 1.55 },
	{ id = "olho", name = "O Olho Que Tudo Vê", rarity = "Secreto", price = 500000000, income = 6000000, body = Color3.fromRGB(10, 10, 10), head = Color3.fromRGB(255, 0, 60), shape = "Ball", scale = 1.7 },
} :: { Brainrot }

Config.BrainrotById = {} :: { [string]: Brainrot }
for _, brainrot in Config.Brainrots do
	Config.BrainrotById[brainrot.id] = brainrot
end

-- Loja (dinheiro do jogo) ---------------------------------------------------

export type ShopItem = {
	id: string,
	name: string,
	description: string,
	price: number,
}

Config.ShopItems = {
	{ id = "speedCoil", name = "Bobina de Velocidade", description = "Corra muito mais rápido para sempre.", price = 2500 },
	{ id = "gravityCoil", name = "Bobina de Gravidade", description = "Pule muito mais alto para sempre.", price = 4000 },
	{ id = "giantBat", name = "Bastão Gigante", description = "Seu tapa vai mais longe e arremessa mais forte.", price = 15000 },
	{ id = "banana", name = "Casca de Banana", description = "Espalhe bananas: quem pisar escorrega e larga o que roubou.", price = 30000 },
	{ id = "airhorn", name = "Corneta Troll", description = "BUZINA! Arremessa todo mundo em volta de você.", price = 75000 },
} :: { ShopItem }

Config.ShopItemById = {} :: { [string]: ShopItem }
for _, item in Config.ShopItems do
	Config.ShopItemById[item.id] = item
end

-- Preço para liberar cada vaga extra (índice = número da vaga)
Config.SLOT_PRICES = {
	[7] = 5000,
	[8] = 50000,
	[9] = 500000,
	[10] = 5000000,
} :: { [number]: number }

-- Robux ---------------------------------------------------------------------
-- Crie os Game Passes e Developer Products no site do Roblox (Creator Hub)
-- depois de publicar o jogo e cole os IDs aqui. Itens com id = 0 aparecem
-- como "em breve" na loja.

export type GamePass = {
	key: string,
	id: number,
	name: string,
	description: string,
}

Config.GamePasses = {
	{ key = "doubleCash", id = 2053829594, name = "Dinheiro x2", description = "Seus brainrots rendem o dobro, para sempre." },
	{ key = "vipTroll", id = 2052467556, name = "VIP Troll", description = "Ganha a Casca de Banana e a Corneta Troll de graça." },
} :: { GamePass }

export type Product = {
	key: string,
	id: number,
	name: string,
	description: string,
	cashSeconds: number?, -- pacotes de dinheiro: X segundos da sua renda
	cashMin: number?, -- ...com este valor mínimo
}

Config.Products = {
	{ key = "cashSmall", id = 2053247666, name = "Pacote Pequeno", description = "10 minutos da sua renda (mínimo $5K).", cashSeconds = 600, cashMin = 5000 },
	{ key = "cashMedium", id = 2053685573, name = "Pacote Médio", description = "1 hora da sua renda (mínimo $50K).", cashSeconds = 3600, cashMin = 50000 },
	{ key = "cashLarge", id = 2052347629, name = "Pacote Gigante", description = "6 horas da sua renda (mínimo $500K).", cashSeconds = 21600, cashMin = 500000 },
	{ key = "globalSlap", id = 2053919617, name = "Tapa Global", description = "Dá um tapa em TODOS do servidor. Quem estava roubando larga tudo." },
	{ key = "shield", id = 2053007609, name = "Escudo de 5 min", description = "Tranca sua base por 5 minutos na hora." },
	{ key = "bananaRain", id = 2052029632, name = "Chuva de Bananas", description = "30 cascas de banana caem pelo mapa. Você não escorrega." },
} :: { Product }

-- Combate e trollagem -------------------------------------------------------

Config.Slap = {
	cooldown = 0.8,
	range = 8,
	force = 70,
	up = 35,
	giantRange = 13,
	giantForce = 130,
	giantUp = 55,
	trip = 0.8,
}

Config.Banana = {
	cooldown = 10,
	maxActive = 3,
	lifetime = 40,
	trip = 2.5,
	rainCount = 30,
	rainLifetime = 60,
}

Config.Airhorn = {
	cooldown = 20,
	radius = 28,
	force = 110,
	up = 60,
	trip = 1.2,
}

-- Sons que já vêm com o Roblox (troque por IDs da Toolbox se quiser)
Config.Sounds = {
	slap = "rbxasset://sounds/swordslash.wav",
	horn = "rbxasset://sounds/electronicpingshort.wav",
	buy = "rbxasset://sounds/electronicpingshort.wav",
	banana = "rbxasset://sounds/swordlunge.wav",
}

return Config
