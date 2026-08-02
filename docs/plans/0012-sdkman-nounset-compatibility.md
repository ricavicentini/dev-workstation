# Incremento 0012 - Compatibilidade do SDKMAN com `set -u`

## Resumo

Corrigir o helper de inicializacao do modulo `java` para carregar o script
oficial do SDKMAN mesmo quando o lifecycle do repositorio executa com
`set -u`. O problema atual interrompe `install` e `validate` antes da
instalacao das versoes declaradas, deixando o ambiente com SDKMAN presente,
mas sem Java configurado.

O incremento permanece pequeno e revisavel. Nao altera o contrato publico dos
modulos, nao muda ownership de dotfiles e nao exige ADR: a correcao apenas
preserva a integracao ja planejada no incremento 0011.

## Execucao incremental

| Etapa | Trabalho | Esforco | Dependencia | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Registrar este plano corretivo | P | Incremento 0011 | Nenhum | Causa, estrategia e recuperacao ficam documentadas antes da mudanca |
| 2 | Ajustar `modules/java/common.sh` | P | Etapa 1 | Testes podem avancar em paralelo | `source_sdkman` passa a isolar o `source` do SDKMAN do `nounset` do repositorio |
| 3 | Tornar a fixture do SDKMAN fiel ao bug real | P | Etapa 1 | Em paralelo com Etapa 2 | A suite deixa de aceitar um comportamento que o SDKMAN real nao suporta |
| 4 | Fortalecer os testes do modulo Java | P | Etapas 2-3 | Nenhum | Instalacao, default e validacao passam a cobrir a regressao |
| 5 | Reexecutar a suite e recuperar o ambiente local | M | Etapas 2-4 | Nenhum | O repositorio e o bootstrap confirmam a correcao ponta a ponta |

## Mudancas de comportamento

- `modules/java/common.sh` continua sendo o unico ponto que inicializa o
  SDKMAN para o modulo Java, mas agora:
  - detecta se `nounset` estava ativo;
  - desativa `set -u` apenas durante o `source` de `sdkman-init.sh`;
  - restaura o estado original antes de avaliar sucesso ou falha;
  - falha explicitamente se o `source` retornar erro ou se `sdk` continuar
    indisponivel.
- `tests/fixtures/sdkman-installer.sh` passa a reproduzir o detalhe relevante
  do script oficial: ler `SDKMAN_CANDIDATES_API` antes de defini-la.
- `tests/modules-test.sh` continua validando o lifecycle inteiro do modulo
  Java, mas agora garante que a fixture mais realista ainda instala Java
  `21.0.11-tem` e `17.0.19-tem`, define Java 21 como `current` e mantem
  `java -version` funcional.

## Testes e recuperacao

- `bash tests/run.sh`
- `find . -type f -name '*.sh' -exec bash -n {} +`
- `git diff --check`
- `bash bootstrap.sh ubuntu`
- Em uma nova sessao Zsh, ou apos `source ~/.zshrc`, confirmar:
  - `sdk current java`
  - `java -version`

Resultado esperado: `sdk current java` informa `21.0.11-tem`, `java -version`
executa normalmente e uma segunda execucao do bootstrap nao reinstala SDKMAN
nem repete `sdk install`.

## Assumptions

- Java `21.0.11-tem` permanece como default global.
- Java `17.0.19-tem` permanece instalado como versao adicional.
- O repositorio continua configurando apenas Zsh para carregar o SDKMAN.
