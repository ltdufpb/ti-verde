# Measurement summary

- Duration: **60.417 s**
- Successful requests: **120**
- Host total energy: **2231.091257 J**
- Host dynamic energy: **204.435318 J**
- PHP process total energy: **0.657803 J**
- PHP process dynamic energy: **0.657803 J**
- PHP energy/request: **0.005481689 J/request**
- Estimated PHP emissions: **0.000018272298 gCO2e**
- Unattributed PHP energy: **0.516462 J**

## Top sampled self-energy functions

| Function | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|
| `countWordsFast` | 0.047638 | 0.106029 |
| `isPrimeFast` | 0.023851 | 0.023851 |
| `preg_replace` | 0.023621 | 0.023621 |
| `ksort` | 0.023310 | 0.023310 |
| `calculatePrimeChecksumFast` | 0.011460 | 0.035311 |
| `array_values` | 0.011460 | 0.011460 |
| `<main>` | 0.000000 | 0.141341 |
| `executeMixedWorkload` | 0.000000 | 0.141341 |
| `array_filter` | 0.000000 | 0.000000 |
| `normalizeSentence` | 0.000000 | 0.035081 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
