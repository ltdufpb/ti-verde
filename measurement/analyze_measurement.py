#!/usr/bin/env python3
"""Correlate Scaphandre process power with phpspy stack samples."""

from __future__ import annotations

import argparse
import bisect
import csv
import json
import math
import re
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

from frame_naming import qualify_frame_name

@dataclass(frozen=True)
class PowerPoint:
    timestamp: float
    microwatts: float


@dataclass(frozen=True)
class StackSample:
    timestamp: float
    pid: int
    stack: tuple[str, ...]


def read_concatenated_json(path: Path) -> list[dict[str, Any]]:
    """
    Read Scaphandre output in either of these forms:

    1. Concatenated reports:
       {...}{...}{...}

    2. Arrays of reports:
       [{...}, {...}]

    3. Multiple concatenated arrays:
       [{...}][{...}]
    """

    text = path.read_text(encoding="utf-8", errors="replace")
    decoder = json.JSONDecoder()

    reports: list[dict[str, Any]] = []
    index = 0

    while index < len(text):
        while index < len(text) and (
            text[index].isspace() or text[index] == ","
        ):
            index += 1

        if index >= len(text):
            break

        try:
            value, end = decoder.raw_decode(text, index)
        except json.JSONDecodeError as exc:
            context = text[max(0, index - 100):index + 200]

            raise ValueError(
                "Invalid Scaphandre JSON near "
                f"byte {index}: {exc}\n"
                f"Context:\n{context}"
            ) from exc

        index = end

        if isinstance(value, dict):
            reports.append(value)

        elif isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    reports.append(item)

        elif value is None:
            continue

        else:
            print(
                "WARNING: ignoring unexpected Scaphandre "
                f"JSON value of type {type(value).__name__}",
                file=sys.stderr,
            )

    if not reports:
        raise ValueError(
            f"No Scaphandre report objects were found in {path}"
        )

    return reports

def deduplicate_points(points: Iterable[PowerPoint]) -> list[PowerPoint]:
    by_time: dict[float, float] = {}
    for point in points:
        if math.isfinite(point.timestamp) and math.isfinite(point.microwatts):
            by_time[point.timestamp] = point.microwatts
    return [PowerPoint(t, by_time[t]) for t in sorted(by_time)]


def extract_scaphandre_series(
    reports: Sequence[dict[str, Any]],
    target_pid: int | None,
) -> tuple[list[PowerPoint], list[PowerPoint]]:
    host_points: list[PowerPoint] = []
    process_points: list[PowerPoint] = []

    for report in reports:
        host = report.get("host") or {}
        try:
            host_points.append(
                PowerPoint(
                    float(host["timestamp"]),
                    float(host["consumption"]),
                )
            )
        except (KeyError, TypeError, ValueError):
            pass

        for consumer in report.get("consumers") or []:
            try:
                pid = int(consumer["pid"])
                if target_pid is not None and pid != target_pid:
                    continue
                process_points.append(
                    PowerPoint(
                        float(consumer["timestamp"]),
                        float(consumer["consumption"]),
                    )
                )
            except (KeyError, TypeError, ValueError):
                continue

    return deduplicate_points(host_points), deduplicate_points(process_points)


def interpolate(points: Sequence[PowerPoint], timestamp: float) -> float:
    if not points:
        raise ValueError("Cannot interpolate an empty power series.")

    times = [p.timestamp for p in points]
    pos = bisect.bisect_left(times, timestamp)

    if pos < len(points) and points[pos].timestamp == timestamp:
        return points[pos].microwatts
    if pos == 0:
        return points[0].microwatts
    if pos >= len(points):
        return points[-1].microwatts

    left = points[pos - 1]
    right = points[pos]
    span = right.timestamp - left.timestamp
    if span <= 0:
        return left.microwatts

    fraction = (timestamp - left.timestamp) / span
    return left.microwatts + fraction * (right.microwatts - left.microwatts)


def crop_series(
    points: Sequence[PowerPoint],
    start: float,
    end: float,
) -> list[PowerPoint]:
    if start >= end:
        raise ValueError("Measurement start must be before end.")
    if len(points) < 2:
        return []

    cropped = [PowerPoint(start, interpolate(points, start))]
    cropped.extend(p for p in points if start < p.timestamp < end)
    cropped.append(PowerPoint(end, interpolate(points, end)))
    return deduplicate_points(cropped)


def integrate_microjoules(points: Sequence[PowerPoint]) -> float:
    energy = 0.0
    for left, right in zip(points, points[1:]):
        dt = right.timestamp - left.timestamp
        if dt <= 0:
            continue
        average_power = (left.microwatts + right.microwatts) / 2.0
        energy += average_power * dt
    return energy


