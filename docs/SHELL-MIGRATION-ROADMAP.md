# Roadmap de migração do Hyprveil Shell

Sim. O melhor caminho é uma migração incremental: manter o visual e as funcionalidades atuais, mas reorganizar o Hyprveil como um shell coerente. O roadmap anterior já resolveu muitas lacunas funcionais; agora o foco precisa ser arquitetura e experiência.

## Arquitetura-alvo

O Caelestia separa claramente componentes, módulos, serviços e utilitários, além de oferecer CLI e configuração centralizada. Essa é a principal ideia que vale trazer do [Caelestia Shell](https://github.com/caelestia-dots/shell), sem copiar sua estética.

```text
config/quickshell/
├── App/
│   ├── Shell.qml
│   ├── SurfaceCoordinator.qml
│   └── SurfaceHost.qml
├── Design/
│   ├── Tokens.qml
│   ├── Motion.qml
│   └── Components/
├── Features/
│   ├── Bar/
│   ├── Dock/
│   ├── Launcher/
│   ├── QuickSettings/
│   ├── Notifications/
│   ├── Overview/
│   └── Session/
├── Services/
│   ├── Audio.qml
│   ├── Network.qml
│   ├── Bluetooth.qml
│   └── Settings.qml
└── Adapters/
    ├── Hyprland.qml
    ├── SystemActions.qml
    └── Wallpaper.qml
```

Lock, notificações passivas e OSD permanecem isolados por razões de segurança e comportamento.

## Fase 0 — Baseline e contrato visual

Prazo estimado: 2–3 dias.

- [x] Registrar screenshots e vídeos de todos os fluxos atuais.
- [x] Medir abertura do launcher, Quick Settings, memória e CPU.
- [x] Inventariar padrões duplicados: botões, listas, campos, cards, modais e animações.
- [x] Documentar quais comportamentos não podem mudar.
- [x] Definir a linguagem visual Hyprveil: densidade, elevação, tipografia, foco, estados e movimento.

Entrega: `docs/SHELL-ARCHITECTURE.md` e `docs/DESIGN-SYSTEM.md`.

O que preservar:

- [x] `Tokens.qml`, `Accent.qml` e `Surface.qml`;
- [x] configuração versionada de [Settings.qml](../config/quickshell/Services/Settings.qml);
- [x] suporte por monitor;
- [x] instalador e mecanismos de recuperação;
- [x] lock sem possibilidade de unlock via IPC.

## Fase 1 — Biblioteca de componentes

Prazo estimado: 1–2 semanas.

Criar componentes reutilizáveis:

- [x] `HvButton`, `HvIconButton` e `HvToggle`;
- [x] `HvListRow` e `HvActionRow`;
- [x] `HvTextField` e `HvSearchField`;
- [x] `HvSlider`;
- [x] `HvPanel`, `HvDialog` e `HvPopover`;
- [x] `HvSection`, `HvHeader` e `HvEmptyState`;
- [x] `HvFocusRing`, tooltip e menu contextual.

Depois migrar primeiro as superfícies mais simples:

1. [x] Session;
2. [x] Launcher;
3. [x] Integrations;
4. [x] Preferences.

Critérios de aceite:

- [x] controles iguais possuem o mesmo foco, hover, tamanho e animação;
- [x] navegação por teclado é idêntica;
- [x] módulos de feature não recriam botões usando `Rectangle + Text + MouseArea`;
- [x] acessibilidade está embutida nos componentes, não repetida por tela.

## Fase 2 — Coordenador de superfícies

Prazo estimado: 1 semana.

Hoje as superfícies são conectadas manualmente em [shell.qml](../config/quickshell/shell.qml). Criar um `SurfaceCoordinator` central com algo equivalente a:

```qml
SurfaceCoordinator.open("launcher", screen, originItem)
SurfaceCoordinator.open("quickSettings", screen, originItem)
SurfaceCoordinator.close()
SurfaceCoordinator.back()
```

Ele deverá controlar:

- [x] qual superfície está aberta;
- [x] monitor de destino;
- [x] exclusão entre modais;
- [x] restauração de foco;
- [x] `Escape`, Enter, setas e busca;
- [x] origem visual da abertura;
- [x] histórico interno de navegação.

Separar os hosts por natureza:

- [x] `AnchoredHost`: calendário, mídia, tray e controles da barra;
- [x] `ModalHost`: launcher, sessão, preferências e wallpapers;
- [x] `FullscreenHost`: overview e cheatsheet;
- [x] `PassiveHost`: OSD e notificações.

Critério principal: [x] nunca existir launcher, sessão e Quick Settings disputando foco simultaneamente.

## Fase 3 — Continuidade visual

Prazo estimado: 1–2 semanas.

- [x] Fazer popovers nascerem visualmente do botão que os abriu.
- [x] Compartilhar transições de entrada, saída e troca de página.
- [x] Usar um único sistema de cabeçalho e navegação.
- [x] Manter posição e dimensão estáveis ao trocar conteúdo.
- [x] Aplicar detalhe progressivo: resumo → seção → configuração avançada.
- [x] Unificar estados vazios, carregamento, erro e indisponibilidade.
- [x] Ajustar bar e dock para parecerem partes do shell, não widgets soltos.

Não é necessário copiar o morphing constante do Caelestia. O Hyprveil pode continuar mais calmo, usando transformações apenas quando ajudam a explicar origem e destino.

## Fase 4 — Serviços e ações centralizadas

Prazo estimado: 1–2 semanas.

- [x] Todo serviço deve expor o mesmo contrato:

```text
available
state
busy
error
lastUpdated
refresh()
ações idempotentes
```

- [x] Criar adapters para ações externas. Features não deveriam executar diretamente `systemctl`, scripts ou comandos Hyprland.

Exemplo:

```qml
SystemActions.suspend()
SystemActions.powerOff()
WallpaperService.apply(path, monitor)
ShellActions.toggleDnd()
```

- [x] O armazenamento Bash atual pode continuar fazendo validação, locking e escrita atômica. A mudança é impedir que cada tela conheça scripts e caminhos diferentes.

- [x] Também ampliar a CLI:

```bash
hyprveil shell toggle launcher
hyprveil shell toggle quick-settings
hyprveil shell get settings
hyprveil shell set dock.autohide true
hyprveil shell doctor
hyprveil wallpaper set arquivo.jpg
```

Internamente ela pode usar o IPC do Quickshell, mas isso deixa de ser exposto ao usuário.

## Fase 5 — Configuração única

Prazo estimado: 3–5 dias.

Evoluir `settings.json` para schema v2:

- [x] aparência;
- [x] módulos habilitados;
- [x] bar e dock;
- [x] comportamento de superfícies;
- [x] animação e acessibilidade;
- [x] providers;
- [x] preferências por monitor.

- [x] Wallpapers, pins e notificações podem continuar em stores separados, mas todos devem ser descobertos por uma camada única de estado.

Critérios:

- [x] defaults documentados;
- [x] validação antes de gravar;
- [x] migração v1 → v2;
- [x] recuperação de arquivo corrompido;
- [x] nenhum componente lendo JSON diretamente.

## Fase 6 — Isolar os fallbacks

Prazo estimado: 3–5 dias.

Separar dois perfis:

```text
default:
  Quickshell completo

recovery:
  Waybar + Rofi + wlogout + SwayNC/Mako
```

- [x] O perfil padrão não inicializa nem apresenta ferramentas legadas.
- [x] Rofi e wlogout continuam disponíveis por atalhos de emergência.
- [x] Waybar, SwayNC e Mako deixam de aparecer como partes equivalentes do produto.
- [x] O doctor informa claramente quando o shell está operando em modo degradado.

Isso preserva a confiabilidade do Hyprveil sem deixar os fallbacks influenciarem sua identidade.

## Fase 7 — Polimento e lançamento

Prazo estimado: 1 semana.

- [x] Atualizar screenshots — o README ainda mostra o launcher antigo em [README.md](../README.md).
- [x] Produzir uma demonstração curta dos fluxos conectados.
- [x] Testar 1280, 1600, 1920 e ultrawide.
- [x] Testar um, dois e três monitores.
- [x] Validar teclado, motion reduzido e escalas fracionárias.
- [x] Comparar desempenho com o baseline.
- [x] Remover componentes antigos somente depois da migração completa.
- [x] Publicar como primeira versão reconhecível do “Hyprveil Shell”.

## Ordem sugerida de PRs

1. [x] Documentação da arquitetura e baseline.
2. [x] Biblioteca de componentes + migração do Session.
3. [x] Migração do Launcher e Preferences.
4. [x] `SurfaceCoordinator` e hosts.
5. [x] Quick Settings, calendário e wallpapers.
6. [x] Serviços, adapters e CLI.
7. [x] Bar, dock e continuidade visual.
8. [x] Perfis default/recovery.
9. [x] Testes, screenshots e limpeza final.

Estimativa realista: cerca de 6–9 semanas para uma pessoa trabalhando continuamente. O primeiro resultado visualmente convincente deve aparecer após as fases 1–3, sem precisar esperar a migração inteira.
