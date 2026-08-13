# Measurement summary

- Duration: **60.482 s**
- Successful requests: **120**
- Host total energy: **1966.779636 J**
- Host dynamic energy: **92.730867 J**
- PHP process total energy: **0.331085 J**
- PHP process dynamic energy: **0.331085 J**
- PHP energy/request: **0.002759042 J/request**
- Estimated PHP emissions: **0.000009196806 gCO2e**
- Unattributed PHP energy: **0.331085 J**

## Top sampled self-energy functions

| Function | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|
| `wpApplyFiltersFast` | 0.000000 | 0.000000 |
| `<main>` | 0.000000 | 0.000000 |
| `hash` | 0.000000 | 0.000000 |
| `executeWordpressWorkload` | 0.000000 | 0.000000 |

## Function execution times (Tempo de Execução por Função)

| Function | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |
|---|---:|---:|---:|---:|
| `wpApplyFiltersFast` | 1.078100 | 8.984 | 0.000000 | 1.078100 |
| `<main>` | 1.078100 | 8.984 | 0.000000 | 1.078100 |
| `hash` | 1.078100 | 8.984 | 1.078100 | 1.078100 |
| `executeWordpressWorkload` | 1.078100 | 8.984 | 0.000000 | 1.078100 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
Open `function-times.csv` for the complete table of function times.
