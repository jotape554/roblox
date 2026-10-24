# BRAINROT HEIST

Jogo Roblox (Luau) de coleção, economia, defesa de base e roubo de criaturas originais.
Projeto organizado para o **Rojo**, que sincroniza estes arquivos com o Roblox Studio.

## Status (honesto)

| Parte | Estado |
|---|---|
| Configuração central (`src/shared/Config.luau`) | Pronto |
| Salvamento com trava de sessão (`DataService`) | Pronto, testado no Studio |
| Arena neon e 8 bases geradas por código (`WorldBuilder`) | Pronto, testado no Studio |
| Criaturas placeholder com uid único (`BrainrotFactory`) | Pronto, testado no Studio |
| Bases, vagas, renda, coleta e tranca (`PlotService`) | Pronto, testado no Studio |
| Esteira de compra (`ConveyorService`) | Pronto, testado no Studio |
| Roubo com regras de sucesso/falha (`StealService`) | Pronto, testado no Studio |
| Bastão, banana, corneta (`CombatService`) | Pronto, testado no Studio |
| Loja e venda (`ShopService`) | Pronto, testado no Studio |
| Robux: passes e produtos (`MonetizationService`) | Pronto; jogo publicado, IDs reais configurados |
| Interface do cliente (`src/client`) | Pronto, testado no Studio |

O cliente (`src/client`) tem: HUD (dinheiro, renda/s, vagas, botões), loja (melhorias,
vaga extra e aba Robux), inventário (criaturas da base + melhorias compradas),
configurações (som, menos efeitos, rever tutorial), tutorial de primeira entrada,
a regra de esconder os botões Roubar/Vender por audiência e o empurrão do tapa
(knockback + "tropeço" via `Humanoid.PlatformStand`).

Verificação feita: todos os arquivos (servidor, shared e cliente) foram checados com
`luau-lsp analyze --platform roblox` contra um sourcemap do Rojo, e o projeto builda
com `rojo build` sem erro. Fora do escopo do cliente, a checagem também encontrou um
tipo impreciso pré-existente em `PlotService.reserved` (linha 232), já corrigido.

**Testado no Roblox Studio** (solo e com "Servidor e clientes", 2 jogadores): tutorial
de primeira entrada (e "Rever tutorial"), som, esteira (comprar), coleta, loja
(melhorias, vaga extra, banana, corneta), vender, roubo, combate (tapa, banana,
corneta), tranca da base e expulsão de invasores — tudo funcionando. Durante o teste
um bug real apareceu e foi corrigido: `SoundController` usava `SoundService.Volume`,
que não existe na API do Roblox (o `luau-lsp` em modo não-estrito não pega indexação
de propriedade inexistente em serviços, só testando no Studio isso apareceu); agora
ele ajusta o `Volume` de cada `Sound` individualmente.

O jogo já foi **publicado no Roblox** e os 2 Game Passes + 6 Developer Products têm
IDs reais configurados em `Config.luau` (preços definidos no Creator Hub, não no código).

Ainda não feito: trocar os modelos placeholder das criaturas (`BrainrotFactory`) por
modelos 3D de verdade — hoje são blocos/esferas/cilindros coloridos, funcionais mas
visualmente simples.

## Como abrir no seu PC (Windows)

1. Instale o [Git](https://git-scm.com/download/win) e o Roblox Studio.
2. No PowerShell:
   ```powershell
   git clone https://github.com/jotape554/roblox.git
   cd roblox
   ```
3. Instale o Rojo: baixe `rojo-7.4.4-windows-x86_64.zip` em
   https://github.com/rojo-rbx/rojo/releases, extraia o `rojo.exe` nesta pasta
   e instale o plugin do Rojo no Studio (aba Plugins).
4. Para sincronizar com o Studio ao vivo:
   ```powershell
   .\rojo.exe serve
   ```
   No Studio: aba Plugins > Rojo > Connect.
5. Ou gere um arquivo do jogo para abrir direto:
   ```powershell
   .\rojo.exe build -o BrainrotHeist.rbxlx
   ```
6. No Studio: Game Settings > Security > ative **Enable Studio Access to API Services**
   para testar o salvamento.

## Estrutura

```
src/shared   -> ReplicatedStorage.Shared (Config, Format, Remotes)
src/server   -> ServerScriptService.Server (Main.server + serviços)
src/client   -> StarterPlayerScripts.Client (interface: HUD, loja, inventário, config, tutorial)
```
