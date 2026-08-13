# Measurement summary

- Duration: **60.572 s**
- Successful requests: **121**
- Host total energy: **2173.354007 J**
- Host dynamic energy: **161.138125 J**
- PHP process total energy: **21.151595 J**
- PHP process dynamic energy: **21.151595 J**
- PHP energy/request: **0.174806567 J/request**
- Estimated PHP emissions: **0.000587544293 gCO2e**
- Unattributed PHP energy: **0.090053 J**

## Top sampled self-energy functions

| Function | Samples (Calls) | Self energy (J) | Inclusive energy (J) |
|---|---:|---:|---:|
| `<main>` | 301 | 0.553464 | 19.868082 |
| `get_the_block_template_html` | 163 | 0.000000 | 10.781666 |
| `do_blocks` | 158 | 0.044752 | 10.503031 |
| `WP_Block::render` | 158 | 0.409218 | 10.503031 |
| `render_block` | 158 | 0.050895 | 10.503031 |
| `WP_Hook::apply_filters` | 156 | 0.854887 | 10.454262 |
| `render_block_core_pattern` | 102 | 0.070900 | 6.684353 |
| `apply_filters` | 98 | 1.018560 | 6.758991 |
| `WP_Theme_JSON_Resolver::get_merged_data` | 76 | 0.101285 | 5.006056 |
| `WP_Hook::do_action` | 62 | 0.000000 | 4.224789 |

## Function execution times (Tempo de Execução por Função)

| Function | Samples (Calls) | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |
|---|---:|---:|---:|---:|---:|
| `<main>` | 301 | 57.047173 | 471.464 | 1.716173 | 57.047173 |
| `get_the_block_template_html` | 163 | 30.850777 | 254.965 | 0.000000 | 30.850777 |
| `do_blocks` | 158 | 30.007711 | 247.998 | 0.129227 | 30.007711 |
| `WP_Block::render` | 158 | 30.007711 | 247.998 | 1.114963 | 30.007711 |
| `render_block` | 158 | 30.007711 | 247.998 | 0.165386 | 30.007711 |
| `WP_Hook::apply_filters` | 156 | 29.959343 | 247.598 | 2.523316 | 29.959343 |
| `render_block_core_pattern` | 102 | 19.290761 | 159.428 | 0.194682 | 19.290761 |
| `apply_filters` | 98 | 19.210808 | 158.767 | 2.826485 | 19.210808 |
| `WP_Theme_JSON_Resolver::get_merged_data` | 76 | 14.206516 | 117.409 | 0.299678 | 14.206516 |
| `WP_Hook::do_action` | 62 | 12.081674 | 99.849 | 0.000000 | 12.081674 |
| `render_block_core_template_part` | 64 | 11.983962 | 99.041 | 0.000000 | 11.983962 |
| `do_action` | 60 | 11.692472 | 96.632 | 0.166243 | 11.692472 |
| `wp_render_block_style_variation_support_styles` | 52 | 9.678426 | 79.987 | 0.000000 | 9.678426 |
| `wpdb::query` | 52 | 9.341665 | 77.204 | 0.468889 | 9.341665 |
| `mysqli_query` | 53 | 9.283222 | 76.721 | 9.283222 | 9.283222 |

Open `energy-flamegraph.svg` for energy-attributed stacks.
Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.
Open `function-times.csv` for the complete table of function times.
