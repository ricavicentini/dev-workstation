# Incremento 0005 — Fundação de perfis e Homebrew

## Objetivo

Preparar Homebrew por perfil explícito antes da configuração dos módulos. O
bootstrap continua com Git e Zsh em ordem fixa; o loader fica para depois que
ambos tiverem instalação funcional.

## Execução

| Etapa | Esforço | Dependência | Resultado |
| --- | --- | --- | --- |
| Perfil e ADR | P | 0004 | Contrato de configuração explícito |
| Provisionamento Homebrew | M | Perfil | Ubuntu e macOS preparados sem detecção automática |
| Integração bootstrap | M | Provisionamento | Pré-requisitos validados antes dos módulos |
| Testes e documentação | M | Integração | Fluxo controlado e documentado |

## Arquivos

- `profiles/*.conf`: estratégias declarativas de Ubuntu e macOS.
- `core/profile.sh`: valida e consulta os perfis sem executá-los.
- `core/homebrew.sh`: instala pré-requisitos, Homebrew e Bash quando necessário.
- `bootstrap.sh`: recebe o perfil, prepara o runtime e mantém a sequência atual.
- `dotfiles/zsh/.zshrc`: disponibiliza Homebrew em novos shells.
- `tests/`: cobre parser, provisionamento controlado e preflight.

## Validação

```bash
bash tests/run.sh
find . -type f -name '*.sh' -print0 | xargs -0 bash -n
git diff --check
```

## Próximos passos

1. Migrar Zsh para Brew e implementar instalação funcional do Git.
2. Extrair helper de pacotes apenas se os dois módulos duplicarem comportamento.
3. Adicionar módulos ordenados aos perfis e criar loader que execute somente `all`.
4. Validar compatibilidade entre utilitários GNU e BSD em macOS e adicionar CI.
5. Avaliar instalador fixado por checksum e modo não interativo separadamente.

## Resultado

Implementado e validado com a suíte Bash, verificação de sintaxe em todos os
scripts e `git diff --check`. Os testes usam fixtures para não instalar pacotes
nem baixar o instalador real.
