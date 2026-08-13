# Measurement summary

- Duration: **60.455 s**
- Successful requests: **121**
- Host total energy: **2111.462836 J**
- Host dynamic energy: **357.874932 J**
- PHP process total energy: **0.757733 J**
- PHP process dynamic energy: **0.757733 J**
- PHP energy/request: **0.006262258 J/request**
- Estimated PHP emissions: **0.000021048145 gCO2e**
- Unattributed PHP energy: **0.654087 J**

## Top sampled self-energy functions

| Function | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|
| `executeWordpressWorkload` | 0.000000 | 0.103646 |
| `<main>` | 0.000000 | 0.103646 |
| `wpApplyFiltersSlow` | 0.041869 | 0.083120 |
| `preg_replace` | 0.031009 | 0.031009 |
| `wpQueryGetPostsSlow` | 0.020526 | 0.020526 |
| `strtolower` | 0.010243 | 0.010243 |

## Function execution times (Tempo de Execução por Função)

| Function | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |
|---|---:|---:|---:|---:|
| `executeWordpressWorkload` | 6.465696 | 53.436 | 0.000000 | 6.465696 |
| `<main>` | 6.465696 | 53.436 | 0.000000 | 6.465696 |
| `wpApplyFiltersSlow` | 5.390002 | 44.545 | 2.156869 | 5.390002 |
| `preg_replace` | 2.695612 | 22.278 | 2.695612 | 2.695612 |
| `wpQueryGetPostsSlow` | 1.075693 | 8.890 | 1.075693 | 1.075693 |
| `strtolower` | 0.537521 | 4.442 | 0.537521 | 0.537521 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
Open `function-times.csv` for the complete table of function times.
