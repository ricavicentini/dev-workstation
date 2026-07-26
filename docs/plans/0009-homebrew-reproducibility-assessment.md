# Incremento 0009 - Avaliacao da reprodutibilidade do Homebrew

## Resumo

Concluir a avaliacao prevista no item 1 dos proximos passos do incremento
0008: versionamento de formulas, uso de `Brewfile` e instalador Homebrew
fixado.

Resultado: recomenda-se fixar apenas o script instalador do Homebrew em um
incremento futuro, por revisao imutavel e verificacao de checksum. O
versionamento de formulas e a introducao de `Brewfile` devem permanecer
adiados ate que exista uma necessidade concreta.

Esta avaliacao nao altera o comportamento do bootstrap. Como ADR-0004 aceita
explicitamente o instalador oficial corrente e registra a pinagem como trabalho
deferido, a mudanca de comportamento deve ser documentada por uma nova ADR
antes da implementacao.

## Contexto atual

| Area | Estado atual | Observacao |
| --- | --- | --- |
| Instalador Homebrew | `core/homebrew.sh` baixa `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` | A URL segue o instalador oficial corrente, mas o conteudo remoto e mutavel |
| Formula Git | `modules/git/install.sh` instala `git` | O modulo continua dono da instalacao e validacao de Git |
| Formula Zsh | `modules/zsh/install.sh` instala `zsh` | O modulo continua dono da instalacao e validacao de Zsh |
| Runtime Bash macOS | `bootstrap.sh` usa a formula `bash` quando o perfil pede Bash do Homebrew | O runtime e uma decisao de perfil, nao de modulo |
| Brewfile | Inexistente | A lista de pacotes vive nos modulos e no perfil explicito |

## Criterios de avaliacao

- Reprodutibilidade real obtida pelo mecanismo.
- Preservacao de atualizacoes e correcoes de seguranca.
- Simplicidade e custo de manutencao.
- Compatibilidade com a arquitetura atual de modulos independentes.
- Adequacao a execucao idempotente em Ubuntu, WSL e macOS.
- Necessidade de novo ADR antes de alterar decisoes aceitas.

## Avaliacao

### Versionamento de formulas

Homebrew e um gerenciador rolling release e nao oferece suporte geral para
misturar arbitrariamente versoes de formulas. Formulas versionadas existem
principalmente para linhas major/minor suportadas, como `foo@1.2`, nao para
fixar patches individuais. Mecanismos como `brew pin`,
`HOMEBREW_NO_AUTO_UPDATE`, `HOMEBREW_NO_INSTALL_UPGRADE` e
`brew bundle --no-upgrade` reduzem atualizacoes, mas nao produzem um lockfile
reprodutivel e podem atrasar correcoes de seguranca.

Pinagem exata exigiria extrair formulas para um tap proprio ou manter variantes
customizadas. Isso transferiria para este repositorio a responsabilidade por
atualizacoes, correcoes, deprecacoes e seguranca das formulas.

Decisao: manter formulas nao versionadas por enquanto. Se um modulo futuro
precisar de uma linha especifica, usar primeiro uma formula versionada ja
mantida pelo Homebrew, como `tool@major`, e validar a compatibilidade no modulo.
Pinagem exata so deve ser considerada diante de incompatibilidade comprovada e
com politica explicita de manutencao.

### Brewfile

`Brewfile` fornece uma interface declarativa para instalar, atualizar e
verificar dependencias Homebrew. Ele e util quando o projeto precisa expressar
um conjunto amplo de formulas, casks, taps, servicos ou extensoes em um unico
inventario.

Para o estado atual deste repositorio, um `Brewfile` centralizaria apenas Git,
Zsh e Bash, duplicando ou deslocando responsabilidades que hoje estao bem
delimitadas:

- Git e Zsh pertencem aos seus modulos, que instalam e validam suas ferramentas.
- Bash no macOS e uma preparacao de runtime escolhida pelo perfil.
- Perfis sao dados `key=value`; `Brewfile` e avaliado como Ruby e pode esconder
  logica por maquina se usado sem disciplina.
- `brew bundle` nao cria lockfile de versoes e, por padrao, pode atualizar
  dependencias desatualizadas.

Decisao: nao introduzir `Brewfile` agora. Reavaliar quando houver um inventario
Homebrew amplo o bastante para justificar uma fonte declarativa propria, ou
quando casks, taps, servicos e extensoes passarem a criar duplicacao real nos
modulos.

