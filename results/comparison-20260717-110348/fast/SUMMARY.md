# Measurement summary

- Duration: **60.357 s**
- Successful requests: **120**
- Host total energy: **1904.311428 J**
- Host dynamic energy: **305.287090 J**
- PHP process total energy: **0.441226 J**
- PHP process dynamic energy: **0.441226 J**
- PHP energy/request: **0.003676881 J/request**
- Estimated PHP emissions: **0.000012256270 gCO2e**
- Unattributed PHP energy: **0.402710 J**

## Top sampled self-energy functions

| Function | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|
| `<main>` | 0.000000 | 0.038516 |
| `executeTextWorkload` | 0.000000 | 0.038516 |
| `executeMixedWorkload` | 0.000000 | 0.038516 |
| `countWordsFast` | 0.000000 | 0.038516 |
| `normalizeSentence` | 0.000000 | 0.038516 |
| `array_values` | 0.000000 | 0.000000 |
| `isPrimeFast` | 0.000000 | 0.000000 |
| `preg_replace` | 0.038516 | 0.038516 |
| `array_filter` | 0.000000 | 0.000000 |
| `parse_url` | 0.000000 | 0.000000 |

## Function execution times (Tempo de Execução por Função)

| Function | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |
|---|---:|---:|---:|---:|
| `<main>` | 5.779437 | 48.162 | 0.000000 | 5.779437 |
| `executeTextWorkload` | 4.629052 | 38.575 | 0.000000 | 4.629052 |
| `executeMixedWorkload` | 4.629052 | 38.575 | 0.000000 | 4.629052 |
| `countWordsFast` | 4.629052 | 38.575 | 1.169328 | 4.629052 |
| `normalizeSentence` | 3.459724 | 28.831 | 1.153996 | 3.459724 |
| `array_values` | 1.174685 | 9.789 | 1.174685 | 1.174685 |
| `isPrimeFast` | 1.155260 | 9.627 | 1.155260 | 1.155260 |
| `preg_replace` | 1.152984 | 9.608 | 1.152984 | 1.152984 |
| `array_filter` | 1.152744 | 9.606 | 1.152744 | 1.152744 |
| `parse_url` | 1.150385 | 9.587 | 1.150385 | 1.150385 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
Open `function-times.csv` for the complete table of function times.
