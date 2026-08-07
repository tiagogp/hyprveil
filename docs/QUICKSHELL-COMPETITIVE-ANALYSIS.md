# Benchmark competitivo: Hyprland + Quickshell

> **Data de corte:** 6 de agosto de 2026
> **Linha-base do Hyprveil:** commit `9cb2381`, branch local consultada em 6 de
> agosto de 2026
> **Escopo:** análise documental; nenhuma mudança de QML, script, API ou
> comportamento do desktop faz parte deste trabalho.

## Resumo executivo

O Hyprveil já tem uma base mais disciplinada que muitos projetos de aparência
semelhante: superfícies Quickshell por monitor, três níveis responsivos, dock com
aplicativos em execução, Quick Settings funcional, lock nativo com fallback,
movimento reduzido, propagação consistente de tokens e um instalador conservador.
Sua identidade — vidro escuro, pouca densidade, blur controlado e animação
funcional — também é mais clara que a de shells que tentam demonstrar todos os
efeitos ao mesmo tempo.

A distância para os líderes está menos na barra e mais nos fluxos completos.
[Caelestia](#caelestia-shell) e [end-4](#end-4dots-hyprland) transformam o
launcher em uma central de ações; [DankMaterialShell](#dankmaterialshell-dms)
entrega notificações agrupadas, calendário com eventos, busca extensível e
preferências abrangentes; [Noctalia v4](#noctalia-v4--referência-histórica)
oferecia a referência mais clara de configuração gráfica e extensibilidade;
[Silere](#silere-shell) trata ausência de serviços e medição de desempenho com
uma simplicidade particularmente compatível com o Hyprveil.

As cinco lacunas mais importantes são: launcher nativo, brilho no painel,
notificações persistentes e agrupadas, workspaces/dock dinâmicos e uma interface
gráfica de preferências de escopo controlado. Calendário com eventos, Matugen
opcional e configurações por monitor vêm logo depois. A recomendação não é
converter o Hyprveil em uma desktop shell maximalista: é adotar os fluxos e os
limites técnicos que funcionam, mantendo a apresentação calma.

## Metodologia

### Fontes e grau de evidência

As fontes foram consultadas até a data de corte e classificadas assim:

- **C — código/repositório:** estrutura, dependências, módulos e comportamento
  verificáveis no repositório.
- **M — mantenedor:** README, documentação, release, issue ou anúncio oficial.
- **U — usuário/comunidade:** Reddit, r/unixporn, r/hyprland e fóruns. Serve
  para validar instalação e uso real; não substitui a inspeção do código.
- **V — visual:** vídeo ou showcase. Serve para avaliar hierarquia, transições e
  fluxo, não para comprovar arquitetura ou desempenho.

Cada projeto foi avaliado na branch principal e no estado visível em 6 de agosto
de 2026, salvo quando uma versão é indicada. Contagens de estrelas ou votos
mudam continuamente e, por isso, são usadas apenas como sinal de alcance, não
como nota de qualidade. Issues representam ocorrências documentadas, não uma
estimativa de prevalência.

O baseline do Hyprveil foi obtido do QML, scripts, documentação, screenshots e
testes no próprio commit informado acima. Para concorrentes, repositórios e
documentação oficial têm precedência; Reddit e YouTube foram usados para
contrastar as declarações com experiência pública e comportamento visual.

### Como ler desempenho

Não há benchmark equivalente entre os projetos. **RSS** inclui páginas
compartilhadas e tende a superestimar o custo exclusivo; **PSS** divide páginas
compartilhadas entre processos; **USS** aproxima memória privada. Números com
hardware, versão, cenário ou métrica diferentes não são comparados diretamente.
Quando um projeto não publica medição reproduzível, a tabela diz “não publicado”
e a nota considera apenas evidências arquiteturais: polling, subprocessos,
carregamento sob demanda, renderização por monitor e trabalho em segundo plano.

### Critério das notas

As notas vão de 1 a 5. Qualidade visual mede coerência, hierarquia e aderência a
uma experiência calma — não a quantidade de efeitos. Usabilidade mede conclusão
de tarefas e navegação por teclado; personalização mede alcance e previsibilidade;
arquitetura mede separação de responsabilidades e extensibilidade; desempenho
mede evidência disponível e risco arquitetural; documentação mede instalação,
referência e troubleshooting.

Confiança: **A** = código e documentação convergem, com validação comunitária;
**M** = evidência primária suficiente, mas pouca validação independente;
**B** = README/showcase ou inferência arquitetural, sem medição comparável.

## Linha-base verificável do Hyprveil

| Área | Estado em `9cb2381` | Consequência competitiva |
|---|---|---|
| Barra | Instância por monitor; modos completo, padrão e compacto; workspaces 1–5, janela, mídia, tray e status | Boa base responsiva, mas workspaces são fixos |
| Quick Settings | Wi-Fi, Bluetooth, saída/entrada e streams de áudio, night light, perfil de energia, clipboard, DND, accent e atalhos | Cobertura diária forte; falta brilho e uma navegação de preferências mais ampla |
| Brilho | Teclas/OSD e helper; sem slider no painel | Laptop e monitor externo exigem um fluxo fora do painel |
| Notificações | Servidor DBus nativo, ações, imagens, markup, DND, popups e histórico | Histórico só em memória da sessão e sem agrupamento |
| Calendário | Mês navegável, sem fontes de eventos | Bom glance visual, utilidade limitada |
| Launcher e sessão | Rofi e wlogout externos | Tema coeso, mas estado, animação e teclado não formam um fluxo Quickshell único |
| Dock | Apps fixados e em execução, reordenação e resolução de desktop entries | Agrupamento por classe é simples e não expõe bem múltiplas janelas |
| Lock | `WlSessionLock`/PAM, mídia, bateria, rede e fallback seguro para hyprlock | Diferencial positivo de resiliência |
| Cores | Algoritmo próprio de accent, presets e renderizadores para o desktop inteiro | Coeso e controlável; Matugen não é um provider opcional |
| Movimento | Perfis padrão/reduzido e chave global | Melhor base de acessibilidade que muitos showcases |
| Monitores | Superfícies por tela, wallpaper/fit por monitor e três breakpoints de barra | Falta preferência gráfica por monitor e regras mais granulares de localização |
| Falhas | Fallbacks de notificações/lock, probing de fontes, recovery e testes mockados | Base madura; faltam estado de capacidade e diagnóstico dentro da shell |

## Matriz de capacidades

Legenda: **●** integrado; **◐** parcial, externo ou limitado; **—** ausente ou não
documentado; **H** disponível apenas na versão histórica analisada.

### Fluxos de interface

| Projeto | Barra | Quick settings | Wi-Fi / BT / áudio | Brilho | Notificações | Calendário | Sessão | Launcher | Dock / workspaces | Mídia / tray | Lock |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **Hyprveil** | ● | ● | ● | ◐ OSD | ◐ sessão | ◐ mês | ◐ wlogout | ◐ Rofi | ◐ fixos | ● | ● + fallback |
| **Caelestia** | ● | ● | ● | ● interno/DDC | ● | ● | ● | ● multiprovider | ● | ● | ● + fingerprint |
| **end-4** | ● | ● | ● | ● | ● | ● | ● | ● multiprovider | ● overview | ● | ● |
| **DMS** | ● | ● | ● | ● hotplug | ● agrupadas | ● eventos | ● | ● extensível | ● | ● | ● |
| **Noctalia v4** | H | H | H | H interno/DDC | H | H eventos | H | H providers | H | H | H |
| **tripathiji1312** | ● | ● | ● | ● | ● | — | ◐ | ● | ◐ | ● / ◐ | — |
| **Silere** | ● | ● | ● | ● | ● | ◐ mês | ◐ | — | ◐ workspaces | ● | — |
| **ChillPill** | ● | ● | ◐ sem BT | ● | ● | ◐ mês | ● | ● | ◐ fixos | ● / — | ◐ externo |

“—” não prova que uma integração seja impossível; indica que ela não apareceu
na documentação/código público consultado com confiança suficiente.

### Plataforma, personalização e operação

| Projeto | Wallpaper / temas | Cores / Matugen | Animação | Responsivo | Multi-monitor | Organização | Instalação | Ausência de serviços | Dados de memória |
|---|---|---|---|---|---|---|---|---|---|
| **Hyprveil** | ● fit por tela | ● próprio / sem Matugen | ● + reduzido | ● 3 níveis | ● | módulos + singletons/serviços | Fedora, cuidadosa | ● fallbacks | não publicado |
| **Caelestia** | ● variantes | ● material | ● morphing | ● | ● overrides | components/modules/services/utils + plugin C++ | AUR/Nix/manual | ◐ muitas dependências | não publicado |
| **end-4** | ● | ● material | ● intensa | ●, issues de escala | ● | shell integrado + scripts | instalador próprio | ◐ | não publicado |
| **DMS** | ● por tela | ● Matugen/dank16 | ● | ● | ● | QML modular + serviços/CLI Go | Fedora/Debian/Nix/Arch | ● capability-aware | não publicado |
| **Noctalia v4** | H automação/tela | H vários geradores | H | H | H | QML + plugins + fork QS | várias distros | H | ~300 MB/monitor, mantenedor, métrica não informada |
| **tripathiji1312** | ● | ◐ pywal | ● shaders | ◐ | ◐ | components/modules/services/config | script Arch | ● troubleshooting | não publicado |
| **Silere** | ● | ● Matugen/manual | ● discreta | ◐ | ◐ | módulos/serviços opcionais | script + backup | ● check/hide | 101 MB PSS / 76 MB USS, autor, 1 máquina |
| **ChillPill** | ◐ | — | ● pill | ◐ | ◐ | módulos + JSONC | Arch/manual | ◐ | 200–500 MB, autor, métrica não informada |

## Projetos analisados

### Caelestia Shell

1. **Nome, link e estado.** [caelestia-dots/shell](https://github.com/caelestia-dots/shell),
   acompanhado pelo repositório de
   [dotfiles Caelestia](https://github.com/caelestia-dots/caelestia). Projeto
   ativo e de alto alcance na data de corte. Branch principal consultada em
   6/8/2026. Evidências: C/M; o
   [showcase no YouTube](https://www.youtube.com/watch?v=6QJXZixpmQs) e o
   [post V2 no r/unixporn](https://www.reddit.com/r/unixporn/comments/1tzdeeb/hyprland_i_3_quickshell_v2/)
   foram usados apenas para validar fluxo e recepção visual (U/V).
2. **Tecnologias.** Quickshell/QML, Hyprland, plugin compilado com CMake e
   `caelestia-cli`; integra NetworkManager, PipeWire, `brightnessctl`, `ddcutil`,
   sensores, Cava e serviços de mídia/clima conforme os módulos habilitados.
   A árvore separa `components`, `modules`, `services` e `utils`.
3. **Principais recursos.** Barra fluida com workspaces, janelas e tray;
   dashboard; launcher de apps, ações, cálculo, wallpaper e sessão; mídia com
   visualização/letras; notificações; VPN; brilho interno e DDC; lock com
   fingerprint; configuração JSON e overrides por monitor.
4. **O que faz melhor que o Hyprveil.** O launcher nativo conclui ações sem
   mudar para Rofi; brilho de monitores externos faz parte do mesmo painel;
   configuração por monitor é mais ampla; dashboard e lock biométrico cobrem
   cenários que o Hyprveil não cobre.
5. **O que adaptar sem copiar o design.** Adotar providers de launcher, um
   `MonitorSettings` com herança global, DDC opcional e uma visão de mídia mais
   rica somente quando expandida. A barra morphing não precisa ser reproduzida:
   o padrão útil é a continuidade de estado entre compacto e detalhado.
6. **Limitações/problemas.** A instalação manual depende de Quickshell Git e de
   uma lista grande de serviços; parte das opções continua global. Há relatos de
   conflito de startup e compatibilidade em
   [discussion #768](https://github.com/caelestia-dots/shell/discussions/768),
   falha de lock em [issue #675](https://github.com/caelestia-dots/shell/issues/675)
   e comentários comunitários sobre Qt/Fedora, escala e mudanças do Hyprland.
   Efeitos e densidade padrão são altos para a identidade do Hyprveil. Não há
   benchmark público comparável.

### end-4/dots-hyprland

1. **Nome, link e estado.** [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland),
   ativo e entre as referências mais populares. Branch principal e
   [documentação](https://ii.clsty.link) consultadas em 6/8/2026. O
   [showcase oficial](https://www.youtube.com/watch?v=RPwovTInagE) e o
   [post do r/unixporn](https://www.reddit.com/r/unixporn/comments/1ls4xdv/hyprland_my_virginity_defense_ft_quickshell/)
   complementam a avaliação visual (U/V).
2. **Tecnologias.** Hyprland, Quickshell/QML, scripts e integrações externas para
   IA, OCR/tradução, busca visual, captura e geração de tema.
3. **Principais recursos.** Overview de janelas ao vivo, launcher e comandos,
   settings, sidebar, wallpaper com paleta Material, Gemini/Ollama, tradução de
   tela, Google Lens e tratamento “anti-flashbang”.
4. **O que faz melhor que o Hyprveil.** Pesquisa e ações são integradas em um
   fluxo de teclado; overview fornece contexto de janelas que o dock simples não
   mostra; utilitários de screenshot/OCR e a UI de settings reduzem ida ao
   terminal.
5. **O que adaptar sem copiar o design.** Um índice de apps/janelas/ações, preview
   discreto de janelas e um pipeline de captura extensível. IA deve ser provider
   opcional, nunca superfície ou dependência padrão.
6. **Limitações/problemas.** Grande superfície e muitas integrações aumentam
   dependências e risco de atualização. O próprio README alerta para transições
   incompatíveis do Hyprland; há regressões de
   [escala](https://github.com/end-4/dots-hyprland/issues/1479) e
   [startup após atualização](https://github.com/end-4/dots-hyprland/issues/2062).
   Comentários comunitários também citam icon mapping e shaders. A estética e a
   quantidade de informação são mais intensas que a proposta calma do Hyprveil.
   Não há benchmark equivalente publicado.

### DankMaterialShell (DMS)

1. **Nome, link e estado.** [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell),
   ativo, com pacotes e releases frequentes. Branch principal,
   [documentação oficial](https://danklinux.com/docs/) e
   [releases](https://github.com/AvengeMedia/DankMaterialShell/releases)
   consultadas em 6/8/2026. Há uma
   [análise em vídeo](https://www.youtube.com/watch?v=mtrRsKETneY) e um
   [release no r/unixporn](https://www.reddit.com/r/unixporn/comments/1r89mk3/oc_dankmaterialshell_14_saffron_bloom_released/).
2. **Tecnologias.** Quickshell/QML em `Modules`, `Services`, `Widgets` e `Common`,
   com backend e CLI em Go. Integra Matugen/dank16, dsearch, dgop, PipeWire,
   NetworkManager, Bluetooth, display/brightness e múltiplos compositores.
3. **Principais recursos.** Control center abrangente; launcher Spotlight para
   apps, arquivos, emoji, janelas, cálculo, comandos e plugins; notificações
   agrupadas; calendário sincronizado; clipboard com imagens; monitor de sistema;
   dock, tray, MPRIS, weather, lock/idle; temas de wallpaper aplicados a apps;
   registro de plugins.
4. **O que faz melhor que o Hyprveil.** É a implementação mais completa dos
   fluxos ausentes: pesquisa extensível, notificações agrupadas, eventos,
   display/brilho e preferências. A separação QML/Go evita transformar todo
   trabalho de I/O em bindings e subprocessos QML.
5. **O que adaptar sem copiar o design.** Registry pequeno de providers, estados
   de capacidade, carregadores assíncronos, agrupamento por app/thread,
   persistência limitada e uma UI de preferências baseada em schema. Manter os
   tokens visuais do Hyprveil em vez de imitar Material 3.
6. **Limitações/problemas.** É praticamente uma camada de desktop completa e
   requer serviços próprios em Go. As
   [notas de release](https://github.com/AvengeMedia/DankMaterialShell/releases)
   registram correções recorrentes de VRAM, frame rate de mídia, unloading do
   launcher, hotplug, tray, overview e crashes de notificações: sinal de boa
   manutenção, mas também do custo do escopo. Memória comparável não foi
   publicada.

### Noctalia v4 — referência histórica

1. **Nome, link e estado.** [noctalia-dev/noctalia-shell](https://github.com/noctalia-dev/noctalia-shell),
   release final v4.7.7 (`3abfa1f`), é analisado exclusivamente como referência
   histórica Quickshell. A linha v4 está congelada/manutenção; sua
   [documentação permanece disponível](https://docs.noctalia.dev/v4/getting-started/installation/).
   O
   [Noctalia v5](https://github.com/noctalia-dev/noctalia) atual foi reescrito do
   zero em C++, sem Qt ou Quickshell, conforme o
   [anúncio de 24/4/2026](https://noctalia.dev/blog/announcing-noctalia-v5).
2. **Tecnologias.** Quickshell/QML por meio do fork `noctalia-qs`, Hyprland e um
   sistema de plugins QML. DDC, EDS e integrações adicionais eram opcionais.
3. **Principais recursos.** Configuração gráfica de quase toda a shell;
   [plugins](https://docs.noctalia.dev/v4/development/plugins/overview/) para
   barra, desktop, control center, providers do launcher, painéis, settings,
   tradução e IPC; wallpapers por monitor; eventos via EDS; brilho DDC; modos de
   cor incluindo monocromático e muted; interface IPC documentada.
4. **O que fazia melhor que o Hyprveil.** Preferências e extensões eram
   descobríveis sem editar QML; calendário recebia eventos; brilho e wallpaper
   tratavam múltiplos monitores; documentação cobria instalação e keybinds com
   profundidade.
5. **O que adaptar sem copiar o design.** Schema de settings que gera controles,
   extension points limitados e versionados, providers de cor e indicadores de
   disponibilidade. A migração v5 é também uma lição: controlar quantas
   superfícies e engines se duplicam por monitor.
6. **Limitações/problemas.** O fork customizado podia conflitar com Quickshell
   upstream e plugins v4 não migram automaticamente. O mantenedor relata cerca
   de 300 MB por monitor na v4 e aproximadamente um sexto disso na v5; a métrica
   e o cenário não foram publicados, portanto o valor não é comparável aos
   números PSS/USS do Silere. A reescrita foi motivada por memória, empacotamento
   Qt e custo de bindings — evidência forte contra crescimento QML sem orçamento,
   mas não contra Quickshell em si.

### tripathiji1312/quickshell

1. **Nome, link e estado.** [tripathiji1312/quickshell](https://github.com/tripathiji1312/quickshell),
   projeto menor, ativo, com v1.0 publicada em maio de 2026. Branch principal
   consultada em 6/8/2026.
2. **Tecnologias.** Quickshell 0.2+, Qt 6.10+, Hyprland, QML, shaders, pywal e um
   script de setup voltado a Arch. A árvore explicita `components`, `modules`,
   `services` e `config`; `shell.json` recarrega via `FileView`.
3. **Principais recursos.** Barra, OSD, notificações, dashboard, launcher/sidebar
   e serviços separados de áudio, brilho, Bluetooth, rede, bateria e player.
4. **O que faz melhor que o Hyprveil.** A fronteira entre configuração, serviço
   e apresentação é especialmente fácil de estudar; launcher e serviço de
   brilho já são internos; o troubleshooting nomeia conflitos de daemon e
   serviços ausentes.
5. **O que adaptar sem copiar o design.** Um singleton de configuração validado,
   contratos pequenos por serviço e uma página de health/status no startup.
   Shaders devem permanecer opcionais e fora dos componentes básicos.
6. **Limitações/problemas.** Setup centrado em Arch, primeiro ciclo do pywal
   manual, exigência alta de Qt e comunidade pequena. Calendário, lock, dock e
   algumas integrações não estão documentados com clareza. Não há medição de
   desempenho comparável.

### Silere Shell

1. **Nome, link e estado.** [s3rven/silere-shell](https://github.com/s3rven/silere-shell),
   jovem e de baixo alcance, incluído como contraponto técnico e de identidade,
   não como líder de popularidade. Branch principal consultada em 6/8/2026.
2. **Tecnologias.** Quickshell/QML, Hyprland, Matugen opcional, PipeWire,
   NetworkManager, brightnessctl e Cava opcional; scripts de instalação, check e
   benchmark.
3. **Principais recursos.** Barra, workspaces, mídia, volume, brilho, bateria,
   rede e tray; control center e settings; notificações com DND/histórico;
   accent manual ou Matugen; night light. A proposta declarada é “quiet by
   default”.
4. **O que faz melhor que o Hyprveil.** Preferências gráficas e brilho estão no
   painel; módulos opcionais se escondem sem serviço; `check.sh` verifica imports,
   serviços e notificações; `bench.sh` explicita uma metodologia PSS/USS.
5. **O que adaptar sem copiar o design.** Doctor integrado, módulo opt-in,
   benchmark versionado e política de pausar visualizadores quando mídia/tela
   estão inativas. A filosofia silenciosa combina diretamente com o Hyprveil.
6. **Limitações/problemas.** Projeto pequeno, sem validação comunitária ampla e
   sem histórico de releases. O autor mediu 101 MB PSS, 76 MB USS e 0,8% CPU para
   Quickshell (aprox. 106 MB PSS com watchers) em uma única máquina; não é
   reprodução independente. Ajustes de jemalloc/EGL e imports opcionais precisam
   ser validados no Fedora antes de adoção.

### ChillPill Shell

1. **Nome, link e estado.** [LUCKYS1NGHH/ChillPill-Shell](https://github.com/LUCKYS1NGHH/ChillPill-Shell),
   ativo e ainda jovem. Branch principal consultada em 6/8/2026. O lançamento
   foi demonstrado no
   [r/unixporn](https://www.reddit.com/r/unixporn/comments/1uv3atu/hyprland_quickshell_pill_bar_chillpillshell_for/)
   e discutido no
   [r/hyprland](https://www.reddit.com/r/hyprland/comments/1uv3d5e/quickshell_pill_bar_chillpillshell_for_no/).
2. **Tecnologias.** Quickshell/QML, backend próprio construído com CMake,
   Hyprland, JSONC, DBus notifications, NetworkManager, PipeWire, brightnessctl,
   cliphist e serviços de weather.
3. **Principais recursos.** Pill dinâmica; barra de bateria/volume/workspaces/
   rede/clock; control center com mídia, Wi-Fi, notificações, timer, volume e
   brilho; clipboard com imagens; dashboard com perfil, tráfego, weather,
   calendário e sessão; OSDs e Wi-Fi com senha.
4. **O que faz melhor que o Hyprveil.** Clipboard visual, timer e dashboard
   entregam muita utilidade em área pequena; a notificação pode assumir uma
   apresentação fullscreen; o projeto declara atenção a hardware antigo.
5. **O que adaptar sem copiar o design.** Preview de imagem no clipboard e um
   único “status capsule” temporário para volume, timer ou hotspot — sem deixar a
   barra morphing permanentemente. Usar o objetivo de hardware fraco como
   orçamento verificável, não como claim visual.
6. **Limitações/problemas.** Testado principalmente em Arch/Hyprland, workspaces
   continuam limitados por configuração, Bluetooth/tray/Matugen não estão claros
   e a maturidade é inicial. O autor relata 200–500 MB de memória e média de 15%
   de GPU em um i5-3337U/Intel HD 4000, mas não identifica RSS/PSS/USS nem cenário;
   portanto não é comparável e não confirma baixo consumo.

## Comparação geral

| Projeto | Recursos exclusivos | Qualidade visual | Usabilidade | Personalização | Arquitetura | Desempenho | Documentação | Ideias relevantes para o Hyprveil |
|---|---|---:|---:|---:|---:|---:|---:|---|
| **Hyprveil (base)** | fallback seguro, fit por monitor, pipeline amplo de tokens, motion reduzido | **4,5 A** | **4,0 A** | **3,5 A** | **4,5 A** | **4,0 B** | **4,5 A** | Preservar calma, resiliência e escopo Fedora |
| **Caelestia** | launcher multiprovider, DDC, dashboard, fingerprint, overrides por tela | **4,5 A** | **4,5 A** | **4,5 A** | **4,5 M** | **3,0 B** | **4,0 A** | Providers, monitor settings, brilho externo |
| **end-4** | overview, OCR/tradução, busca visual, IA, anti-flashbang | **4,0 A** | **4,5 M** | **4,0 M** | **4,0 M** | **2,5 B** | **3,5 M** | Apps+janelas+ações e captura modular |
| **DMS** | plugins, arquivos/emoji, eventos, processos, multi-compositor | **4,0 A** | **5,0 A** | **5,0 A** | **5,0 A** | **3,5 M** | **5,0 A** | Registry, backend de I/O, agrupamento, lazy load |
| **Noctalia v4 (hist.)** | settings quase total, plugins QML, EDS, IPC documentado | **4,5 A** | **5,0 A** | **5,0 A** | **4,5 A** | **2,5 M** | **5,0 A** | Schema de settings e alerta de escala QML |
| **tripathiji1312** | config hot reload, arquitetura didática, shaders | **3,5 M** | **3,5 M** | **4,0 M** | **4,5 M** | **3,5 B** | **4,0 M** | Contratos simples entre config/service/UI |
| **Silere** | quiet-by-default, doctor, benchmark PSS/USS | **4,0 M** | **4,0 M** | **4,0 M** | **4,0 M** | **4,5 M** | **4,0 M** | Capability states e orçamento mensurável |
| **ChillPill** | pill, timer, clipboard visual, fullscreen notification | **4,0 M** | **4,0 M** | **3,0 M** | **3,5 M** | **3,0 B** | **3,5 M** | Status transitório e clipboard com imagens |

A nota de desempenho não é ranking de megabytes. Em especial, o 4,0 B do
Hyprveil é uma avaliação arquitetural provisória; deve ser substituído por uma
linha-base PSS/USS reproduzível. A nota alta do Silere tem confiança M porque o
script e as métricas são explícitos, mas a medição continua sendo do autor. A
Noctalia v4 recebe nota histórica e não deve ser confundida com a v5 nativa.

## Triagem de projetos não aprofundados

- [Nucleus](https://github.com/nucleus-hq/nucleus-shell) tem plugins, settings e
  CLI interessantes, mas o próprio projeto anunciou arquivamento e encerramento
  da reescrita. É uma referência de ideias, não uma base sustentável.
- [SELFshell](https://github.com/TripShuti/SELFshell) é uma configuração pessoal
  experimental, pequena e explicitamente dependente de hardware, caminhos e
  credenciais do autor; a generalização seria especulativa.
- [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) é popular e
  bem documentado como distribuição de dotfiles, mas usa Quickshell de forma
  parcial/opcional. É relevante para onboarding e compatibilidade, não para uma
  comparação de arquitetura de shell integrada.

## Análise estratégica

### Recursos essenciais ausentes

1. **Launcher Quickshell nativo e enxuto.** Caelestia, end-4 e DMS mostram que
   apps, janelas e ações no mesmo índice reduzem troca de contexto. O Rofi atual
   do Hyprveil não compartilha estado, animação nem providers com a shell.
   Adotar apps + janelas + cinco ações de sistema no MVP; arquivos, cálculo e
   plugins ficam desligados por padrão.
2. **Brilho no Quick Settings, com duas capacidades.** Caelestia, DMS e Noctalia
   v4 distinguem backlight interno de DDC. O Hyprveil já tem helper/OSD, portanto
   a lacuna é de serviço observável e slider, não de keybind. Sem dispositivo, o
   controle deve sumir ou explicar indisponibilidade.
3. **Persistência e agrupamento de notificações.** DMS agrupa conversas/apps e
   shells líderes preservam histórico; hoje o Hyprveil perde tudo ao reiniciar.
   Persistir um conjunto limitado, agrupar por app/categoria e respeitar hints de
   privacidade fecha a lacuna sem criar um inbox complexo.
4. **Workspaces e janelas dinâmicos.** Overview do end-4 e modelos de Caelestia/
   DMS representam estado real. O conjunto fixo 1–5 e uma tile por classe no
   Hyprveil escondem workspaces especiais e múltiplas janelas. Exibir somente
   workspaces ocupados + vizinhos e abrir um seletor de janelas na tile agrupada.
5. **Preferências gráficas de escopo controlado.** Noctalia v4, DMS e Silere
   tornam aparência, módulos e integrações descobríveis. O Hyprveil deve editar
   apenas uma configuração versionada própria — nunca os QML gerados — e expor
   barra, dock, motion, wallpaper, accent e módulos opcionais.

### Melhorias de experiência

- **Calendário útil, mas opcional:** eventos EDS fizeram a diferença na Noctalia
  v4 e DMS. Mostrar próximos três eventos e abrir a agenda configurada; quando EDS
  não existe, manter o calendário mensal atual sem erro ou spinner eterno.
- **Detalhe progressivo no painel:** Caelestia e DMS começam com resumo e abrem
  detalhe. O Hyprveil deve manter poucos toggles visíveis e usar uma segunda
  camada para dispositivos Wi-Fi/BT, streams e saídas de display.
- **Teclado consistente entre superfícies:** launcher, painel, notificações,
  wallpaper e power devem compartilhar Escape, setas, Enter, foco inicial e
  busca. end-4 demonstra o ganho de um fluxo keyboard-first; o Hyprveil já tem
  bons hit targets e cheatsheet para sustentar a convenção.
- **Clipboard com preview seguro:** DMS e ChillPill mostram imagens; o Hyprveil
  pode carregar thumbnails sob demanda, limitar dimensão/memória e nunca mostrar
  conteúdo marcado sensível no lock.
- **Preferências por monitor:** Caelestia e Noctalia tratam overrides. Permitir
  posição da barra/dock, wallpaper/fit, escala visual e monitor preferido para
  popups, herdando defaults globais.
- **Estado de saúde visível:** o `check.sh` do Silere e o troubleshooting do
  tripathiji1312 devem virar “Sistema > Integrações”: disponível, ausente,
  degradado e comando de correção. Isso torna os fallbacks existentes do
  Hyprveil descobríveis.

### Melhorias técnicas

- **Contrato único de serviços.** Cada integração deve expor `available`,
  `state`, `busy`, `error`, `lastUpdated` e ações idempotentes. DMS e a separação
  didática do tripathiji1312 mostram o padrão; ele elimina condições especiais
  espalhadas pelos componentes.
- **Configuração tipada, migrável e observável.** Inspirar-se no schema do
  Noctalia e no `shell.json` do tripathiji1312: defaults, versão, validação,
  migração e escrita atômica. Componentes recebem propriedades; não leem arquivos
  nem executam comandos diretamente.
- **`SurfaceContext` por monitor.** Concentrar screen, scale tier, preferências,
  wallpaper, posição de popup e safe area. Caelestia mostra o valor do override;
  a lição de memória da Noctalia v4 exige compartilhar serviços globais em vez de
  duplicá-los para cada tela.
- **Coordenador de superfícies.** Um estado central garante um painel modal por
  monitor, restaura foco e resolve exclusão entre launcher, Quick Settings,
  calendário, notificações e power. Isso adapta a continuidade visual de
  Caelestia sem copiar morphing.
- **Carregamento sob demanda.** Releases do DMS citam unloading de launcher,
  loaders assíncronos e throttling de mídia. Calendário EDS, thumbnails,
  visualização e providers de arquivo não devem iniciar no boot.
- **Persistência pequena e resiliente.** Usar estado sob XDG, escrita atômica,
  schema versionado, limite de itens/tamanho e recuperação de arquivo corrompido
  para notificações e clipboard. Nenhum banco é necessário no primeiro ciclo.
- **Adapter de paleta.** Preservar o algoritmo Hyprveil como padrão e adicionar
  Matugen apenas como provider que produz os mesmos tokens. DMS/Silere provam a
  utilidade; a camada impede que Material 3 determine layout ou densidade.
- **Benchmark reproduzível.** Adaptar o `bench.sh` do Silere: registrar commit,
  Quickshell/Qt, GPU, monitores, escala, PSS/USS/RSS e CPU em idle, mídia,
  launcher e notificações. Resultados sem esses metadados não entram em regressão.

### Diferenciais possíveis

1. **Calm Mode como contrato, não preset.** Silere valida “quiet by default”. No
   Hyprveil, isso pode combinar DND contextual, mídia colapsada, tray sob demanda,
   pausa de animação em bateria e nenhuma visualização contínua por padrão.
2. **Shell confiável e explicável.** Unir fallbacks já existentes a health UI,
   recovery e status de capacidade criaria uma história de confiabilidade que
   Caelestia/end-4 não priorizam na apresentação.
3. **Cenas por monitor.** Wallpaper, fit, accent, posição de superfícies e
   comportamento de popup como perfil de “mesa”, “laptop” ou “apresentação”. É
   uma evolução natural do suporte por monitor já existente.
4. **Acessibilidade como feature visível.** Motion reduzido, blur reduzido,
   contraste, tamanho e navegação de teclado podem formar um painel coerente; não
   apenas flags dispersas.
5. **Orçamento de serenidade.** Toda feature nova declara custo de boot,
   processos, polling, PSS e ruído visual. Essa disciplina responde diretamente
   à reescrita da Noctalia v5 e aos ciclos de otimização do DMS.

Ideias deliberadamente rejeitadas como padrão: IA/sidebar do end-4, visualizador
sempre ativo, morphing constante de Caelestia/ChillPill, marketplace de plugins
com poder irrestrito e reprodução literal do Material 3. Podem existir como
extensões futuras, mas conflitam com o escopo Fedora, a baixa densidade e a
identidade sem estética neon/gamer.

### Roadmap recomendado

Cada entrega abaixo é rastreada como um item de checklist (`- [ ]`/`- [x]`),
marcado feito somente depois de implementado E verificado — pelos testes
automatizados existentes (`tests/run.sh`) quando aplicável, ou por evidência
equivalente quando o item é infraestrutura sem hardware/serviço presente no
ambiente de desenvolvimento. Status registrado em 6/8/2026, no mesmo commit
mencionado no cabeçalho deste documento.

#### Prioridade alta — essenciais para o uso diário

- [x] **Serviço + slider de brilho** — controle único para laptop/monitor;
  Caelestia/DMS/Noctalia.
  - Dependências: wrapper existente, brightnessctl, ddcutil opcional.
  - Risco: mapeamento DDC e hotplug.
  - Critério de conclusão: backlight e DDC testados; ausente/degradado não
    quebra painel; teclado e slider sincronizam.
  - Implementado em `Services/Brightness.qml` (probe único de backlight +
    probe/porta DDC sob demanda) e `Panel/BrightnessSection.qml`; o gate
    leve mantém o carregamento real do QML via `tests/qml-load-smoke.sh`.
- [x] **Launcher nativo MVP** — apps, janelas e ações em um fluxo;
  Caelestia/end-4/DMS.
  - Dependências: índice desktop, Hyprland IPC, coordenador de foco.
  - Risco: latência e ranking.
  - Critério de conclusão: abre quente em meta definida após medir baseline;
    teclado completo; Rofi permanece fallback.
  - Implementado em `Launcher/Launcher.qml` (apps + janelas + 5 ações de
    sistema, navegação por teclado completa, `$mod`/`$mod+Space` reatribuídos
    à IPC do launcher, Rofi mantido em `$mod SHIFT+Space`); baseline de
    abertura é o que `tests/bench.sh` mede no cenário `launcher`.
- [x] **Notificação persistente/agrupada** — histórico sobrevive a restart;
  DMS.
  - Dependências: store XDG, schema, hints DBus.
  - Risco: dados sensíveis/corrupção.
  - Critério de conclusão: agrupamento por app, limite/expiração, ações
    preservadas, privacidade e recovery testados.
  - Implementado em `hypr/scripts/notification-store.sh` (JSON atômico sob
    XDG state, limite de 200, apenas metadados — nunca o corpo da mensagem —
    e recovery de arquivo malformado com backup) e `Notif/Popups.qml` +
    `Panel/NotificationSection.qml` (agrupamento por app em "Earlier").
- [x] **Workspaces/dock dinâmicos** — estado real e múltiplas janelas;
  end-4/Caelestia/DMS.
  - Dependências: IPC existente, modelo de janelas.
  - Risco: churn de classes/títulos.
  - Critério de conclusão: ocupados + vizinhos + especiais; tile agrupada
    lista/ativa/fecha a janela correta.
  - Implementado em `Services/Compositor.qml` (`visibleWorkspaceIds`/
    `occupiedWorkspaceIds`, `toplevelsForClass`), `Bar/Workspaces.qml`
    (substituiu o modelo fixo `5`) e `Dock/WindowPicker.qml` (seletor
    multi-janela por tile agrupada).
- [x] **Capability model + doctor** — falha deixa de ser silenciosa;
  Silere/tripathiji1312.
  - Dependências: contrato de serviços, página de status.
  - Risco: mensagens inconsistentes.
  - Critério de conclusão: toda dependência opcional aparece como
    disponível/ausente/degradada com fallback e correção.
  - Implementado em `hypr/scripts/doctor.sh` (texto e `--json`, única fonte
    de verdade) e `Services/Capabilities.qml` + `Panel/Integrations.qml`
    ("Sistema > Integrações"), cobrindo backlight, DDC, Bluetooth, night
    light, power profiles, clipboard, screenshot/OCR, Matugen e eventos EDS.
- [x] **Baseline de desempenho** — evita repetir escala da Noctalia v4;
  Silere/DMS.
  - Dependências: script de cenário e coleta smaps.
  - Risco: variância entre execuções.
  - Critério de conclusão: commit/ambiente/PSS/USS/RSS/CPU registrados; CI
    falha apenas contra baseline equivalente e tolerância documentada.
  - Implementado em `tests/bench.sh` (metadados de commit/Quickshell/GPU/
    monitores/escala, PSS/USS/RSS/CPU via `/proc/<pid>/smaps_rollup`,
    cenários idle/launcher/notifications); `tests/bench.sh --check` roda em
    CI sem sessão Wayland e está incluído em `tests/run.sh`. Regressão
    numérica automatizada (comparar contra uma baseline salva com
    tolerância) ainda não existe — falta um segundo commit que grave e
    compare contra uma baseline versionada; o script em si já é reprodutível.

#### Prioridade média — aumentam a qualidade do projeto

- [x] **Preferências gráficas v1** — customização segura;
  Noctalia/DMS/Silere.
  - Dependências: schema/migração, componentes de formulário.
  - Risco: virar settings infinito.
  - Critério de conclusão: cobre barra, dock, motion, accent, wallpaper e
    opcionais; nunca edita QML gerado.
  - Implementado em `hypr/scripts/settings-store.sh` (schema versionado v1,
    merge de defaults, migração hook, escrita atômica com flock) +
    `Services/Settings.qml` (espelho reativo via `FileView`, escrita sempre
    via script) + `Panel/Preferences.qml` (UI: modo de workspaces da barra,
    autohide do dock, provider de accent, Calm Mode, providers do launcher).
    Nenhum componente edita `settings.json` nem QML gerado diretamente.
- [x] **Eventos no calendário** — próximos compromissos no glance;
  Noctalia/DMS.
  - Dependências: adapter EDS/ICS opcional, lazy load.
  - Risco: timezone/recorrência.
  - Critério de conclusão: próximos eventos, timezone e abertura de app;
    fallback mensal idêntico sem provider.
  - Implementado em `hypr/scripts/calendar-events.sh` — um adapter ICS (não
    EDS via D-Bus: a API assíncrona real do Evolution Data Server exigiria
    abrir uma `CalendarView` e escutar sinais, o que não cabe com segurança
    num script bash sem uma sessão EDS real para validar contra; ICS é a
    alternativa que o próprio roadmap lista e que dá para testar com
    fixtures) — lê arquivos `.ics` de diretórios conhecidos (Evolution,
    khal, ou um diretório configurável), extrai `VEVENT`s futuros e ordena
    pelos próximos. Sem recorrência (`RRULE`) nesta passada — ver
    limitações. Carregado só quando o calendário abre, em
    `Panel/Calendar.qml` ("Próximos eventos" acima da grade mensal, que
    permanece idêntica quando nenhum `.ics` é encontrado).
- [x] **Overrides por monitor** — setup coerente em desktop+laptop;
  Caelestia/Noctalia.
  - Dependências: SurfaceContext e schema.
  - Risco: combinações difíceis de testar.
  - Critério de conclusão: herança global previsível; posição/escala/popup/
    wallpaper testados em 1–3 monitores.
  - Implementado como `Settings.monitors[connectorName]` (schema já previa o
    campo) com herança rasa sobre os defaults globais, exposto em
    `Panel/Preferences.qml`: autohide do dock por monitor conectado, e um
    monitor preferido global para os popups de superfície única (launcher,
    quick settings, calendário, integrações), que hoje seguem o monitor com
    foco quando nenhuma preferência é salva. Escala e wallpaper por monitor
    já existiam antes deste trabalho (`Panel/Wallpapers.qml`); posição da
    barra/dock por monitor (topo vs. base) NÃO foi implementada nesta
    passada — ambos são hoje de âncora única e fixa em todo o código, e
    tornar isso configurável é uma mudança de layout maior, fora do escopo
    seguro desta rodada. Ver limitações no fim do documento.
- [x] **Matugen opcional** — compatibilidade com ecossistema; DMS/Silere.
  - Dependências: adapter de paleta e detecção.
  - Risco: drift dos tokens.
  - Critério de conclusão: saída Matugen mapeia tokens existentes; algoritmo
    atual segue default; ausência é neutra.
  - Implementado em `hypr/scripts/matugen-adapter.sh` (roda `matugen`,
    remapeia sua paleta para os mesmos tokens que `accent.sh` já escreve, e
    sai sem erro — apenas avisando — quando `matugen` não está instalado) e
    `accent { provider }` em `Settings`/`Panel/Preferences.qml`, default
    `"hyprveil"`.
- [x] **Clipboard com imagens** — reconhecimento mais rápido; DMS/ChillPill.
  - Dependências: thumbnails lazy, limites.
  - Risco: vazamento e memória.
  - Critério de conclusão: previews limitados, cache descartável, exclusão e
    modo privado/lock testados.
  - Implementado em `Panel/ClipboardSection.qml`: detecção de entradas de
    imagem do cliphist a partir da saída real de `cliphist list`, thumbnail
    64×64 decodificado sob demanda para
    `$XDG_CACHE_HOME/hyprveil/clipboard-thumbs/`, nunca para o histórico
    persistente, apagado por `clearAll()`. Modo privado/lock NÃO tem uma
    guarda explícita própria nesta passada: o painel de Quick Settings já é
    estruturalmente inatingível enquanto `Lock.qml` está ativo (foco de
    teclado exclusivo, camada acima), então não há um caminho real para
    gerar uma thumbnail durante o bloqueio — mas isso é uma garantia
    estrutural do resto do shell, não uma checagem que este código faz por
    si; ver limitações.
- [x] **Power/session nativo** — transição e foco consistentes.
  - Dependências: coordinator, comandos session.
  - Risco: ação destrutiva acidental.
  - Critério de conclusão: confirmação clara, teclado completo, estados
    disabled e wlogout como fallback.
  - Implementado em `Session/Session.qml`: modal com lock/suspend imediatos
    (reversíveis, sem necessidade de confirmação) e logout/restart/shutdown
    atrás de uma confirmação em duas etapas, navegação por teclado completa
    (setas, Enter, Escape recua um nível por vez em vez de sempre fechar),
    ligado a `$mod, Escape` e `CTRL ALT, Delete` (que antes chamavam o
    `wlogout` diretamente) via `qs ipc call session toggle`; `wlogout`
    permanece o fallback em `$mod SHIFT, Escape`. "Estados disabled" não foi
    implementado — nenhuma ação é desabilitada condicionalmente nesta
    passada; ver limitações.

#### Prioridade baixa — diferenciais e recursos avançados

- [x] **Extensões restritas** — providers opcionais sem fork; Noctalia/DMS.
  - Dependências: API versionada, sandbox de config.
  - Risco: suporte e segurança.
  - Critério de conclusão: apenas launcher/painel/providers declarativos;
    erro de extensão não derruba a shell.
  - Implementado como um registry JSON versionado
    (`hypr/scripts/data/launcher-providers.json`) lido por
    `Launcher/Providers.qml`: cada entrada é puramente declarativa (id,
    rótulo, glyph por codepoint, `kind`), nenhuma execução de código de
    terceiros — só um `kind` que este build conhece (`calculator`, `files`,
    `emoji`) é ativado, e uma entrada com `kind` desconhecido ou malformada é
    filtrada individualmente sem falhar o carregamento do registry nem do
    launcher. O carregamento QML geral continua coberto pelo gate leve; sem
    sandbox real de execução de código arbitrário —
    fora de escopo para um MVP declarativo; ver limitações.
- [x] **Cenas por monitor** — alterna trabalho/apresentação rapidamente.
  - Dependências: overrides, coordinator, wallpaper.
  - Risco: estados surpreendentes.
  - Critério de conclusão: preview, aplicar/reverter atômico e recuperação
    após monitor removido.
  - Implementado em `hypr/scripts/scenes.sh` (`save`/`list`/`apply`/
    `revert`/`remove`, snapshot de `dock`/`accent`/`modules` — nunca
    wallpaper, que continua exclusivamente de `wallpaper.sh` — aplicado
    atomicamente via `settings-store.sh set`, com um slot de reverter de um
    passo) e uma seção "Scenes" em `Panel/Preferences.qml`. "Por monitor" é
    uma simplificação do nome —
    ver a nota de escopo no cabeçalho de `scenes.sh`: isto é hoje um perfil
    de mesa inteira, não por conector; recuperação após remoção de monitor
    não se aplica a este MVP porque nada aqui referencia um monitor
    específico.
- [x] **Calm Mode contextual** — menos ruído em bateria/foco; Silere.
  - Dependências: políticas DND/motion/mídia.
  - Risco: esconder informação crítica.
  - Critério de conclusão: indicador explícito, exceções urgentes e toggle
    reversível; nenhuma perda de notificação.
  - Implementado em `Services/CalmMode.qml` (ativação manual OU automática
    sob bateria baixa via `Quickshell.Services.UPower`, ambas reversíveis) e
    ligado em `Notif/Popups.qml` (suprime popups não críticos, nunca o
    histórico), `Bar/Bar.qml` (mídia colapsada, tray sob demanda) e
    `Services/Motion.qml` (pausa de animação). Indicador e toggle manual
    vivem em `Panel/Preferences.qml`.
- [x] **Providers avançados do launcher** — arquivo, cálculo, emoji sob
  demanda; DMS/end-4. OCR não foi incluído neste provider (ver limitações).
  - Dependências: registry e lazy load.
  - Risco: escopo/dependências.
  - Critério de conclusão: cada provider instalável/desativável, com timeout
    e orçamento medido.
  - Implementado em `Launcher/Providers.qml`: arquivos via `find` (sem
    depender de `fd`), debounced e limitado a 8 resultados, com `timeout 2`
    no processo; calculadora via um parser aritmético próprio (sem `eval`,
    sem `qalc`); emoji via lista estática curta. Cada
    provider liga/desliga em `Settings.providers.launcher` a partir
    de `Panel/Preferences.qml`; calculadora ligada por padrão (nenhum
    processo obrigatório), arquivos e emoji desligados por padrão como o
    roadmap pede. "Orçamento medido" aqui é o `timeout 2` do provider de
    arquivos — não há uma métrica de latência coletada além disso.
- [x] **Status capsule transitória** — feedback compacto; ChillPill.
  - Dependências: OSD/coordinator.
  - Risco: morphing distrativo.
  - Critério de conclusão: só eventos temporários, motion reduzido
    respeitado e barra estável em idle.
  - Implementado em `Osd/StatusCapsule.qml`, reaproveitando o padrão já
    existente do `Osd/Osd.qml` (aparece, expõe o evento, some sozinho) para
    eventos que hoje não têm OSD: DND ligado/desligado e Calm Mode
    ligado/desligado — nenhuma barra "morphing" permanente, e a duração da
    animação de entrada/saída respeita `Motion.duration()`.

## Conclusão

O melhor caminho não é alcançar paridade item a item com DMS ou end-4. É fechar
os cinco fluxos diários incompletos e usar uma arquitetura de capacidades,
settings tipados, contexto por monitor e carregamento sob demanda. Isso captura o
que os projetos maduros fazem melhor e, ao mesmo tempo, evita seus principais
custos: dependências extensas, densidade visual, regressões por superfície e
configuração difícil de sustentar.

Com esse filtro, o Hyprveil pode competir não pela maior quantidade de widgets,
mas por ser a shell Quickshell mais calma, previsível e recuperável para Fedora.
