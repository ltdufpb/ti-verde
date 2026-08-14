import json
import sys
from pathlib import Path

from analyze_measurement import StackSample
from frame_naming import qualify_frame_name


def parse_pyspy(
    path: Path,
    target_pid: int,
    start_time: float,
    sample_rate_hz: float = 100.0,
    project_root: Path | None = None,
) -> list[StackSample]:
    """Parse a py-spy chrometrace file into StackSample objects"""
    with open(path) as file:
        events = json.load(file)

    tick_us = 1_000_000.0 / sample_rate_hz
    stacks: dict[tuple[int, int], list[tuple[str, str]]] = {}
    segment_starts: dict[tuple[int, int], float] = {}
    samples: list[StackSample] = []

    def emit_segment(key: tuple[int, int], end_ts: float) -> None:
        stack = stacks.get(key)
        begin_ts = segment_starts.get(key)
        if not stack or begin_ts is None:
            return
        frozen = tuple(qualified for _, qualified in stack)
        pid = key[0]
        t = begin_ts
        while t < end_ts:
            samples.append(
                StackSample(start_time + t / 1_000_000.0, pid, frozen)
            )
            t += tick_us

    # Stable sort: preserves file order for same-ts events, which is
    # what keeps push/pop ordering correct within a burst.
    for event in sorted(events, key=lambda e: e["ts"]):
        phase = event.get("ph")
        if phase not in ("B", "E"):
            continue

        key = (int(event.get("pid", target_pid)), int(event["tid"]))
        ts = float(event["ts"])

        emit_segment(key, ts)
        segment_starts[key] = ts

        stack = stacks.setdefault(key, [])
        if phase == "B":
            filename = event.get("args", {}).get("filename")
            qualified = qualify_frame_name(event["name"], filename, project_root)
            stack.append((event["name"], qualified))
        else:
            if not stack:
                print(
                    f"WARNING: 'E' event without open frame at ts={ts}",
                    file=sys.stderr,
                )
                continue
            popped_name, _ = stack.pop()
            if popped_name != event["name"]:
                print(
                    "WARNING: frame mismatch on close: "
                    f"expected {popped_name!r}, got {event['name']!r}",
                    file=sys.stderr,
                )

    # Frames still open at end of file (interrupted recording) have no
    # known end time; their trailing segment is dropped, not guessed.
    return sorted(samples, key=lambda sample: sample.timestamp)
