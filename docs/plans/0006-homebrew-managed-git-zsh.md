# Incremento 0006 — Gerenciar Git e Zsh com Homebrew

## Objetivo

Concluir o lifecycle funcional de Git e migrar Zsh de `apt-get` para Homebrew.
Ao final, o bootstrap executará `all` para os dois módulos, mantendo a ordem
Git → Zsh e o ownership por tecnologia definido no ADR-0003.

Uma tecnologia será considerada instalada somente quando sua fórmula estiver
gerenciada pelo Homebrew. A simples presença de uma versão fornecida pelo
sistema operacional não satisfará `install` ou `validate`.

## Decisões

- Reutilizar `core/homebrew.sh`; não criar um package manager genérico.
- Adicionar operações internas para instalar e validar uma fórmula Homebrew.
- Exigir `DEV_WORKSTATION_PACKAGE_PROVIDER=brew` nas instalações dos módulos.
- Manter configuração de links transacional por módulo.
- Não remover pacotes previamente instalados por `apt-get` e não tentar
  rollback de fórmulas Homebrew.
- Não alterar os perfis nem introduzir module loader neste incremento.
- Não criar novo ADR: ADR-0003 mantém o ownership nos módulos e ADR-0004 já
  define Homebrew como package provider.

## Execução incremental

| Etapa | Trabalho | Esforço | Dependência | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Registrar plano e atualizar roadmap | P | Incremento 0005 | Nenhum | Escopo e estado atual documentados |
| 2 | Estender operações Homebrew | M | Etapa 1 | Fixtures podem avançar em paralelo | Fórmulas podem ser instaladas e validadas de forma compartilhada |
| 3 | Migrar Zsh e implementar Git | M | Etapa 2 | Testes de cada módulo em paralelo | Ambos os módulos possuem lifecycle funcional |
| 4 | Integrar bootstrap | P | Etapa 3 | Documentação pode avançar em paralelo | Bootstrap executa Git `all` antes de Zsh `all` |
| 5 | Validar e registrar resultados | M | Etapa 4 | Testes manuais e automatizados em paralelo | Incremento revisável e reproduzível |

## Arquivos e responsabilidades

| Arquivo | Alteração |
| --- | --- |
| `core/homebrew.sh` | Adicionar `install <formula>` e `validate <formula> <executable>`, preservando `ensure` |
| `modules/git/install.sh` | Instalar a fórmula `git` pelo provider configurado e confirmar o executável |
| `modules/git/validate.sh` | Validar fórmula, `git --version` e os dois links sem mutações |
| `modules/zsh/install.sh` | Remover `sudo`/`apt-get` e instalar a fórmula `zsh` via Homebrew |
| `modules/zsh/validate.sh` | Validar fórmula, executável, link e sintaxe do `.zshrc` |
| `bootstrap.sh` | Passar o provider e executar `all` para Git, depois `all` para Zsh |
| `tests/fixtures/` | Simular `brew list`, `brew install`, Git e Zsh sem tocar no host |
| `tests/homebrew-test.sh` | Cobrir instalação, validação, idempotência e falhas de fórmula |
| `tests/modules-test.sh` | Substituir cenários adiados por lifecycle funcional de Git e Zsh |
| `tests/bootstrap-test.sh` | Verificar ordem, interrupção na primeira falha e isolamento entre módulos |
| `README.md` e `docs/Architecture.md` | Registrar o resultado e preparar o loader como próximo incremento |

## Comportamento esperado

`core/homebrew.sh install <formula>` deverá:

1. localizar e validar o Homebrew;
2. retornar sem mutação quando `brew list --formula <formula>` confirmar a
   instalação;
3. executar `brew install <formula>` quando ausente;
4. confirmar que a fórmula passou a constar no Homebrew;
5. retornar erro claro em qualquer falha.

`core/homebrew.sh validate <formula> <executable>` será somente leitura e
falhará quando a fórmula não estiver instalada, o executável não existir no
prefixo do Homebrew ou não estiver disponível no `PATH` preparado pelo
bootstrap.

Os módulos continuarão disponíveis diretamente, com o provider explícito:

```bash
DEV_WORKSTATION_PACKAGE_PROVIDER=brew bash modules/git/module.sh all
DEV_WORKSTATION_PACKAGE_PROVIDER=brew bash modules/zsh/module.sh all
```

## Testes e aceitação

- Git e Zsh já gerenciados pelo Brew não executam nova instalação.
- Uma versão fornecida apenas pelo sistema não impede `brew install`.
- Provider ausente ou diferente de `brew` falha antes da configuração.
- Homebrew ausente, fórmula ausente após instalação ou executável incorreto
  produz diagnóstico e retorno não zero.
- Git valida fórmula, versão, `.gitconfig` e `.gitignore_global`.
- Zsh valida fórmula, versão, `.zshrc` e sua sintaxe.
- `all` de Git e Zsh conclui com `HOME` temporário.
- Bootstrap executa todas as fases de Git antes das fases de Zsh.
- Falha em Git impede qualquer fase de Zsh.
- Falha em Zsh não desfaz Git previamente validado.
- Configuração de links continua idempotente e transacional.
- Nenhum caminho ativo do módulo Zsh executa `apt-get`, `sudo` ou `chsh`.
- Nenhum teste instala fórmulas ou pacotes reais.

Executar:

```bash
bash tests/run.sh
find . -type f -name '*.sh' -print0 | xargs -0 bash -n
git diff --check
rg 'apt-get|sudo|chsh' modules/zsh bootstrap.sh
```

## Validação manual

Em uma máquina descartável com Homebrew preparado:

```bash
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
  bash modules/git/module.sh all
HOME="$TEST_HOME" DEV_WORKSTATION_PACKAGE_PROVIDER=brew \
  bash modules/zsh/module.sh all
HOME="$TEST_HOME" bash modules/git/module.sh validate
HOME="$TEST_HOME" bash modules/zsh/module.sh validate
rm -rf "$TEST_HOME"
```

Resultado esperado: fórmulas Git e Zsh instaladas, três links válidos e
configurações funcionais. A remoção das fórmulas não faz parte da limpeza.

## Próximos passos

1. Estender perfis com entradas ordenadas `module=<name>`.
2. Criar o module loader e remover a lista fixa de módulos do bootstrap.
3. Validar diferenças entre utilitários GNU/BSD e adicionar CI Ubuntu/macOS.
4. Avaliar versões de fórmulas, Brewfile e instalador Homebrew fixado.
5. Adicionar novos módulos somente após o loader estar estável.

## Premissas

- Homebrew e seu `shellenv` já foram preparados pelo incremento 0005.
- Git e Zsh usarão fórmulas sem versão fixada.
- O bootstrap continuará sendo o caminho principal de execução completa.
- Instalação de fórmulas é global e não participa do rollback de dotfiles.
- O incremento permanece abaixo de aproximadamente 1000 linhas de alteração.
