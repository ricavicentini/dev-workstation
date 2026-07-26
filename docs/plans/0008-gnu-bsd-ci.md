# Incremento 0008 — Compatibilidade GNU/BSD e CI Ubuntu/macOS

## Resumo

Comprovar a portabilidade do fluxo atual em runners nativos Ubuntu e macOS e
torná-la uma garantia contínua por GitHub Actions. O incremento permanece
pequeno e revisável, sem novo ADR e sem executar provisionamento real de
workstation.

Estimativa: 200–400 linhas alteradas, abaixo do limite de aproximadamente
1000 linhas. ADR-0004 continua suficiente: o trabalho valida a implementação
atual, não altera a arquitetura de perfis ou módulos.

## Execução incremental

| Etapa | Trabalho | Esforço | Dependência | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Criar `docs/plans/0008-gnu-bsd-ci.md` | P | Incremento 0007 | Nenhum | Sequência, escopo e aceitação ficam registrados antes da implementação |
| 2 | Ajustar compatibilidade GNU/BSD pontual | P | Etapa 1 | Testes podem avançar em paralelo | `core/symlink.sh` evita opções não documentadas no BSD sem expandir abstrações |
| 3 | Fortalecer cobertura macOS do bootstrap | M | Etapa 1 | Documentação e CI podem avançar em paralelo | A suíte comprova a reinicialização para Bash moderno quando o runtime do sistema é Bash 3 |
| 4 | Adicionar workflow Ubuntu/macOS | M | Etapas 2–3 | Documentação pode avançar em paralelo | Portabilidade vira verificação contínua em runners nativos |
| 5 | Atualizar documentação e validar localmente | P | Etapa 4 | Nenhum | Incremento concluído, documentado e pronto para revisão |

## Mudanças de interface e comportamento

- Não haverá novas interfaces públicas para `bootstrap.sh`, `core/profile.sh`,
  `core/module-loader.sh` ou módulos.
- `core/symlink.sh` removerá o terminador `--` apenas de `dirname` e
  `readlink`, cujas interfaces BSD não o documentam; comandos mutáveis que
  suportam o terminador o manterão.
- A fixture de Homebrew continuará simulando fórmulas e executáveis, mas o
  Bash instalado por ela passará a delegar para `HOMEBREW_TEST_REAL_BASH` e a
  registrar a execução quando solicitado pelo teste.
- O teste do perfil macOS iniciará o bootstrap com `/bin/bash`, usará o perfil
  real `macos` e verificará o reinício pelo Bash preparado via Homebrew antes
  dos módulos quando o shell do sistema for Bash 3.
- A CI executará somente a suíte isolada, checagem de sintaxe Bash,
  `git diff --check` e limpeza do worktree após os testes.
- Não serão adicionados ShellCheck, abstração genérica GNU/BSD, bootstrap real
  na CI, pinagem de Homebrew/fórmulas nem detecção automática de sistema.

## Arquivos

| Arquivo | Alteração |
| --- | --- |
| `docs/plans/0008-gnu-bsd-ci.md` | Registrar plano, esforço, sequência, aceitação e resultado |
| `core/symlink.sh` | Remover `--` apenas de `dirname` e `readlink` para compatibilidade BSD |
| `tests/fixtures/homebrew-installer.sh` | Fazer o Bash fake delegar ao Bash real indicado pelo teste e registrar a reinicialização |
| `tests/bootstrap-test.sh` | Cobrir o fluxo macOS iniciado por `/bin/bash` e verificar a delegação para o Bash moderno antes dos módulos |
| `.github/workflows/ci.yml` | Executar suíte, sintaxe e integridade do repositório em `ubuntu-latest` e `macos-latest` |
| `README.md` | Incluir `core/module-loader.sh`, registrar Ubuntu/macOS como plataformas verificadas e fechar o incremento 0008 |
| `docs/Architecture.md` | Documentar a garantia de portabilidade GNU/BSD validada pela CI |

## Testes e aceitação

- `bash tests/run.sh`
- `find . -type f -name '*.sh' -exec bash -n {} +`
- `git diff --check`
- `git status --short` vazio após a suíte
- A suíte passa com utilitários GNU nativos no Ubuntu e BSD nativos no macOS.
- O teste macOS comprova que `/bin/bash` 3 reinicia o bootstrap pelo Bash do
  Homebrew e só então executa os módulos.
- Preflight, ordem Git → Zsh, propagação de falhas, rollback e idempotência
  permanecem verdes.
- Nenhum teste instala fórmulas reais ou altera o `HOME` do runner.
- O workflow fica verde em `ubuntu-latest` e `macos-latest`.

## Resultado

Implementado. O projeto agora evita a dependência em opções não documentadas
por utilitários BSD, cobre explicitamente a reinicialização do bootstrap no
perfil macOS e valida continuamente o fluxo em runners Ubuntu e macOS do
GitHub Actions.

## Próximos passos

1. Avaliar versionamento de fórmulas, Brewfile e um instalador Homebrew fixado.
2. Revisitar a matriz de CI quando novos módulos exigirem dependências
   específicas por plataforma.
3. Considerar verificações adicionais somente quando houver benefício claro
   para revisão, como lint Bash orientado ao repositório.

## Premissas

- Runners `-latest` continuam sendo a referência suportada do projeto.
- O runner macOS fornece Homebrew, mas o shell do sistema permanece em Bash 3;
  por isso a workflow instala a fórmula `bash`.
- `actions/checkout@v6` é a linha principal corrente adotada pelo workflow.
- As duas lacunas observadas no incremento 0007 — árvore do README e cobertura
  do reinício macOS — entram neste incremento.
