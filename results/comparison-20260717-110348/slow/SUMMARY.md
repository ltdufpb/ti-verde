# Measurement summary

- Duration: **61.222 s**
- Successful requests: **121**
- Host total energy: **1826.617247 J**
- Host dynamic energy: **105.457391 J**
- PHP process total energy: **4.595066 J**
- PHP process dynamic energy: **4.595066 J**
- PHP energy/request: **0.037975752 J/request**
- Estimated PHP emissions: **0.000127640723 gCO2e**
- Unattributed PHP energy: **0.023898 J**

## Top sampled self-energy functions

| Function | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|
| `executeMixedWorkload` | 0.000000 | 4.571168 |
| `<main>` | 0.000000 | 4.571168 |
| `executeTextWorkload` | 0.128888 | 3.541210 |
| `countWordsSlow` | 3.134736 | 3.379222 |
| `executeCpuWorkload` | 0.000000 | 1.029958 |
| `calculatePrimeChecksumSlow` | 0.027558 | 1.029958 |
| `isPrimeSlow` | 1.002400 | 1.002400 |
| `normalizeSentence` | 0.000000 | 0.205175 |
| `array_filter` | 0.045417 | 0.129579 |
| `{closure:normalizeSentence():131}` | 0.084162 | 0.084162 |

## Function execution times (Tempo de Execução por Função)

| Function | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |
|---|---:|---:|---:|---:|
| `executeMixedWorkload` | 60.306726 | 498.403 | 0.000000 | 60.306726 |
| `<main>` | 60.306726 | 498.403 | 0.000000 | 60.306726 |
| `executeTextWorkload` | 47.399931 | 391.735 | 1.765267 | 47.399931 |
| `countWordsSlow` | 45.241487 | 373.897 | 41.869215 | 45.241487 |
| `executeCpuWorkload` | 12.906794 | 106.668 | 0.000000 | 12.906794 |
| `calculatePrimeChecksumSlow` | 12.906794 | 106.668 | 0.295642 | 12.906794 |
| `isPrimeSlow` | 12.611152 | 104.224 | 12.611152 | 12.611152 |
| `normalizeSentence` | 2.795284 | 23.102 | 0.000000 | 2.795284 |
| `array_filter` | 1.643197 | 13.580 | 0.416502 | 1.643197 |
| `{closure:normalizeSentence():131}` | 1.226694 | 10.138 | 1.226694 | 1.226694 |
| `preg_split` | 0.576987 | 4.768 | 0.576987 | 0.576987 |
| `array_unique` | 0.576987 | 4.768 | 0.576987 | 0.576987 |
| `preg_replace` | 0.575101 | 4.753 | 0.575101 | 0.575101 |
| `buildTextCorpus` | 0.393178 | 3.249 | 0.393178 | 0.393178 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
Open `function-times.csv` for the complete table of function times.