def average_power(points: Sequence[PowerPoint]) -> float:
    if len(points) < 2:
        return 0.0
    duration = points[-1].timestamp - points[0].timestamp
    return integrate_microjoules(points) / duration if duration > 0 else 0.0


FRAME_RE = re.compile(r"^(\d+)\s+(.*?)\s+(.+):(-?\d+)$")
TRACE_TS_RE = re.compile(r"^# trace_ts = ([0-9]+(?:\.[0-9]+)?)$")
PID_RE = re.compile(r"^# pid = ([0-9]+)$")


def clean_frame_name(name: str) -> str:
    return name.strip().replace(";", ":") or "<unknown>"


def parse_phpspy(path: Path, project_root: Path | None = None) -> list[StackSample]:
    samples: list[StackSample] = []
    frames: list[tuple[int, str]] = []
    timestamp: float | None = None
    pid: int | None = None

    def finish_trace() -> None:
        nonlocal frames, timestamp, pid
        if frames and timestamp is not None and pid is not None:
            # phpspy frame 0 is the leaf. FlameGraph expects root first.
            ordered = tuple(
                clean_frame_name(name)
                for _, name in sorted(frames, key=lambda item: item[0], reverse=True)
            )
            samples.append(StackSample(timestamp, pid, ordered))
        frames = []
        timestamp = None
        pid = None

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()

        if not line or line.startswith("# - - -"):
            finish_trace()
            continue

        match = FRAME_RE.match(line)
        if match:
            depth = int(match.group(1))
            name = match.group(2)
            filename = match.group(3)
            frames.append((depth, qualify_frame_name(name, filename, project_root)))
            continue

        match = TRACE_TS_RE.match(line)
        if match:
            timestamp = float(match.group(1))
            continue

        match = PID_RE.match(line)
        if match:
            pid = int(match.group(1))

    finish_trace()
    return sorted(samples, key=lambda sample: sample.timestamp)


