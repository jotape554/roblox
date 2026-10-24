# BRAINROT HEIST

Jogo Roblox (Luau) de coleção, economia, defesa de base e roubo de criaturas originais.
Projeto organizado para o **Rojo**, que sincroniza estes arquivos com o Roblox Studio.

## Status (honesto)

| Parte | Estado |
|---|---|
| Configuração central (`src/shared/Config.luau`) | Pronto |
| Salvamento com trava de sessão (`DataService`) | Pronto, não testado no Studio |
| Arena neon e 8 bases geradas por código (`WorldBuilder`) | Pronto, não testado no Studio |
| Criaturas placeholder com uid único (`BrainrotFactory`) | Pronto, não testado no Studio |
| Bases, vagas, renda, coleta e tranca (`PlotService`) | Pronto, não testado no Studio |
| Esteira de compra (`ConveyorService`) | Pronto, não testado no Studio |
| Roubo com regras de sucesso/falha (`StealService`) | Pronto, não testado no Studio |
| Bastão, banana, corneta (`CombatService`) | Pronto, não testado no Studio |
| Loja e venda (`ShopService`) | Pronto, não testado no Studio |
| Robux: passes e produtos (`MonetizationService`) | Pronto; IDs ainda são 0 |
| Interface do cliente (`src/client`) | Pronto, não testado no Studio |

O cliente (`src/client`) tem: HUD (dinheiro, renda/s, vagas, botões), loja (melhorias,
vaga extra e aba Robux), inventário (criaturas da base + melhorias compradas),
configurações (som, menos efeitos, rever tutorial), tutorial de primeira entrada,
a regra de esconder os botões Roubar/Vender por audiência e o empurrão do tapa
(knockback + "tropeço" via `Humanoid.PlatformStand`).

Verificação feita: todos os arquivos (servidor, shared e cliente) foram checados com
`luau-lsp analyze --platform roblox` contra um sourcemap do Rojo e o projeto builda
com `rojo build` sem erro. Fora do escopo do cliente, a checagem também encontrou um
tipo impreciso pré-existente em `PlotService.reserved` (linha 232: a tabela é anotada
como `{ [number]: boolean }`, mas o código grava `nil` para apagar uma vaga reservada;
funciona em runtime, só o tipo declarado está apertado demais). Ainda falta testar
tudo dentro do Studio.

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
