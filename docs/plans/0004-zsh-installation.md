# Incremento 0004 — Instalação e validação funcional do Zsh

## Objetivo

Tornar o módulo Zsh funcional no ciclo `install → configure → validate`, sem
alterar o shell padrão do usuário. O bootstrap passará a executar `all` para
Zsh; a instalação do Git continua adiada.

## Execução incremental

| Etapa | Trabalho | Esforço | Dependência | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Implementar instalação idempotente via `apt-get` | M | Planos 0002 e 0003 | Nenhum | Zsh é instalado somente quando ausente |
| 2 | Validar executável, link e sintaxe do `.zshrc` | P | Etapa 1 | Testes podem avançar em paralelo | Validação funcional sem mutações |
| 3 | Integrar `all` ao bootstrap | P | Etapas 1 e 2 | Documentação pode avançar em paralelo | Bootstrap instala, configura e valida Zsh |
| 4 | Atualizar testes e documentação | M | Etapa 3 | Testes manuais e automatizados em paralelo | Incremento reproduzível e documentado |

Cada etapa deve formar uma alteração coerente e revisável. O incremento não
introduz um gerenciador genérico de pacotes nem um novo ADR.

## Arquivos

- `modules/zsh/install.sh`: instala `zsh` com `sudo apt-get install -y zsh`
  quando o executável não está disponível; não executa `chsh`.
- `modules/zsh/validate.sh`: verifica o executável, o link de `.zshrc` e sua
  sintaxe com `zsh -n`.
- `bootstrap.sh`: mantém Git em `configure`/`validate` e executa Zsh com `all`.
- `tests/modules-test.sh`: cobre instalação idempotente, instalação controlada,
  pré-requisitos e validação de sintaxe.
- `tests/fixtures/bin/`: comandos controlados para testar instalação sem tocar
  no sistema real.
- `scripts/install/zsh.sh`: permanece como legado e informa o novo entrypoint;
  não altera o shell padrão.
- `README.md` e `docs/Architecture.md`: registram o novo comportamento.

## Contratos e limites

- A instalação pressupõe um sistema Debian/Ubuntu com `sudo` e `apt-get`.
- Se Zsh já estiver no `PATH`, `install` termina sem efeitos adicionais.
- A instalação de pacotes é uma alteração global e não participa do rollback
  transacional dos links.
- Nenhum `chsh` é executado automaticamente.
- A instalação e validação funcional do Git permanecem fora deste incremento.

## Validação

```bash
bash tests/run.sh
find . -type f -name '*.sh' -print0 | xargs -0 bash -n
git diff --check
```

Validação manual com `HOME` temporário:

```bash
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" bash modules/zsh/module.sh all
HOME="$TEST_HOME" bash modules/zsh/module.sh validate
readlink "$TEST_HOME/.zshrc"
rm -rf "$TEST_HOME"
```

Resultado esperado: Zsh disponível, `.zshrc` apontando para o asset do
repositório e sintaxe validada. O bootstrap pode solicitar a senha do `sudo`
quando Zsh ainda não estiver instalado.

## Resultado

Implementado e validado. A suíte cobre os caminhos idempotente, instalação
controlada, pré-requisitos, validação de sintaxe e integração do bootstrap.
Também foram executados `bash -n` em todos os scripts e `git diff --check`, sem
erros. O fluxo não executa `chsh`.
