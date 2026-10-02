# Droid Battles — esqueleto Flutter

Este projeto é o ponto de partida da conversão de
[Revers-BR/droidbattles](https://github.com/Revers-BR/droidbattles)
(C++/Qt) para Flutter.

O objetivo desta primeira etapa foi **apenas** dar forma ao projeto para
compilar — nenhuma lógica de jogo foi portada ainda. Cada classe do
código original em C++ ganhou um stub Dart equivalente (classe vazia,
só com a herança correta), para servir de esqueleto na próxima etapa.

## Como o código original foi mapeado

O `droidbattles.pro` original listava tudo isso rodando sobre `QT +=
widgets`. Nada disso é específico do Qt em termos de *regras do jogo* —
é lógica de simulação e assembly puro, então tudo abaixo pode virar
Dart puro. Só a camada de janelas/telas do Qt (`QMainWindow`,
`QPushButton`, `QMultiLineEdit` etc.) precisa virar widgets Flutter.

| Pasta Dart | Conteúdo | Vem de (C++) |
|---|---|---|
| `lib/core/` | Objetos base da arena, robô, dispositivos passivos (armadura, escudo, combustível, RAM, reparo, direção, camuflagem, resfriador) | `screenobject`, `device`, `devchoice`, `resource`, `botinfo`, `robots`, `armor`, `shield`, `fuel`, `ram`, `repair`, `steering`, `cloaker`, `chiller`, `timedev`, `explosion` |
| `lib/weapons/` | Armas e projéteis (feixe, plasma, chaff, minas, mísseis, foguetes, torreta, radar) | `beam`, `beamer`, `plasma`, `chaff`, `chafflauncher`, `mine`, `minelayer`, `missile`, `radarmissile`, `radarmissilelauncher`, `rocket`, `rocketlauncher`, `turret`, `scanner`, `scandetect` |
| `lib/vm/` | A VM de assembly que interpreta o programa de cada bot | `cpu`, `robcpu`, `instruktion`, `commonsymbols`, `communication` |
| `lib/battle/` | Simulação da arena e os modos de jogo/torneio | `battlearea`, `textmodebattlearea`, `battleconfig`, `confstruct`, `matchresult`, `kothtournament`, `startcup`, `startdeathbatt`, `startsbatt`, `startsurvbatt`, `starttournament` |
| `lib/ui/` | Telas e widgets (o que era Qt Widgets) | `droidbattles` (janela principal), `engine`, `createbot`, `confedit`, `debugwindow`, `debugcontents`, `docbrowser`, `infobox`, `pixbutton`, `pixmapholder`, `myqmultilineedit`, `textmodefilemanip` |

Cada arquivo tem um comentário `// TODO: portar a lógica real de ...`
apontando para o arquivo `.h`/`.cpp` original correspondente.

## Status atual (o que já foi portado de verdade)

A partir do código-fonte original (`droidbattles-master.zip`), a VM de
assembly já está parcialmente portada com fidelidade linha-a-linha,
não mais como stub:

| Arquivo | Status |
|---|---|
| `lib/vm/ram.dart` | **Completo.** Porte 1:1 de `ram.h`/`ram.cpp`. |
| `lib/vm/common_symbols.dart` | **Completo.** Todas as constantes de `commonsymbols.h`. |
| `lib/vm/instruction.dart` | **Completo.** As 247 entradas de `Instruction::instructions[]`, geradas automaticamente a partir do C++ (sem risco de erro de transcrição). |
| `lib/vm/register_file.dart` | **Completo.** Replica o aliasing de memória `registers`/`bit8reg`/`iregisters`/`ibit8reg` do C++ (todos apontam pro mesmo buffer de 512 bytes). |
| `lib/vm/cpu_host.dart` | Interface mínima do que a CPU precisa do robô (era `ScreenObject *ourbot`). |
| `lib/vm/cpu.dart` | Porte de `cpu.h`/`cpu.cpp` (classe base). `readfile`/`writefile` ficaram como TODO — dependem da camada de persistência de bots, ainda não portada. |
| `lib/vm/rob_cpu.dart` | **Completo.** Registradores, tabela de latência, loop de interrupção, loop de execução e os **247/247 opcodes** (0x00–0xF2), todos portados instrução por instrução a partir do switch original (`robcpu.cpp`, ~2600 linhas). |

### O que ainda falta (fora da VM em si)

A VM de assembly está pronta. A arena (`TextModeBattleArea`) também já
tem o loop principal portado. Status atual, arquivo por arquivo:

| Arquivo | Status |
|---|---|
| `lib/core/screen_object.dart` | **Completo.** Porte de `screenobject.h`/`.cpp` — a base de todo objeto da arena (posição, direção, dano, tipo). |
| `lib/core/device.dart` | **Completo.** Porte de `device.h`/`.cpp` — base de armas/módulos que um bot equipa. |
| `lib/battle/battle_config.dart` | **Completo.** Porte de `battleconfig.h`. |
| `lib/battle/text_mode_battle_area.dart` | **Completo o "motor".** `startOneBattle`, `execRound` (detecção/resolução de colisão, as 3 condições de fim de partida — normal/survival/deathmatch), `addScreenObject`, `devIo`, `getAreaInfo`, `explosions`, fiéis ao `textmodebattlearea.cpp` original. Como `Robots`/`Missile`/`Mine`/etc. ainda não existem de verdade, a arena recebe "factories" opcionais (`createRobot`, `createMissile`, ...) injetadas de fora — sem elas, cai num `ScreenObject()` vazio (não trava, só não tem bot/projétil de verdade ainda). |
| `lib/battle/battle_area.dart` | **Lógica completa** da arena **interativa** (`battlearea.cpp`), como subclasse de `TextModeBattleArea`. No C++ ela reimplementa `execute`/`explosions` com regras um pouco diferentes da headless (mesmo dono não colide, cada colisão cria um `Explosion` e soma `scorePoints`, dano de explosão em double, sorteio inclusivo, `maxPoints` da config, mensagens com o `baseName` do bot, `battledone` em torneio). Fora: só a janela Qt (timer, Play/Pause/Singlestep, slider, desenho) — isso vira a tela mobile. |
| `lib/core/explosion.dart` | **Completo** (`explosion.cpp`): círculo visual de 32 ciclos, só criado pela `BattleArea` interativa. |
| `lib/core/robots.dart` | **Completo** (menos os 20 devices, ver seção abaixo). Porte de `robots.h`/`robots.cpp` — a classe `Robots`, o robô de verdade. |
| `lib/battle/conf_struct.dart` | **Completo**, incluindo `load`/`save` (`confstruct.h/.cpp`) — mesmo formato de texto do `current.cfg` original (INI do `QSettings`, grupos com `\`). Recebe/devolve `String`; ler/escrever o arquivo em si fica por conta de quem chama. |
| `lib/battle/match_result.dart` | **Completo** (`matchresult.h`) — struct simples usada pelos modos de torneio (ainda não portados). |
| `lib/core/bot_info.dart` | **Só a lógica** de `botinfo.h/.cpp` (`score()`, usado por `storeScores()`) — o resto do original é um painel Qt inteiro (nome/armadura/calor/combustível/mensagem), que vira tela mobile usando os callbacks que `ScreenObject` já expõe. |
| `lib/vm/cpu.dart` | **Completo**, incluindo `readFile`/`writeFile` (opcodes 0x93/0x94) — estende `Device` (como no C++ original) e fala com o robô via `ourbot`, herdado de `Device`. |
| `lib/persistence/bot_file.dart` | **Completo** — o *framing* do arquivo `.bot` (prefixo de tamanho do `QDataStream`, layout do header de 256 bytes). Converte bytes crus ↔ o `mem` que `Robots(..., botFileBytes: ...)` espera. |
| `lib/persistence/bot_file_access.dart` | Interface pluggable para o acesso a arquivo que `readFile`/`writeFile` da CPU precisam — a implementação de verdade (usando algo como `dart:io`/`path_provider`) fica por conta da camada de plataforma. |
| `lib/assembler/assembler.dart` | **Completo** — o assembler de verdade (`CreateBot::assemble`), texto → bytecode: tokenizador, tabela de símbolos (labels/consts/vars), referências para frente resolvidas no final, todas as diretivas (`%org`, `%CPUboot`, `%CPUstack`, `%interrupt`, `db`, `dw`), e o casamento de mnemônico/operandos contra `kInstructionTable`. |
| `lib/assembler/device_symbols.dart` | **Completo** — a tabela de símbolos automáticos por device (ex.: `Scanner0_Scan`), extraída de `createbot.cpp`. |
| `lib/vm/rob_cpu.dart` | **Completo.** Registradores, tabela de latência, loop de interrupção, loop de execução e os **247/247 opcodes** (0x00–0xF2), todos portados instrução por instrução a partir do switch original (`robcpu.cpp`, ~2600 linhas). |

### `Robots` (o robô de verdade)

`lib/core/robots.dart` já é um porte fiel de `robots.cpp`: monta a
lista de até 32 devices a partir dos bytes do arquivo `.bot`, executa
todos a cada tick, aplica dano na ordem armadura→escudo
(`hitAbsorbOrder`), roteia portas OUT/IN pros devices certos, cuida de
rádio, debug, custo e superaquecimento — 1:1 com o C++ original.

**Todos os 21 tipos de device** (0 = genérico até 20 = RocketLauncher)
estão portados e instanciados de verdade em `Robots`: CPU (`RobCpu`),
Engine, Steering, Plasma, Armor, Scanner, Fuel, ChaffLauncher, Turret,
ScanDetect, TimeDev, Shield, Repair, Communication, Chiller, Cloaker,
MineLayer, RadarMissileLauncher, Beamer e RocketLauncher. O parâmetro
`deviceFactory` do construtor foi removido (não há mais device
faltando). Todos os objetos que a arena cria também estão portados:
`Missile`, `RadarMissile`, `Mine`, `Beam`, `Rocket` e `Chaff`.

Também corrigi, ao portar `Robots::addInterrupt`, a forma como
`RobCpu.execute()` detecta uma interrupção pendente: agora ela lê a
fila de portas herdada de `Device` (`portStack`/`stackTaken`) direto,
igual ao original, em vez do parâmetro externo que eu tinha colocado
antes de `Device` existir.

**Achei e corrigi um mapeamento errado do esqueleto inicial:**
`lib/ui/engine.dart` (`GameEngine`) tinha sido gerado a partir de
`engine.h` supondo que fosse o "loop principal do jogo" — mas
`engine.h` original é o device de propulsão. O device de verdade está
em `lib/core/engine.dart` (`Engine`); o antigo `lib/ui/engine.dart`
ficou como estava, com uma nota explicando a confusão, já que um loop
de UI ainda pode fazer sentido existir separadamente mais pra frente.

### Próximos passos, em ordem de prioridade

Regra do projeto: **a lógica fica fiel ao original; só as telas mudam**
(serão redesenhadas especificamente para mobile).

1. `devchoice.cpp`/`textmodefilemanip.cpp` — puramente UI/utilitários
   de replay em texto, não essenciais pro app rodar; sem prioridade.

### Correções feitas em relação ao esqueleto inicial

- `Plasma` estava mapeado como projétil (`extends ScreenObject`); no
  original é o **device** canhão (`extends Device`). Corrigido.
- `engine.h` estava mapeado como "loop do jogo"; na verdade é o
  device de propulsão. Corrigido (ver acima).
- Removi `lib/core/ram.dart`, um stub órfão e errado (`Ram extends
  Device`); a RAM de verdade é `lib/vm/ram.dart`.

### Arena headless x interativa

- `TextModeBattleArea` = a versão **headless** do original (torneios/modo rápido).
- `BattleArea` = a versão **interativa**; é a que a tela mobile deve usar.
  Ela expõe `onFightEnded(msg)` (no lugar do `QMessageBox`),
  `onBattleDone(a, b)` (signal `battledone`), `scorePoints`, e os objetos
  `Explosion` ficam em `objects[129..254]` para a UI desenhar.
- Ao conferir meu porte da headless contra o C++ achei e corrigi três
  divergências em `execRound`/`explosions`: o "guard" do modo survival
  usa o índice do laço externo (`x < 8`), o frag do deathmatch vai para o
  **dono** do atacante (não o slot), e o vencedor do survival é o bot
  nomeado com **menos** `fightsWon`.

### Como ligar tudo e rodar uma batalha

`lib/battle/default_factories.dart` liga na arena as factories dos
objetos já portados (robôs, mísseis, minas, feixes, foguetes e chaff):

```dart
final area = TextModeBattleArea(BattleConfig(names: [...], randomSeed: 1));
installDefaultFactories(area, botFiles: {'meubot.bot': bytesDoArquivo});
// Interativa (tela): use `BattleArea(...)` e `installDefaultFactories(..., ui: true)`.
final r = area.execRound(); // 3 = batalha terminou (ver area.lastResultMessage)
```

Ler os bytes do `.bot` (disco/assets) fica por sua conta até a
persistência ser portada.

### Testes

`test/vm_test.dart` tem testes de fumaça (tabela de instruções,
RAM, alguns opcodes, arena sem bots). **Eles nunca foram executados**
— o ambiente onde o porte foi feito não tem SDK Dart/Flutter. O mesmo
vale para o código todo: ele só teve as chaves conferidas, não foi
compilado. Rode `flutter test` e `flutter analyze` primeiro; espere
alguns erros de compilação/tipo pra corrigir.

### Sobre `startsbatt`/`startdeathbatt`/`startsurvbatt`/`startcup`/`starttournament`/`kothtournament`

Conferi os seis arquivos — **são só telas Qt** (diálogo de "Nova
Batalha": escolher arquivos `.bot`, número de rounds, tamanho da
arena, times, semente aleatória), sem nenhuma lógica de simulação.
Não há nada de lógica pra portar aqui; pela regra do projeto (lógica
fiel ao original, só a tela muda) eles vão direto para `lib/ui` como
telas mobile quando chegar a vez, usando os campos que `BattleConfig`
já tem. A única regra que não é puramente visual é a validação do
`StartCup` (número de bots deve ser 4, 8, 16, 32 ou 64) — deixo
anotada aqui pra não se perder: `[4, 8, 16, 32, 64].contains(numBots)`.

### Persistência do `.bot`

Conferi o formato exato no `createbot.cpp` (função `assemble()`) e no
`robots.cpp` originais, e confirma tudo que eu já tinha assumido em
`Robots.botFileBytes`: `mem[0]='B'` (magic byte, decorativo),
`mem[1]`=índice do tamanho de RAM, `mem[2+i*6 .. 7+i*6]` para os 32
devices (tipo/nível/arg1, e pra CPU os 4 bytes extras viram
boot/stack mem, escritos pelas diretivas `%CPUboot`/`%CPUstack` do
assembler), e `mem[256..]` é a RAM/programa do bot. No disco, o
arquivo tem um prefixo de 4 bytes (tamanho, big-endian) na frente
disso tudo — é o *framing* do `QDataStream::writeBytes` do Qt, sem
escolha nossa. `BotFile.stripFraming`/`addFraming` convertem entre os
bytes crus do arquivo e o `mem` que `Robots` espera.

`CPU::readfile`/`writefile` (instruções 0x93/0x94 da VM) agora têm a
lógica real portada — inclusive um comportamento estranho do
original que documentei em `BotFileAccess`: `writefile` **trunca** o
próprio arquivo `.bot` do robô antes de escrever (é como
`QFile::open(WriteOnly)` funciona no Qt sem `Append`), então um bot
que usa essa instrução apaga o próprio arquivo. Preservei o
comportamento por fidelidade, só documentei.

### O assembler e um bug real do jogo original

Ao portar `CreateBot::assemble()` reparei que a sintaxe rara de 3
operandos `mov reg,@regref,valor` (e sua variação invertida) usa, no
C++ original, um índice **literal** (245 e 246) na tabela de
instruções para pegar o opcode a emitir — em vez de calculado. Só que
nesses índices da tabela real estão as instruções `cj`/`cjn`, não os
opcodes que de fato implementam esse mov (que ficam nos índices
236/237). Ou seja: o assembler original **emite o opcode errado**
para essa forma de mov, e, pior, como a busca normal de mnemônico só
varre os índices 0–244, `cj`/`cjn` nunca são alcançáveis por matching
normal — só saem, por acidente, através desse mov quebrado. Isso é um
bug real do jogo original (não um erro de porte); documentei e
repliquei fielmente em `assembler.dart`, já que a regra do projeto é
manter a lógica fiel.

Testei o assembler contra um trecho pequeno em `test/assembler_test.dart`
(label pra frente, `%CPUboot`) — sem poder rodar, como sempre.

### Telas mobile (`lib/ui`)

Primeira leva de telas, pensada do zero pra toque — **a única parte
do projeto que não é um porte 1:1** (por decisão sua: lógica fiel ao
original, telas redesenhadas). Referências de UX usadas: apps de
cartas/RPG mobile pra listas de bots e escolha de equipamento (grid
de ícones + bottom sheet em vez das janelas separadas do
`DevChoice`/`CreateBot` originais), e HUD de jogos de ação mobile pra
tela de batalha (mapa em tela cheia + cartões de status deslizando +
barra de controles no rodapé, no lugar da `QDialog` com barra de menu
do `BattleArea` original).

| Arquivo | O que é |
|---|---|
| `lib/ui/app_theme.dart` | Tema escuro com acentos neon (Material 3). |
| `lib/ui/home_screen.dart` | Lista de bots em cards; FAB pra criar um novo; ícone de "batalha" quando há ≥2 bots montados. |
| `lib/ui/bot_editor_screen.dart` | Editor com 2 abas: **Código** (campo de texto monoespaçado + botão "Montar", mostra erro/sucesso do assembler) e **Devices** (grid de 32 slots). |
| `lib/ui/widgets/device_picker_sheet.dart` | Bottom sheet com grid de ícones pros 20 tipos de device + slider de nível. |
| `lib/ui/battle_setup_screen.dart` | Grid de seleção de 2-8 bots, `SegmentedButton` pro modo (Normal/Survival/Deathmatch), slider de rounds. |
| `lib/ui/battle_screen.dart` | Tela de batalha: roda `BattleArea.execRound()` num `Ticker`, cards de status (armadura/combustível/calor) por bot, tocar num robô seleciona ele, controles de play/pause e velocidade (1x/4x), overlay de resultado no fim. |
| `lib/ui/widgets/arena_painter.dart` | `CustomPainter` que desenha a arena (robôs como triângulos na cor do time, projéteis como pontos, minas como losangos, explosões como círculos que crescem/somem) dentro de um `InteractiveViewer` (pinça pra zoom). |
| `lib/ui/widgets/stat_bar.dart` | Barra de status estilo HUD (reaproveitada em vários lugares). |
| `lib/ui/models/bot_draft.dart` | Estado de um bot em edição (nome, RAM, devices, código-fonte, resultado da montagem) — não existe no C++, era espalhado pelos widgets do `CreateBot`. |

Ainda não tem: depuração passo-a-passo da CPU.

### Depurador passo-a-passo

- `lib/vm/debug_contents.dart` — porte de `debugcontents.h`
  (registradores + memória ao redor de IP/SP/SI/DI + últimos
  endereços executados). `RobCpu.debugContents()` (`vm/rob_cpu.dart`)
  é o porte de `RobCpu::debugContents()`.
- `lib/core/robots.dart` ganhou `firstCpu()` — acha a primeira CPU do
  bot (mesma lógica de busca que `addInterrupt` já fazia); é a CPU
  que o depurador mostra, igual ao `DebugWindow` original.
- `lib/ui/debug_screen.dart` — a tela: roda o bot **sozinho**, sem
  oponentes, numa arena headless, com `singleStepMode` ligado; botão
  "Step" avança uma instrução por vez, painel de registradores em
  hexadecimal, e o código-fonte com a **linha atual destacada** — algo
  que o depurador original não tinha (ele só mostrava endereços
  numéricos); dá pra fazer porque `Assembler` agora expõe
  `debugMem`/`debugLines` (endereço ↔ linha), e `BotDraft.lineForAddress`
  faz essa tradução.
- Acessível pelo botão "Depurar" na aba Código do editor, uma vez que
  o bot monta com sucesso.

### Persistência de verdade

- `lib/persistence/file_bot_file_access.dart` — implementação real de
  `BotFileAccess` com `dart:io`, resolvida dentro da pasta de
  documentos do app (nunca deixa um bot ler/escrever fora dela).
  Liga READFILE/WRITEFILE (0x93/0x94) nos arquivos `.dat` de cada bot
  de verdade — a `BattleScreen` já passa isso pro
  `installDefaultFactories`.
- `lib/persistence/local_bot_storage.dart` — a "biblioteca de bots"
  do app, usando `path_provider`. Cada bot vira dois arquivos: um
  **`.bot`** (formato 100% igual ao original, via `BotFile`) e um
  **`.asm`** com o código-fonte — o `.bot` compilado não tem como
  virar texto de novo, então o fonte precisa de um arquivo próprio
  pra poder reabrir no editor (isso é uma extensão do app, não muda o
  formato `.bot`). Ao carregar, o loadout de devices/RAM é lido
  direto do header do `.bot` (não precisa reassemblar o código pra
  saber isso). A config ativa (`ConfStruct`) persiste em
  `config.cfg`, no mesmo formato do `current.cfg` original.
- `lib/ui/home_screen.dart` agora carrega/salva/apaga bots de
  verdade (arrastar um card apaga, com desfazer visual do próprio
  `Dismissible`); `lib/ui/settings_screen.dart` é a tela nova de
  configurações (limites de custo/devices/RAM e quais devices estão
  liberados), persistida no mesmo `config.cfg`.

### Bugs de compilação reais, achados a partir de um ajuste manual seu

Você compilou o projeto e corrigiu alguns erros na mão; comparei seu
`lib.zip` com o meu e usei isso pra caçar a mesma classe de erro no
projeto inteiro, não só nos arquivos que você tinha mexido:

- **Imports faltando de `common_symbols.dart`**: `weapons/chaff.dart`
  (usa `destroySelf`) e `core/fuel.dart` (usa `fuelLevelInt`) — corrigidos.
- **Imports faltando de `assembler/assembler.dart`** (onde `DeviceSlot`
  é definido — não em `core/device.dart`): `ui/home_screen.dart`,
  `ui/widgets/device_picker_sheet.dart` e
  `persistence/local_bot_storage.dart` — corrigidos.
- **`clamp()` com tipo errado** em `ui/widgets/arena_painter.dart`:
  `double.clamp(1, 40)` com limites `int` volta como `num`, não
  `double`, e `Canvas.drawCircle` exige `double` — troquei pra
  `clamp(1.0, 40.0)`.
- **Índice fora da lista** em `TextModeBattleArea`/`BattleArea`: se
  `BattleConfig.names`/`teams` viesse com menos de 8 posições (ex.:
  uma partida com só 3 bots, como a tela de setup manda), o resto do
  código — que sempre itera até `maxBots`=8 — estourava índice. Em vez
  de guardas espalhadas pelo código, corrigi na raiz: o construtor de
  `BattleConfig` agora sempre normaliza `names`/`teams` pra exatamente
  8 posições (completando com vazio/0), do jeito que o `std::array<_,
  8>` do C++ original já garantia de fábrica.

Nenhum desses eu tinha como pegar sem compilar de verdade — obrigado
por rodar e mandar de volta.

### Perfis de configuração (com os 4 presets do jogo original)

Corrigindo uma limitação que você apontou: antes a tela de
configurações só tinha 3 números gerais + habilitar/desabilitar
device, com custo/valor sempre 0 por padrão. Agora:

- **4 presets reais**, com os valores extraídos direto de
  `misc/light.cfg`, `medium.cfg`, `heavy.cfg` e `ultralight.cfg` do
  repositório original (esses 4 arquivos usam um formato de texto
  mais antigo — `MAXDEVICES:`/`DEVICE:` — diferente do INI que
  `confstruct.cpp` carrega de verdade; extraí os valores de lá em vez
  de portar os dois formatos). `light` é idêntico ao `current.cfg`
  que o jogo já vem com — é o preset padrão.
- **Perfis múltiplos**: `LocalBotStorage` agora guarda vários `.cfg`
  nomeados em `configs/`, com um marcador de qual está ativo. Editar
  um preset de fábrica salva como cópia nova (não sobrescreve o
  original); dá pra criar do zero, duplicar, e apagar perfis
  personalizados.
- **Tela de configurações** reformulada: chips pra escolher o perfil
  no topo, e cada device agora abre numa `ExpansionTile` com
  custo/valor editáveis dos 5 níveis — os mesmos campos
  `<device>\<nível>\Cost`/`Value` do `current.cfg` original, não só
  habilitar/desabilitar.
- A tela de batalha agora carrega o perfil ativo de verdade antes de
  montar os bots (antes usava sempre um `ConfStruct()` em branco).

### Nave mais detalhada na arena

Trocado o triângulo liso do robô por um desenho vetorial mais
elaborado (ainda sem sprite, por decisão sua): casco em formato de
caça com asas em flecha, sombreamento em gradiente (lado claro/lado
escuro), cockpit (elipse clara perto do nariz), contorno fino, e
chama do motor atrás que aparece/cresce conforme a velocidade atual
do bot (`bot.speed()`, vindo de `Engine`/`Robots` de verdade — não é
decoração solta).

### Sprites originais de verdade (não mais vetorial)

Você não gostou do desenho vetorial — troquei pelos sprites reais do
jogo original. `images/*.png/.bmp/.xpm` do repositório C++ foram
convertidos (preto vira transparente) e copiados pra
`assets/images/` como PNG puro — inclusive os `.xpm` (`mine`,
`missile`, `rocket`), que o Flutter não decodifica nativamente.

- **`lib/ui/widgets/sprite_cache.dart`** — carrega as 13 imagens uma
  vez (`ship0`-`ship7`, `missile`, `mine`, `rocket`, `chaff`,
  `radarmissile`) e guarda como `dart:ui.Image` decodificada, porque
  `CustomPainter.paint` é síncrono. `BattleScreen` espera
  `SpriteCache.instance.ensureLoaded()` antes de montar a arena.
- **`arena_painter.dart`** agora desenha os sprites de verdade. O
  robô usa a MESMA lógica de seleção de quadro do `Robots::drawObject`
  original: cada `ship<slot>.png` é uma folha de 16 quadros
  pré-rotacionados (32x32 cada), e o quadro escolhido é
  `(direção + meioQuadro) / grausPorQuadro` — o `mynum` (slot 0-7) do
  bot escolhe o arquivo, exatamente como no C++
  (`":/images/ship" + mynum + ".png"`).
- `pubspec.yaml` ganhou a declaração `assets: - assets/images/`.

Fica faltando (não crítico): permitir que cada bot use sua própria
imagem customizada (`<nome>.png` no lugar do `ship<slot>.png` padrão)
— o original tinha essa opção; hoje sempre usa o skin do slot.
