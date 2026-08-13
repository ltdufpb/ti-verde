# Measurement summary

- Duration: **60.626 s**
- Successful requests: **121**
- Host total energy: **2438.908052 J**
- Host dynamic energy: **509.368800 J**
- PHP process total energy: **47.368454 J**
- PHP process dynamic energy: **47.368454 J**
- PHP energy/request: **0.391474826 J/request**
- Estimated PHP emissions: **0.001315790388 gCO2e**
- Unattributed PHP energy: **0.086397 J**

## Top sampled self-energy functions

| Function | Samples (Calls) | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|---:|
| `<main>` | 939 | 0.815531 | 45.806475 |
| `WP_Hook::apply_filters` | 630 | 0.581003 | 30.681088 |
| `wp_signon` | 480 | 0.000000 | 23.350416 |
| `apply_filters` | 379 | 0.899920 | 18.461257 |
| `wp_authenticate` | 307 | 0.000000 | 14.879993 |
| `wpdb::query` | 306 | 0.179430 | 14.841545 |
| `wp_check_password` | 305 | 0.000000 | 14.796494 |
| `password_verify` | 305 | 14.796494 | 14.796494 |
| `wp_authenticate_username_password` | 305 | 0.000000 | 14.796494 |
| `mysqli_query` | 300 | 14.613432 | 14.613432 |

## Function execution times (Tempo de Execução por Função)

| Function | Samples (Calls) | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |
|---|---:|---:|---:|---:|---:|
| `<main>` | 939 | 58.617035 | 484.438 | 1.071252 | 58.617035 |
| `WP_Hook::apply_filters` | 630 | 39.404427 | 325.656 | 0.759781 | 39.404427 |
| `wp_signon` | 480 | 29.804661 | 246.320 | 0.000000 | 29.804661 |
| `apply_filters` | 379 | 23.659359 | 195.532 | 1.106301 | 23.659359 |
| `wp_authenticate` | 307 | 19.074027 | 157.637 | 0.000000 | 19.074027 |
| `wpdb::query` | 306 | 19.023403 | 157.218 | 0.252885 | 19.023403 |
| `wp_check_password` | 305 | 18.959616 | 156.691 | 0.000000 | 18.959616 |
| `password_verify` | 305 | 18.959616 | 156.691 | 18.959616 | 18.959616 |
| `wp_authenticate_username_password` | 305 | 18.959616 | 156.691 | 0.000000 | 18.959616 |
| `mysqli_query` | 300 | 18.705133 | 154.588 | 18.705133 | 18.705133 |
| `wpdb::_do_query` | 298 | 18.552258 | 153.324 | 0.000000 | 18.552258 |
| `WP_Hook::do_action` | 277 | 17.452828 | 144.238 | 0.000000 | 17.452828 |
| `do_action` | 273 | 17.181160 | 141.993 | 0.000000 | 17.181160 |
| `update_user_meta` | 147 | 9.092483 | 75.144 | 0.000000 | 9.092483 |
| `update_metadata` | 147 | 9.092483 | 75.144 | 0.000000 | 9.092483 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
Open `function-times.csv` for the complete table of function times.
