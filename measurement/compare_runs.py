#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def reduction(before: float, after: float) -> float | None:
    return (before - after) / before * 100 if before else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("slow_dir", type=Path)
    parser.add_argument("fast_dir", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    slow = load(args.slow_dir / "summary.json")
    fast = load(args.fast_dir / "summary.json")

    se, fe = slow["energy"], fast["energy"]
    sc, fc = slow["carbon"], fast["carbon"]
    sw, fw = slow["workload"], fast["workload"]

    entries = [
        (
            "Successful requests",
            float(sw.get("successful_requests", 0)),
            float(fw.get("successful_requests", 0)),
            None,
        ),
        (
            "Dropped iterations",
            float(sw.get("dropped_iterations", 0)),
            float(fw.get("dropped_iterations", 0)),
            None,
        ),
        (
            "p95 latency (ms)",
            float(sw.get("request_duration_ms", {}).get("p95", 0)),
            float(fw.get("request_duration_ms", {}).get("p95", 0)),
        ),
        (
            "PHP total energy (J)",
            float(se["php_process_total_j"]),
            float(fe["php_process_total_j"]),
        ),
        (
            "PHP dynamic energy (J)",
            float(se["php_process_dynamic_j"]),
            float(fe["php_process_dynamic_j"]),
        ),
        (
            "PHP J/successful request",
            float(se["php_j_per_successful_request"] or 0),
            float(fe["php_j_per_successful_request"] or 0),
        ),
        (
            "Host dynamic energy (J)",
            float(se["host_dynamic_j"]),
            float(fe["host_dynamic_j"]),
        ),
        (
            "PHP total emissions (gCO2e)",
            float(sc["php_process_total_g_co2e"]),
            float(fc["php_process_total_g_co2e"]),
        ),
    ]

    lines = [
        "# Slow versus fast comparison",
        "",
        "| Metric | Slow | Fast | Reduction |",
        "|---|---:|---:|---:|",
    ]

    for entry in entries:
        name, slow_value, fast_value = entry[:3]
        if len(entry) == 4:
            reduction_value = entry[3]
        else:
            reduction_value = reduction(slow_value, fast_value)

        reduction_text = (
            "n/a" if reduction_value is None else f"{reduction_value:.2f}%"
        )
        lines.append(
            f"| {name} | {slow_value:.9f} | {fast_value:.9f} | {reduction_text} |"
        )

    lines.extend([
        "",
        "Positive reduction means the fast version used less energy or time.",
        "Both runs should have zero dropped iterations and similar request counts.",
        "",
    ])

    slow_ft = {item["function"]: item for item in slow.get("function_times", [])}
    fast_ft = {item["function"]: item for item in fast.get("function_times", [])}

    all_funcs = sorted(
        set(slow_ft) | set(fast_ft),
        key=lambda f: slow_ft.get(f, {}).get("total_time_s", 0.0),
        reverse=True,
    )

    if all_funcs:
        lines.extend([
            "## Function execution time comparison (Tempo Total e Médio por Função)",
            "",
            "| Function | Slow Total (s) | Fast Total (s) | Slow Avg (ms) | Fast Avg (ms) | Time Reduction |",
            "|---|---:|---:|---:|---:|---:|",
        ])
        for name in all_funcs[:15]:
            s_item = slow_ft.get(name, {})
            f_item = fast_ft.get(name, {})
            st = float(s_item.get("total_time_s", 0.0))
            ft = float(f_item.get("total_time_s", 0.0))
            sa = float(s_item.get("avg_time_ms", 0.0))
            fa = float(f_item.get("avg_time_ms", 0.0))
            red = reduction(st, ft) if st > 0 else None
            red_str = "n/a" if red is None else f"{red:.2f}%"
            lines.append(
                f"| `{name}` | {st:.6f} | {ft:.6f} | {sa:.3f} | {fa:.3f} | {red_str} |"
            )
        lines.append("")

    text = "\n".join(lines)
    output = args.output or args.fast_dir.parent / "COMPARISON.md"
    output.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
