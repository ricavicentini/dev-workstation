# Incremento 0010 - Modulo GitHub CLI

## Resumo

Adicionar o GitHub CLI como um modulo de tecnologia independente, instalado e
validado pelo Homebrew atraves dos perfis existentes.

O incremento permanece pequeno e revisavel. Nao ha novo ADR: o trabalho aplica
a arquitetura ja aceita de modulos independentes, perfis explicitos e
instalacao via Homebrew. Autenticacao do `gh` fica fora de escopo porque e
estado local do usuario e pode exigir navegador, token ou escolha de conta.

## Execucao incremental

| Etapa | Trabalho | Esforco | Dependencia | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Criar `docs/plans/0010-github-cli-module.md` | P | Incremento 0009 | Nenhum | Sequencia, escopo e aceitacao ficam registrados antes da implementacao |
| 2 | Criar `modules/github-cli/` com lifecycle completo | P | Etapa 1 | Testes podem avancar em paralelo | O modulo instala, nao configura estado local e valida `gh` |
| 3 | Adicionar `github-cli` aos perfis Ubuntu e macOS | P | Etapa 2 | Nenhum | Bootstrap passa a executar GitHub CLI depois dos modulos atuais |
| 4 | Atualizar fixture e testes isolados | M | Etapas 2-3 | Documentacao pode avancar em paralelo | A suite comprova instalacao, validacao e ordem no bootstrap |
| 5 | Atualizar README e arquitetura | P | Etapas 2-4 | Nenhum | Modulo e comportamento ficam documentados |

## Mudancas de interface e comportamento

- Novo modulo: `modules/github-cli/module.sh`.
- O modulo instala a formula Homebrew `gh`.
- `configure` nao altera arquivos nem executa `gh auth login`.
- `validate` verifica a formula `gh`, o executavel `gh` no `PATH` e um comando
  funcional sem rede.
- Os perfis `ubuntu` e `macos` passam a executar `github-cli` depois de `git` e
  `zsh`.
- O bootstrap continua perfilado, sequencial e sem descoberta automatica de
  modulos.

## Arquivos

| Arquivo | Alteracao |
| --- | --- |
| `docs/plans/0010-github-cli-module.md` | Registrar plano, escopo, sequencia e aceitacao |
| `modules/github-cli/module.sh` | Expor o lifecycle publico do modulo |
| `modules/github-cli/install.sh` | Instalar a formula `gh` via Homebrew |
| `modules/github-cli/configure.sh` | Registrar fase sem mutacao local |
| `modules/github-cli/validate.sh` | Validar formula, executavel e comando funcional |
| `profiles/ubuntu.conf` | Adicionar `module=github-cli` |
| `profiles/macos.conf` | Adicionar `module=github-cli` |
| `tests/fixtures/homebrew-installer.sh` | Simular executavel `gh` especifico |
| `tests/modules-test.sh` | Cobrir propriedade, instalacao e bootstrap com GitHub CLI |
| `tests/bootstrap-test.sh` | Atualizar expectativa do bootstrap macOS |
| `README.md` | Registrar modulo concluido e remover capacidade planejada |
| `docs/Architecture.md` | Documentar GitHub CLI entre os modulos suportados |

## Testes e aceitacao

- `bash tests/run.sh`
- `find . -type f -name '*.sh' -exec bash -n {} +`
- `git diff --check`
- GitHub CLI instala `gh` por Homebrew quando ausente.
- GitHub CLI falha antes de mutar quando o provider nao e `brew`.
- `configure` nao cria dotfiles nem estado de autenticacao.
- `validate` nao exige usuario autenticado.
- Bootstrap instala os modulos na ordem Git -> Zsh -> GitHub CLI.
- Falha em Git ou Zsh continua impedindo modulos seguintes.
- macOS continua preparando Bash do Homebrew antes de executar modulos.

