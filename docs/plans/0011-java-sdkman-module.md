# Incremento 0011 - Java via SDKMAN com multiplas versoes

## Resumo

Adicionar um modulo `java` que instala SDKMAN como detalhe interno e gerencia
Java 21 e Java 17, deixando Java 21 como padrao global. A escolha segue o
contrato atual de modulos por tecnologia e evita criar um modulo `sdkman`
compartilhado antes de existir uma segunda tecnologia que precise dele.

O incremento permanece pequeno e revisavel. Nao ha novo ADR: o trabalho aplica
o lifecycle aceito em ADR-0002, a organizacao por tecnologia de ADR-0003 e os
perfis explicitos de ADR-0004.

## Execucao incremental

| Etapa | Trabalho | Esforco | Dependencia | Paralelismo | Resultado |
| --- | --- | --- | --- | --- | --- |
| 1 | Criar `docs/plans/0011-java-sdkman-module.md` | P | Incremento 0010 | Nenhum | Decisoes, escopo e aceitacao ficam registrados antes da implementacao |
| 2 | Criar `modules/java/` e `versions.conf` | M | Etapa 1 | Testes podem avancar em paralelo | O modulo instala SDKMAN, instala Java 21 e 17, define o default e valida o estado |
| 3 | Adicionar `java` aos perfis Ubuntu e macOS | P | Etapa 2 | Nenhum | Bootstrap passa a executar Java depois de GitHub CLI |
| 4 | Atualizar fixtures e testes isolados | M | Etapas 2-3 | Documentacao pode avancar em paralelo | A suite cobre SDKMAN, multiplas versoes, default e ordem no bootstrap |
| 5 | Atualizar README e arquitetura | P | Etapas 2-4 | Nenhum | O novo modulo e o comportamento de shell ficam documentados |

## Mudancas de interface e comportamento

- Novo modulo: `modules/java/module.sh`.
- Novo arquivo versionado: `modules/java/versions.conf`.
- O modulo usa o instalador oficial do SDKMAN com `rcupdate=false`, para evitar
  mutacao de dotfiles fora do ownership existente.
- `install` instala SDKMAN quando ausente, instala Java `21.0.11-tem` e
  `17.0.19-tem`, e define `21.0.11-tem` como default global.
- `configure` nao cria dotfiles nem altera estado local fora do diretorio do
  SDKMAN; o carregamento em shells futuros e feito pelo `.zshrc` versionado.
- `validate` confirma SDKMAN carregavel, comando `sdk` funcional, versoes
  declaradas presentes, `java -version` funcional e default alinhado ao
  configurado.
- Os perfis `ubuntu` e `macos` passam a executar `java` depois de
  `github-cli`.

## Arquivos

| Arquivo | Alteracao |
| --- | --- |
| `docs/plans/0011-java-sdkman-module.md` | Registrar plano, sequencia, arquivos e aceitacao |
| `modules/java/module.sh` | Expor o lifecycle publico do modulo |
| `modules/java/common.sh` | Centralizar leitura de versoes e inicializacao do SDKMAN |
| `modules/java/install.sh` | Instalar SDKMAN, instalar as versoes Java declaradas e definir o default |
| `modules/java/configure.sh` | Registrar fase sem mutacao adicional |
| `modules/java/validate.sh` | Validar SDKMAN, as versoes instaladas, o default e o executavel Java |
| `modules/java/versions.conf` | Declarar o default e as versoes Java gerenciadas |
| `dotfiles/zsh/.zshrc` | Carregar `sdkman-init.sh` quando presente |
| `profiles/ubuntu.conf` | Adicionar `module=java` |
| `profiles/macos.conf` | Adicionar `module=java` |
| `tests/fixtures/bin/curl` | Suportar o fluxo do instalador do SDKMAN sem rede |
| `tests/fixtures/sdkman-installer.sh` | Simular uma instalacao minima do SDKMAN |
| `tests/modules-test.sh` | Cobrir ownership, instalacao, idempotencia, default e bootstrap com Java |
| `tests/bootstrap-test.sh` | Atualizar a expectativa do bootstrap Ubuntu/macOS |
| `README.md` | Registrar Java como modulo suportado e fechar a capacidade planejada |
| `docs/Architecture.md` | Documentar Java no fluxo de modulos suportados |

## Testes e aceitacao

- `bash tests/run.sh`
- `find . -type f -name '*.sh' -exec bash -n {} +`
- `git diff --check`
- O modulo instala SDKMAN quando ausente e nao reinstala quando presente.
- O modulo instala Java `21.0.11-tem` e `17.0.19-tem` quando ausentes.
- Execucoes repetidas nao duplicam instalacoes nem alteram o default sem
  necessidade.
- `validate` falha se SDKMAN nao puder ser carregado, se alguma versao
  declarada estiver ausente ou se o default nao for Java 21.
- Bootstrap executa a ordem Git -> Zsh -> GitHub CLI -> Java.
- Falhas em modulos anteriores continuam impedindo Java.
- A fixture simula `sdk install`, `sdk default`, `sdk current java` e
  `sdk list java` sem instalar SDKMAN real.

## Assumptions

- Versoes iniciais: `21.0.11-tem` e `17.0.19-tem`, atuais em 2026-07-26.
- Default global: `21.0.11-tem`.
- Distribuicao: Eclipse Temurin.
- O incremento nao instala Kotlin, Gradle ou Maven.
- Se outra tecnologia passar a depender de SDKMAN, um incremento futuro deve
  reavaliar se SDKMAN merece modulo proprio ou helper compartilhado.