def write_folded(path: Path, weights: dict[tuple[str, ...], float]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for stack, weight in sorted(
            weights.items(),
            key=lambda item: item[1],
            reverse=True,
        ):
            if weight > 0 and stack:
                handle.write(f"{';'.join(stack)} {max(1, round(weight))}\n")


def attribute_energy_to_stacks(
    process_points: Sequence[PowerPoint],
    samples: Sequence[StackSample],
    target_pid: int,
) -> tuple[
    dict[tuple[str, ...], float],
    dict[tuple[str, ...], float],
    dict[str, float],
    dict[str, float],
    dict[str, float],
    dict[str, float],
    float,
    float,
]:
    energy_by_stack: dict[tuple[str, ...], float] = defaultdict(float)
    samples_by_stack: dict[tuple[str, ...], float] = defaultdict(float)
    self_energy: dict[str, float] = defaultdict(float)
    inclusive_energy: dict[str, float] = defaultdict(float)
    self_time: dict[str, float] = defaultdict(float)
    inclusive_time: dict[str, float] = defaultdict(float)
    unattributed_energy = 0.0
    unattributed_time = 0.0

    selected = [sample for sample in samples if sample.pid == target_pid]
    sample_times = [sample.timestamp for sample in selected]

    for left, right in zip(process_points, process_points[1:]):
        dt = right.timestamp - left.timestamp
        if dt <= 0:
            continue

        interval_energy = ((left.microwatts + right.microwatts) / 2.0) * dt
        begin = bisect.bisect_left(sample_times, left.timestamp)
        finish = bisect.bisect_left(sample_times, right.timestamp)
        interval_samples = selected[begin:finish]

        if not interval_samples:
            unattributed_energy += interval_energy
            unattributed_time += dt
            energy_by_stack[("[unattributed: no stack sample]",)] += interval_energy
            continue

        energy_per_sample = interval_energy / len(interval_samples)
        time_per_sample = dt / len(interval_samples)

        for sample in interval_samples:
            energy_by_stack[sample.stack] += energy_per_sample
            samples_by_stack[sample.stack] += 1

            leaf = sample.stack[-1]
            self_energy[leaf] += energy_per_sample
            self_time[leaf] += time_per_sample

            for function in set(sample.stack):
                inclusive_energy[function] += energy_per_sample
                inclusive_time[function] += time_per_sample

    return (
        energy_by_stack,
        samples_by_stack,
        self_energy,
        inclusive_energy,
        self_time,
        inclusive_time,
        unattributed_energy,
        unattributed_time,
    )


def load_json(path: Path | None) -> dict[str, Any]:
    if path is None or not path.exists():
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    return value if isinstance(value, dict) else {}


def safe_divide(numerator: float, denominator: float) -> float | None:
    return numerator / denominator if denominator > 0 else None


def carbon_g(energy_j: float, intensity_g_per_kwh: float) -> float:
    return energy_j / 3_600_000.0 * intensity_g_per_kwh


def generate_svg(
    flamegraph_script: Path,
    folded: Path,
    output: Path,
    title: str,
    count_name: str,
) -> None:
    with output.open("wb") as destination:
        subprocess.run(
            [
                "perl",
                str(flamegraph_script),
                f"--title={title}",
                f"--countname={count_name}",
                str(folded),
            ],
            check=True,
            stdout=destination,
        )


def validate_scaphandre(path: Path) -> None:
    reports = read_concatenated_json(path)
    host, _ = extract_scaphandre_series(reports, None)
    if not host:
        raise ValueError("No host power readings in Scaphandre JSON.")
    print(f"Valid Scaphandre JSON: {len(reports)} reports, {len(host)} readings.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scaphandre", type=Path)
    parser.add_argument("--phpspy", type=Path)
    parser.add_argument("--pyspy", type=Path)
    parser.add_argument("--jfr", type=Path)
    parser.add_argument("--application-prefix", type=str, default=None)
    parser.add_argument("--project-root", type=Path, default=None)
    parser.add_argument("--start-time", type=float)
    parser.add_argument("--pyspy-rate", type=float, default=100.0)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--window", type=Path)
    parser.add_argument("--k6", type=Path)
    parser.add_argument("--target-pid", type=int)
    parser.add_argument("--carbon-intensity", type=float, default=0.0)
    parser.add_argument("--flamegraph-script", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--validate-scaphandre", type=Path)
    args = parser.parse_args()

    if args.validate_scaphandre:
        validate_scaphandre(args.validate_scaphandre)
        return

    if not all([args.scaphandre, args.window, args.output_dir]) or not (
        args.phpspy or args.pyspy or args.jfr
    ):
        parser.error(
            "--scaphandre, --window, --output-dir and one of "
            "--phpspy, --pyspy or --jfr are required."
        )

    if args.pyspy and args.start_time is None:
        parser.error("--start-time is required when using --pyspy.")

    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    window = load_json(args.window)
    start = float(window["start_timestamp"])
    end = float(window["end_timestamp"])
    target_pid = int(args.target_pid or window["target_pid"])
    duration = end - start
    language = window.get("language", "process").upper()

    reports = read_concatenated_json(args.scaphandre)
    host_all, process_all = extract_scaphandre_series(reports, target_pid)
    host_points = crop_series(host_all, start, end)
    process_points = crop_series(process_all, start, end)

    if len(host_points) < 2:
        raise ValueError("Not enough host samples around the measurement window.")
    if len(process_points) < 2:
        raise ValueError(
            f"Not enough {language} PID {target_pid} samples. Check process filtering."
        )

    host_energy_uj = integrate_microjoules(host_points)
    process_energy_uj = integrate_microjoules(process_points)

    baseline_host_uw = 0.0
    baseline_process_uw = 0.0

    if args.baseline and args.baseline.exists():
        baseline_reports = read_concatenated_json(args.baseline)
        baseline_host, baseline_process = extract_scaphandre_series(
            baseline_reports,
            target_pid,
        )
        baseline_host_uw = average_power(baseline_host)
        baseline_process_uw = average_power(baseline_process)

    dynamic_host_uj = max(0.0, host_energy_uj - baseline_host_uw * duration)
    dynamic_process_uj = max(0.0, process_energy_uj - baseline_process_uw * duration)

    if args.jfr:
        from jfr_parser import parse_jfr
        samples = parse_jfr(args.jfr, target_pid)
    elif args.pyspy:
        from pyspy_parser import parse_pyspy
        samples = parse_pyspy(
            args.pyspy, target_pid, args.start_time, args.pyspy_rate, args.project_root
        )
    else:
        samples = parse_phpspy(args.phpspy, args.project_root)
    (
        energy_stacks,
        cpu_stacks,
        self_energy,
        inclusive_energy,
        self_time,
        inclusive_time,
        unattributed_uj,
        unattributed_time_s,
    ) = attribute_energy_to_stacks(process_points, samples, target_pid)

    if args.application_prefix:
        from application_scope import summarize_by_scope

        prefixes = (args.application_prefix,)
        self_energy = summarize_by_scope(self_energy, prefixes)
        inclusive_energy = summarize_by_scope(inclusive_energy, prefixes)
        self_time = summarize_by_scope(self_time, prefixes)
        inclusive_time = summarize_by_scope(inclusive_time, prefixes)

    energy_folded = output_dir / "energy.folded"
    cpu_folded = output_dir / "cpu.folded"
    write_folded(energy_folded, energy_stacks)
    write_folded(cpu_folded, cpu_stacks)

    if args.flamegraph_script:
        generate_svg(
            args.flamegraph_script,
            energy_folded,
            output_dir / "energy-flamegraph.svg",
            f"{language} energy-attributed hotspots",
            "microjoules",
        )
        generate_svg(
            args.flamegraph_script,
            cpu_folded,
            output_dir / "cpu-flamegraph.svg",
            f"{language} sampled execution hotspots",
            "samples",
        )

    k6 = load_json(args.k6)
    successful = int(k6.get("successful_requests", 0) or 0)
    intensity = max(0.0, float(args.carbon_intensity))

    functions = sorted(
        set(self_energy) | set(inclusive_energy) | set(self_time) | set(inclusive_time),
        key=lambda name: inclusive_time.get(name, 0.0),
        reverse=True,
    )

    function_times_list = []
    for name in functions:
        st_s = self_time.get(name, 0.0)
        it_s = inclusive_time.get(name, 0.0)
        avg_st_ms = (st_s / successful * 1000.0) if successful > 0 else 0.0
        avg_it_ms = (it_s / successful * 1000.0) if successful > 0 else 0.0
        self_uj = self_energy.get(name, 0.0)
        inclusive_uj = inclusive_energy.get(name, 0.0)

        function_times_list.append({
            "function": name,
            "total_time_s": it_s,
            "avg_time_ms": avg_it_ms,
            "self_time_s": st_s,
            "avg_self_time_ms": avg_st_ms,
            "inclusive_time_s": it_s,
            "avg_inclusive_time_ms": avg_it_ms,
            "self_energy_j": self_uj / 1_000_000.0,
            "inclusive_energy_j": inclusive_uj / 1_000_000.0,
        })

    function_times_csv = output_dir / "function-times.csv"
    with function_times_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([
            "function",
            "total_time_s",
            "avg_time_ms",
            "self_time_s",
            "avg_self_time_ms",
            "inclusive_time_s",
            "avg_inclusive_time_ms",
        ])
        for ft in function_times_list:
            writer.writerow([
                ft["function"],
                f"{ft['total_time_s']:.6f}",
                f"{ft['avg_time_ms']:.3f}",
                f"{ft['self_time_s']:.6f}",
                f"{ft['avg_self_time_ms']:.3f}",
                f"{ft['inclusive_time_s']:.6f}",
                f"{ft['avg_inclusive_time_ms']:.3f}",
            ])

    top_csv = output_dir / "top-functions.csv"
    with top_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([
            "function",
            "self_energy_j",
            "self_energy_percent_of_process",
            "inclusive_energy_j",
            "inclusive_energy_percent_of_process",
            "self_time_s",
            "avg_self_time_ms",
            "inclusive_time_s",
            "avg_inclusive_time_ms",
        ])
        for name in functions:
            self_uj = self_energy.get(name, 0.0)
            inclusive_uj = inclusive_energy.get(name, 0.0)
            st_s = self_time.get(name, 0.0)
            it_s = inclusive_time.get(name, 0.0)
            avg_st_ms = (st_s / successful * 1000.0) if successful > 0 else 0.0
            avg_it_ms = (it_s / successful * 1000.0) if successful > 0 else 0.0
            writer.writerow([
                name,
                self_uj / 1_000_000.0,
                safe_divide(self_uj * 100, process_energy_uj),
                inclusive_uj / 1_000_000.0,
                safe_divide(inclusive_uj * 100, process_energy_uj),
                st_s,
                avg_st_ms,
                it_s,
                avg_it_ms,
            ])

    host_j = host_energy_uj / 1_000_000.0
    process_j = process_energy_uj / 1_000_000.0
    host_dynamic_j = dynamic_host_uj / 1_000_000.0
    process_dynamic_j = dynamic_process_uj / 1_000_000.0

    summary = {
        "measurement_window": {
            "start_timestamp": start,
            "end_timestamp": end,
            "duration_seconds": duration,
            "target_pid": target_pid,
            "language": language,
        },
        "workload": k6,
        "energy": {
            "host_total_j": host_j,
            "host_dynamic_j": host_dynamic_j,
            "process_total_j": process_j,
            "process_dynamic_j": process_dynamic_j,
            "host_average_power_w": host_j / duration,
            "process_average_power_w": process_j / duration,
            "baseline_host_average_power_w": baseline_host_uw / 1_000_000.0,
            "baseline_process_average_power_w": baseline_process_uw / 1_000_000.0,
            "process_attribution_unattributed_j": unattributed_uj / 1_000_000.0,
            "process_attribution_unattributed_percent": safe_divide(
                unattributed_uj * 100,
                process_energy_uj,
            ),
            "host_j_per_successful_request": safe_divide(host_j, successful),
            "host_dynamic_j_per_successful_request": safe_divide(
                host_dynamic_j,
                successful,
            ),
            "process_j_per_successful_request": safe_divide(process_j, successful),
            "process_dynamic_j_per_successful_request": safe_divide(
                process_dynamic_j,
                successful,
            ),
        },
        "carbon": {
            "intensity_g_co2e_per_kwh": intensity,
            "host_total_g_co2e": carbon_g(host_j, intensity),
            "host_dynamic_g_co2e": carbon_g(host_dynamic_j, intensity),
            "process_total_g_co2e": carbon_g(process_j, intensity),
            "process_dynamic_g_co2e": carbon_g(process_dynamic_j, intensity),
            "host_total_g_co2e_per_1000_successful_requests": safe_divide(
                carbon_g(host_j, intensity) * 1000,
                successful,
            ),
            "process_total_g_co2e_per_1000_successful_requests": safe_divide(
                carbon_g(process_j, intensity) * 1000,
                successful,
            ),
        },
        "profiling": {
            "samples_in_file": len(samples),
            "application_prefix": args.application_prefix,
            "energy_stacks": len(energy_stacks),
            "cpu_stacks": len(cpu_stacks),
            "energy_flamegraph": "energy-flamegraph.svg",
            "cpu_flamegraph": "cpu-flamegraph.svg",
            "top_functions": "top-functions.csv",
            "function_times": "function-times.csv",
        },
        "function_times": function_times_list,
        "interpretation_notes": [
            "Process power is attributed using hardware power and process CPU time.",
            "The energy flamegraph correlates process-power intervals with stack samples.",
            "Host energy includes every process active during the measurement.",
            "Carbon values are estimated operational emissions.",
        ],
    }

    (output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )

    top_rows = []
    with top_csv.open(encoding="utf-8") as handle:
        for index, row in enumerate(csv.DictReader(handle)):
            if index >= 10:
                break
            top_rows.append(row)

    process_per_request = safe_divide(process_j, successful) or 0.0
    lines = [
        "# Measurement summary",
        "",
        f"- Duration: **{duration:.3f} s**",
        f"- Successful requests: **{successful}**",
        f"- Host total energy: **{host_j:.6f} J**",
        f"- Host dynamic energy: **{host_dynamic_j:.6f} J**",
        f"- {language} process total energy: **{process_j:.6f} J**",
        f"- {language} process dynamic energy: **{process_dynamic_j:.6f} J**",
        f"- {language} energy/request: **{process_per_request:.9f} J/request**",
        f"- Estimated {language} emissions: **{carbon_g(process_j, intensity):.12f} gCO2e**",
        f"- Unattributed {language} energy: **{unattributed_uj / 1_000_000:.6f} J**",
    ]

    if args.application_prefix:
        lines.append(
            f"- Note: results filtered to functions matching `{args.application_prefix}`; "
            "framework/infrastructure functions were excluded from the tables below."
        )

    lines.extend([
        "",
        "## Top sampled self-energy functions",
        "",
        "| Function | Self energy (J) | Inclusive energy (J) |",
        "|---|---:|---:|",
    ])

    for row in top_rows:
        lines.append(
            f"| `{row['function']}` | "
            f"{float(row['self_energy_j']):.6f} | "
            f"{float(row['inclusive_energy_j']):.6f} |"
        )

    lines.extend([
        "",
        "## Function execution times (Tempo de Execução por Função)",
        "",
        "| Function | Total time (s) | Average time (ms/req) | Self time (s) | Inclusive time (s) |",
        "|---|---:|---:|---:|---:|",
    ])

    for ft in function_times_list[:15]:
        lines.append(
            f"| `{ft['function']}` | "
            f"{ft['total_time_s']:.6f} | "
            f"{ft['avg_time_ms']:.3f} | "
            f"{ft['self_time_s']:.6f} | "
            f"{ft['inclusive_time_s']:.6f} |"
        )

    lines.extend([
        "",
        "Open `energy-flamegraph.svg` for energy-attributed stacks.",
        "Open `cpu-flamegraph.svg` for ordinary sampled execution hotspots.",
        "Open `function-times.csv` for the complete table of function times.",
        "",
    ])

    (output_dir / "SUMMARY.md").write_text(
        "\n".join(lines),
        encoding="utf-8",
    )

    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
