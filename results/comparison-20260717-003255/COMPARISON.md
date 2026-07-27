# Slow versus fast comparison

| Metric | Slow | Fast | Reduction |
|---|---:|---:|---:|
| Successful requests | 120.000000000 | 120.000000000 | n/a |
| Dropped iterations | 0.000000000 | 0.000000000 | n/a |
| p95 latency (ms) | 20.154297450 | 9.085065500 | 54.92% |
| PHP total energy (J) | 7.654008142 | 0.657802714 | 91.41% |
| PHP dynamic energy (J) | 7.654008142 | 0.657802714 | 91.41% |
| PHP J/successful request | 0.063783401 | 0.005481689 | 91.41% |
| Host dynamic energy (J) | 209.340529600 | 204.435318025 | 2.34% |
| PHP total emissions (gCO2e) | 0.000212611 | 0.000018272 | 91.41% |

Positive reduction means the fast version used less energy or time.
Both runs should have zero dropped iterations and similar request counts.
