# Measurement summary

- Duration: **60.409 s**
- Successful requests: **120**
- Host total energy: **2261.075296 J**
- Host dynamic energy: **209.340530 J**
- PHP process total energy: **7.654008 J**
- PHP process dynamic energy: **7.654008 J**
- PHP energy/request: **0.063783401 J/request**
- Estimated PHP emissions: **0.000212611337 gCO2e**
- Unattributed PHP energy: **0.051603 J**

## Top sampled self-energy functions

| Function | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|
| `countWordsSlow` | 5.945289 | 6.185390 |
| `isPrimeSlow` | 1.233624 | 1.233624 |
| `array_unique` | 0.131311 | 0.131311 |
| `array_values` | 0.130671 | 0.130671 |
| `{closure:normalizeSentence():131}` | 0.055563 | 0.055563 |
| `ksort` | 0.053227 | 0.053227 |
| `hash` | 0.052720 | 0.052720 |
| `executeMixedWorkload` | 0.000000 | 7.419014 |
| `array_filter` | 0.000000 | 0.055563 |
| `textChecksum` | 0.000000 | 0.052720 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
