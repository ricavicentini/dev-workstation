# Incremento 0007 — Carregamento ordenado de módulos por perfil

## Resumo

Substituir a lista fixa Git → Zsh do bootstrap por módulos declarados nos
perfis como entradas ordenadas `module=<name>`. O loader será simples,
executará somente `all`, validará todos os entrypoints antes da primeira
execução e interromperá no primeiro erro.

Estimativa: 300–500 linhas alteradas, abaixo do limite de aproximadamente
1000 linhas. Não requer novo ADR: ADR-0004 já prevê módulos ordenados nos
perfis.

## Execução incremental

| Etapa | Trabalho | Esforço | Dependência | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Criar `docs/plans/0007-profile-module-loader.md` | P | Incremento 0006 | Nenhum | Decisões, arquivos, aceitação e sequência registrados antes da implementação |
| 2 | Estender perfis e parser | M | Etapa 1 | Testes do parser podem acompanhar | Perfis declaram Git e Zsh em ordem e expõem essa lista sem executar dados |
| 3 | Implementar loader | M | Etapa 2 | Fixtures/testes do loader podem avançar em paralelo | Módulos são pré-validados e executados sequencialmente com `all` |
| 4 | Integrar bootstrap | P | Etapa 3 | Documentação pode avançar em paralelo | Bootstrap deixa de conhecer Git e Zsh diretamente |
| 5 | Validar e atualizar documentação | M | Etapa 4 | Testes e revisão documental em paralelo | Incremento reproduzível, revisável e registrado como concluído |

## Mudanças de interface e comportamento

- `profiles/ubuntu.conf` e `profiles/macos.conf` receberão, nesta ordem:
  `module=git` e `module=zsh`.
- `core/profile.sh` passará a aceitar `profile.sh modules <profile-file>`,
  imprimindo um nome por linha na ordem declarada.
- A validação exigirá ao menos um módulo, aceitará várias chaves `module`,
  rejeitará nomes repetidos ou fora de `[a-z0-9-]` e continuará rejeitando
  duplicação das demais chaves.
- Criar `core/module-loader.sh` com interface
  `module-loader.sh <modules-dir> <module>...`. Ele:
  - aceita somente nomes seguros;
  - confirma previamente que todos os diretórios e `module.sh` são legíveis;
  - executa `bash <modules-dir>/<name>/module.sh all` na ordem recebida;
  - herda `DEV_WORKSTATION_PACKAGE_PROVIDER`;
  - preserva o status da primeira falha e não inicia módulos posteriores.
- `bootstrap.sh` consultará os módulos somente após preparar/reiniciar o Bash
  necessário, evitando dependência prematura de recursos ausentes no Bash 3 do
  macOS. A lista fixa de Git e Zsh será removida.
- Não haverá descoberta automática pelo conteúdo de `modules/`, sourcing de
  perfis, alteração do lifecycle público, rollback entre módulos ou mudanças
  internas em Git/Zsh.

## Arquivos

| Arquivo | Alteração |
| --- | --- |
| `docs/plans/0007-profile-module-loader.md` | Registrar este plano, esforço, dependências, arquivos e resultado |
| `profiles/ubuntu.conf`, `profiles/macos.conf` | Declarar módulos na ordem Git → Zsh |
| `core/profile.sh` | Validar módulos repetíveis e implementar a consulta ordenada |
| `core/module-loader.sh` | Novo loader com preflight e execução sequencial de `all` |
| `bootstrap.sh` | Consumir perfil e loader, removendo caminhos fixos de módulos |
| `tests/profile-test.sh` | Cobrir ordem, ausência, duplicidade e nomes inválidos |
| `tests/module-loader-test.sh` | Cobrir preflight, ordem, argumento `all`, propagação de status e interrupção |
| `tests/bootstrap-test.sh` e `tests/run.sh` | Integrar o loader à suíte e confirmar o fluxo completo |
| `README.md` e `docs/Architecture.md` | Documentar a arquitetura resultante e promover CI Ubuntu/macOS como próximo incremento |

## Testes e aceitação

- Os perfis reais retornam exatamente `git` e `zsh`, nessa ordem.
- Perfil sem módulos, com módulo duplicado, nome inválido ou chave desconhecida
  falha antes do provisionamento.
- Um entrypoint ausente em qualquer posição impede a execução de todos os
  módulos.
- O loader passa apenas `all`, mantém a ordem declarada e interrompe no
  primeiro erro preservando seu status.
- O bootstrap configura Git antes de Zsh sem conter referências diretas a seus
  entrypoints.
- Execuções repetidas permanecem idempotentes; falha posterior não desfaz
  módulo já validado.
- Nenhum teste instala pacotes reais ou altera o ambiente do host.

Executar:

```bash
bash tests/run.sh
find . -type f -name '*.sh' -print0 | xargs -0 bash -n
git diff --check
rg 'modules/(git|zsh)/module\.sh' bootstrap.sh
```

## Resultado

Implementado. Os perfis agora declaram módulos ordenados, o bootstrap consulta
essa lista depois de preparar o runtime de Bash exigido pelo perfil e o novo
loader executa `all` com preflight de todos os entrypoints antes da primeira
mutação.

## Próximos passos

1. Validar diferenças entre utilitários GNU/BSD e adicionar CI Ubuntu/macOS.
2. Avaliar versões de fórmulas, Brewfile e um instalador Homebrew fixado.
3. Adicionar novos módulos somente após o loader estar estável.

## Premissas

- Ambos os perfis continuam selecionando Git e Zsh na mesma ordem.
- O loader executará somente `all`; seleção de fases não será adicionada.
- ADR-0004 é suficiente e não será modificado.
- A alteração local existente em `bootstrap.sh` é apenas de permissão; sua
  marcação como executável será preservada.
- Compatibilidade GNU/BSD e CI Ubuntu/macOS permanecem como o incremento
  seguinte.