### Instalador Homebrew fixado

O maior ganho incremental esta em fixar o script instalador. Hoje o bootstrap
baixa e executa uma URL oficial mutavel. Usar uma revisao imutavel do
repositorio `Homebrew/install` com checksum versionado reduziria a superficie de
mudanca nao revisada no primeiro provisionamento.

Essa decisao nao fixa o proprio Homebrew, a API de formulas, taps ou as versoes
instaladas por `brew install`. Ela fixa apenas os bytes do script de instalacao
que este repositorio executa quando Homebrew ainda nao existe. Ainda assim, e
um ganho concreto de revisabilidade e falha rapida sem mudar a arquitetura dos
modulos.

Decisao: recomendar um proximo incremento para fixar o instalador por commit
imutavel e SHA-256, mantendo a instalacao interativa definida pela ADR-0004. A
instalacao nao interativa continua fora deste escopo.

## Plano recomendado quando retomado

| Etapa | Trabalho | Esforco | Dependencia | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Criar ADR para substituir apenas a decisao de instalador mutavel da ADR-0004 | P | Avaliacao 0009 | Nenhum | A mudanca arquitetural fica explicita e revisavel |
| 2 | Fixar URL do instalador por revisao imutavel e checksum em `core/homebrew.sh` | P | Etapa 1 | Testes podem avancar em paralelo | O bootstrap executa somente o instalador esperado |
| 3 | Adicionar verificacao SHA-256 portavel GNU/BSD antes de executar o script | M | Etapa 2 | Nenhum | Falha rapida em download incompleto, alterado ou inesperado |
| 4 | Cobrir sucesso, falha de checksum e limpeza do temporario nos testes | M | Etapas 2-3 | Documentacao pode avancar em paralelo | A fixture comprova o contrato sem instalar Homebrew real |
| 5 | Atualizar README e plano do incremento | P | Etapas 1-4 | Nenhum | Roadmap e comportamento documentados |

Arquivos esperados quando este trabalho for priorizado:

| Arquivo | Alteracao esperada |
| --- | --- |
| `docs/adr/0005-pinned-homebrew-installer.md` | Registrar a decisao de fixar o instalador e seus limites |
| `docs/adr/README.md` | Incluir a nova ADR no indice |
| `docs/plans/0010-pinned-homebrew-installer.md` | Planejar a implementacao incremental antes do codigo |
| `core/homebrew.sh` | Trocar a URL mutavel por revisao imutavel e validar SHA-256 antes da execucao |
| `tests/fixtures/` | Ajustar fixture de Homebrew para simular checksum valido e invalido |
| `tests/bootstrap-test.sh` ou testes equivalentes | Cobrir os fluxos de sucesso e falha do instalador fixado |
| `README.md` | Documentar o novo comportamento depois de implementado |

Aceitacao esperada:

- O bootstrap falha antes de executar o instalador quando o checksum nao bate.
- O arquivo temporario do instalador continua sendo removido em sucesso e falha.
- A verificacao funciona com utilitarios disponiveis em Ubuntu e macOS.
- O comportamento permanece idempotente quando Homebrew ja esta instalado.
- A instalacao continua interativa.
- A suite isolada, sintaxe Bash e `git diff --check` continuam verdes.

## Gatilhos de revisita

- Introduzir formula versionada quando uma ferramenta exigir major/minor
  especifico e a formula correspondente for mantida pelo Homebrew.
- Considerar tap proprio apenas quando uma incompatibilidade impedir o uso de
  formulas suportadas e o repositorio aceitar explicitamente o custo de
  manutencao.
- Introduzir `Brewfile` quando a lista Homebrew deixar de caber naturalmente
  nos modulos independentes, especialmente com casks, taps, servicos ou
  extensoes.
- Reavaliar instalacao nao interativa em um incremento separado, pois ela altera
  a experiencia de bootstrap inicial.

## Referencias

- Homebrew Bundle and Brewfile:
  <https://docs.brew.sh/Brew-Bundle-and-Brewfile>
- Formulae Versions:
  <https://docs.brew.sh/Versions>
- Installation:
  <https://docs.brew.sh/Installation>
- FAQ:
  <https://docs.brew.sh/FAQ>
