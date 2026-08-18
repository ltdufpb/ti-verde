# Green Energy Lab — Medidor Multi-Linguagem de Energia e Performance

O **Green Energy Lab** é uma ferramenta de perfilamento e medição de consumo energético e emissões de carbono para aplicações de software em sistemas Linux nativos.

Ele integra medição direta de hardware via contadores Intel/AMD RAPL (**Scaphandre**), perfilamento de pilhas de chamadas em tempo de execução (**phpspy** para PHP, e extensível para Java e Python), geração de perfil visual (**FlameGraph**), testes de carga desacoplados (**k6**) e um analisador estatístico em Python (`analyze_measurement.py`) que correlaciona o consumo elétrico com o código executado.

---

## 📋 Sumário
1. [Requisito Fundamental](#-requisito-fundamental)
2. [Arquitetura e Fluxo Desacoplado](#-arquitetura-e-fluxo-desacoplado)
3. [Pronto para Fusão Multi-Linguagem (PHP, Java, Python)](#-pronto-para-fusão-multi-linguagem-php-java-python)
4. [Guia de Início Rápido (Quickstart)](#-guia-de-início-rápido-quickstart)
5. [Modos de Execução do Medidor (`run-meter.sh`)](#-modos-de-execução-do-medidor-run-metersh)
6. [Execução Separada do Teste de Carga (`run-load-test.sh`)](#-execução-separada-do-teste-de-carga-run-load-testsh)
7. [Painel Visual Interativo](#-painel-visual-interativo)
8. [Configuração (`config/experiment.env`)](#-configuração-configexperimentenv)
9. [Estrutura do Repositório](#-estrutura-do-repositório)
10. [Calculadora de Carbono (`carbon.py`)](#-calculadora-de-carbono-carbonpy)
11. [Boas Práticas de Medição](#-boas-práticas-de-medição)

---

## ⚠️ Requisito Fundamental

> [!IMPORTANT]
> **Use Linux nativo instalado no computador físico.**
> 
> **Não use WSL nem Máquinas Virtuais comuns** para realizar as medições reais de energia. O Scaphandre depende das interfaces RAPL (Running Average Power Limit) fornecidas pelo kernel Linux (`/sys/class/powercap`), que normalmente **não são expostas** por hipervisores ou pelo WSL.

Requisitos adicionais:
- Privilégios de **`sudo`** para acessar os contadores de hardware RAPL e ler memória de processos via `process_vm_readv`.
- Para PHP: PHP compilado **sem Thread Safety (Non-ZTS)** para compatibilidade com o profiler `phpspy`.

---

## 🏗 Arquitetura e Fluxo Desacoplado

O sistema adota uma separação estrita de responsabilidades: **Medição** e **Geração de Carga** são processos totalmente independentes. Isso permite executar o gerador de tráfego HTTP (`k6`) em um computador ou terminal separado, garantindo que o consumo de CPU do `k6` não interfira nas leituras de energia do servidor sob teste.

```mermaid
flowchart TD
    subgraph Configuração
        ENV[config/experiment.env]
    end

    subgraph Host de Medição
        METER[run-meter.sh\nEntrypoint do Medidor]
        SCAPH[Scaphandre\nLeitura de Watts RAPL]
        PROF[Profiler da Linguagem\nphpspy / async-profiler / py-spy]
        APP[Aplicação Alvo\nLocal / Container Docker / Processo PID]
        ANZ[analyze_measurement.py\nAtribuição Energética]
        FG[FlameGraph.pl\nGerador SVG]
    end

    subgraph Gerador de Carga Separado
        K6[run-load-test.sh\nk6 Workload Engine]
    end

    ENV --> METER & K6
    METER --> APP & SCAPH & PROF
    K6 -.->|Requisições HTTP| APP
    SCAPH -->|scaphandre.json\nMicrowatts / Tempo| ANZ
    PROF -->|phpspy.txt\nCall Stacks + Timestamps| ANZ
    K6 -.->|k6-summary.json (opcional)| ANZ
    ANZ --> FG
    FG --> OUT1[cpu-flamegraph.svg]
    FG --> OUT2[energy-flamegraph.svg]
    ANZ --> OUT3[SUMMARY.md & summary.json]
    ANZ --> OUT4[top-functions.csv & function-times.csv]
```

---

## 🌐 Pronto para Fusão Multi-Linguagem (PHP, Java, Python)

O medidor foi arquitetado para unificar três ecossistemas em uma interface padronizada:

```bash
./run-meter.sh --language <php|java|python> --mode <local|container|process>
```

- **PHP** *(Ativo)*: Utiliza amostragem via `phpspy` a 99 Hz + Scaphandre RAPL.
- **Java** *(Preparado para o merge)*: Integrará `async-profiler` / JVM RAPL.
- **Python** *(Preparado para o merge)*: Integrará `py-spy` / Austin.

---

## 🚀 Guia de Início Rápido (Quickstart)

### 1. Instalar Ferramentas Necessárias
Execute o script de instalação (requer Ubuntu/Debian Linux nativo):
```bash
./measurement/install-tools-ubuntu.sh
```

### 2. Verificar o Ambiente
Confirme que o hardware e o kernel atendem a todos os requisitos:
```bash
./measurement/check-environment.sh
```

### 3. Iniciar o Medidor (Terminal 1)
Inicie a medição informando a linguagem e o modo desejado:
```bash
./run-meter.sh -l php -m local
```
*O script coletará o consumo em repouso (baseline) e abrirá a janela de medição pelo tempo configurado.*

### 4. Executar o Teste de Carga (Terminal 2 ou Máquina Remota)
Durante a janela de medição aberta no Terminal 1, envie o tráfego de carga:
```bash
./run-load-test.sh
```

Ao término, os relatórios completos e Flamegraphs estarão disponíveis no diretório `results/php-local-YYYYMMDD-HHMMSS/`.

---

## 🎯 Modos de Execução do Medidor (`run-meter.sh`)

O medidor suporta três formas de execução:

### 1. Modo Local (`-m local`)
Inicia automaticamente o servidor embutido local da aplicação e anexa o profiler ao processo criado:
```bash
./run-meter.sh -l php -m local
```

### 2. Modo Container Docker (`-m container`)
Identifica o PID do container no Host Linux através de `docker inspect` e monitora o container diretamente pelo Host:
```bash
# Exemplo com WordPress ou qualquer container PHP
./run-meter.sh -l php -m container -c nome_do_container_php
```

### 3. Modo Processo Específico (`-m process`)
Conecta os coletores diretamente a um processo existente no Linux através do seu PID:
```bash
./run-meter.sh -l php -m process -p 12345
```

### Opções do `run-meter.sh`:
| Parâmetro | Descrição | Padrão |
|---|---|---|
| `-l, --language <lang>` | Linguagem da aplicação (`php`, `java`, `python`) | `php` |
| `-m, --mode <mode>` | Modo de execução (`local`, `container`, `process`) | `local` |
| `-c, --container <nome>` | Nome ou ID do container Docker (para modo container) | - |
| `-p, --pid <pid>` | PID do processo alvo (para modo process) | - |
| `-d, --duration <seg>` | Duração da janela de medição em segundos | `60` |
| `-b, --baseline <seg>` | Duração da medição em repouso (*baseline*) | `15` |
| `-o, --output <dir>` | Diretório customizado de saída para os resultados | `results/...` |
| `--config <arquivo>` | Caminho do arquivo de configuração `.env` | `config/experiment.env` |

---

## ⚡ Execução Separada do Teste de Carga (`run-load-test.sh`)

O script `run-load-test.sh` executa o `k6` de forma independente:

```bash
# Executar workload padrão do experiment.env (WordPress login/admin ou sintético)
./run-load-test.sh

# Executar workload sintético específico (cpu, text, mixed)
./run-load-test.sh cpu

# Executar apontando para outro IP / porta na rede com taxa e duração customizadas
./run-load-test.sh --url http://192.168.1.50:8080 --rate 5 --duration 60 --workload wordpress
```

### Opções do `run-load-test.sh`:
| Parâmetro | Descrição | Padrão |
|---|---|---|
| `-u, --url <url>` | URL base da aplicação sob teste | `http://127.0.0.1:8080` |
| `-w, --workload <tipo>` | Tipo de carga (`wordpress`, `cpu`, `text`, `mixed`, `login`) | `wordpress` |
| `-r, --rate <req/s>` | Taxa constante de requisições por segundo | `2` |
| `-d, --duration <seg>` | Duração do teste de carga em segundos | `60` |
| `-s, --scale <escala>` | Fator de escala do peso computacional (1 a 5) | `1` |
| `--warmup <seg>` | Duração de aquecimento prévio opcional | `0` |
| `--user <user>` / `--pass <pass>` | Credenciais para o teste de login no WordPress | `marcos` / `Teste1234` |
| `-o, --output <arquivo>` | Caminho para salvar o `k6-summary.json` | `results/k6-summary.json` |

---

## 📊 Painel Visual Interativo

O projeto conta com um painel web interativo para visualização de resultados:

1. Inicie o servidor da interface:
```bash
./scripts/start-server.sh
```
2. Abra o navegador em `http://127.0.0.1:8080/`.
3. Navegue pelas execuções passadas no menu lateral e visualize:
   - **Métricas de Energia**: Total do Host, Total do Processo e Energia Dinâmica (com desconto de baseline).
   - **Potência Média (Watts)** e **Emissões de Carbono Estimadas ($g\text{CO}_2e$)**.
   - **Flamegraph Interativo de Energia**: Atribuição de microjoules por função.
   - **Flamegraph Interativo de CPU**: Amostras de tempo de execução por pilha de chamadas.

---

## ⚙️ Configuração (`config/experiment.env`)

O arquivo `config/experiment.env` centraliza as configurações padrão:

```env
TARGET_LANGUAGE=php
MODE=local

HOST=127.0.0.1
PORT=8080
BASE_URL=http://127.0.0.1:8080

WORKLOAD=wordpress
WP_USER=marcos
WP_PASS=Teste1234
SCALE=1
RATE=2

DURATION_SECONDS=60
WARMUP_SECONDS=10
BASELINE_SECONDS=15
COLLECTOR_LEAD_SECONDS=3
COLLECTOR_TAIL_SECONDS=5

PHPSPY_RATE_HZ=99
SCAPHANDRE_STEP_SECONDS=1
SCAPHANDRE_PROCESS_REGEX="(php|mysqld|mariadbd|apache2)"
SCAPHANDRE_MAX_PROCESSES=100

CARBON_INTENSITY_G_PER_KWH=100
```

---

## 📁 Estrutura do Repositório

```text
green-php-lab-meter-ready/
├── README.md                   # Documentação do projeto
├── run-meter.sh                # Entrypoint universal do medidor (PHP, Java, Python)
├── run-load-test.sh            # Entrypoint do gerador de carga (k6)
├── carbon.py                   # Calculadora standalone de emissões de carbono
├── k6.js                       # Script de teste de carga constante do k6
├── config/
│   └── experiment.env          # Arquivo de configuração de parâmetros
├── measurement/
│   ├── run-meter.sh            # Engine de medição e acoplamento de coletores
│   ├── run-load-test.sh        # Engine de execução do k6
│   ├── analyze_measurement.py  # Analisador de correlação temporal de energia e stacks
│   ├── check-environment.sh    # Validação do ambiente e contadores RAPL
│   ├── install-tools-ubuntu.sh # Instalador de dependências no Ubuntu Linux
│   ├── test-analyzer.sh        # Testes automatizados do analisador
│   └── test-fixtures/         # Conjunto de dados de teste para validação
├── public/
│   └── index.php               # Aplicação PHP de teste e painel visual interativo
├── scripts/
│   └── start-server.sh         # Utilitário para iniciar o painel web
├── tools/
│   ├── FlameGraph/             # Renderizador SVG de Flamegraphs
│   └── phpspy/                 # Profiler de call stacks para PHP
└── results/                    # Diretório onde são gravados os relatórios de medição
```

---

## 🧮 Calculadora de Carbono (`carbon.py`)

Utilitário de linha de comando para conversão direta de Joules em emissões operacionais:

```bash
./carbon.py --energy-j 125.5 --carbon-intensity 100 --requests 120
```

---

## 📌 Boas Práticas de Medição

1. **Desacoplamento de Carga**: Execute o gerador `run-load-test.sh` em um computador cliente separado na rede para garantir isolamento elétrico completo dos contadores RAPL.
2. **Repetição de Medições**: Realize no mínimo 5 repetições para cada medição experimental a fim de obter significância estatística.
3. **Desconto de Baseline**: O medidor desconta automaticamente a taxa de consumo elétrico da máquina em repouso (*idle baseline*), gerando a métrica de **energia dinâmica**.
