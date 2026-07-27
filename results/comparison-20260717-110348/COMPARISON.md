# Slow versus fast comparison

| Metric | Slow | Fast | Reduction |
|---|---:|---:|---:|
| Successful requests | 121.000000000 | 120.000000000 | n/a |
| Dropped iterations | 0.000000000 | 0.000000000 | n/a |
| p95 latency (ms) | 13.228915000 | 1.524549000 | 88.48% |
| PHP total energy (J) | 4.595066031 | 0.441225703 | 90.40% |
| PHP dynamic energy (J) | 4.595066031 | 0.441225703 | 90.40% |
| PHP J/successful request | 0.037975752 | 0.003676881 | 90.32% |
| Host dynamic energy (J) | 105.457391100 | 305.287090308 | -189.49% |
| PHP total emissions (gCO2e) | 0.000127641 | 0.000012256 | 90.40% |

Positive reduction means the fast version used less energy or time.
Both runs should have zero dropped iterations and similar request counts.

## Function execution time comparison (Tempo Total e Médio por Função)

| Function | Slow Total (s) | Fast Total (s) | Slow Avg (ms) | Fast Avg (ms) | Time Reduction |
|---|---:|---:|---:|---:|---:|
| `executeMixedWorkload` | 60.306726 | 4.629052 | 498.403 | 38.575 | 92.32% |
| `<main>` | 60.306726 | 5.779437 | 498.403 | 48.162 | 90.42% |
| `executeTextWorkload` | 47.399931 | 4.629052 | 391.735 | 38.575 | 90.23% |
| `countWordsSlow` | 45.241487 | 0.000000 | 373.897 | 0.000 | 100.00% |
| `executeCpuWorkload` | 12.906794 | 0.000000 | 106.668 | 0.000 | 100.00% |
| `calculatePrimeChecksumSlow` | 12.906794 | 0.000000 | 106.668 | 0.000 | 100.00% |
| `isPrimeSlow` | 12.611152 | 0.000000 | 104.224 | 0.000 | 100.00% |
| `normalizeSentence` | 2.795284 | 3.459724 | 23.102 | 28.831 | -23.77% |
| `array_filter` | 1.643197 | 1.152744 | 13.580 | 9.606 | 29.85% |
| `{closure:normalizeSentence():131}` | 1.226694 | 0.000000 | 10.138 | 0.000 | 100.00% |
| `preg_split` | 0.576987 | 0.000000 | 4.768 | 0.000 | 100.00% |
| `array_unique` | 0.576987 | 0.000000 | 4.768 | 0.000 | 100.00% |
| `preg_replace` | 0.575101 | 1.152984 | 4.753 | 9.608 | -100.48% |
| `buildTextCorpus` | 0.393178 | 0.000000 | 3.249 | 0.000 | 100.00% |
| `isPrimeFast` | 0.000000 | 1.155260 | 0.000 | 9.627 | n/a |
