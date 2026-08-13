# Slow versus fast comparison

| Metric | Slow | Fast | Reduction |
|---|---:|---:|---:|
| Successful requests | 121.000000000 | 120.000000000 | n/a |
| Dropped iterations | 0.000000000 | 0.000000000 | n/a |
| p95 latency (ms) | 5.966073000 | 1.354158600 | 77.30% |
| PHP total energy (J) | 0.757733224 | 0.331085030 | 56.31% |
| PHP dynamic energy (J) | 0.757733224 | 0.331085030 | 56.31% |
| PHP J/successful request | 0.006262258 | 0.002759042 | 55.94% |
| Host dynamic energy (J) | 357.874932206 | 92.730867263 | 74.09% |
| PHP total emissions (gCO2e) | 0.000021048 | 0.000009197 | 56.31% |

Positive reduction means the fast version used less energy or time.
Both runs should have zero dropped iterations and similar request counts.

## Function execution time comparison (Tempo Total e Médio por Função)

| Function | Slow Total (s) | Fast Total (s) | Slow Avg (ms) | Fast Avg (ms) | Time Reduction |
|---|---:|---:|---:|---:|---:|
| `executeWordpressWorkload` | 6.465696 | 1.078100 | 53.436 | 8.984 | 83.33% |
| `<main>` | 6.465696 | 1.078100 | 53.436 | 8.984 | 83.33% |
| `wpApplyFiltersSlow` | 5.390002 | 0.000000 | 44.545 | 0.000 | 100.00% |
| `preg_replace` | 2.695612 | 0.000000 | 22.278 | 0.000 | 100.00% |
| `wpQueryGetPostsSlow` | 1.075693 | 0.000000 | 8.890 | 0.000 | 100.00% |
| `strtolower` | 0.537521 | 0.000000 | 4.442 | 0.000 | 100.00% |
| `hash` | 0.000000 | 1.078100 | 0.000 | 8.984 | n/a |
| `wpApplyFiltersFast` | 0.000000 | 1.078100 | 0.000 | 8.984 | n/a |
