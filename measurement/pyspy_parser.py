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
    # raw_stacks: (pid, tid) -> list of raw frame names for matching
    raw_stacks: dict[tuple[int, int], list[str]] = {}
    qualified_stacks: dict[tuple[int, int], list[str]] = {}
    frozen_stacks: dict[tuple[int, int], tuple[str, ...]] = {}
    segment_starts: dict[tuple[int, int], float] = {}
    samples: list[StackSample] = []

    def emit_segment(key: tuple[int, int], end_ts: float) -> None:
        frozen = frozen_stacks.get(key)
        begin_ts = segment_starts.get(key)
        if not frozen or begin_ts is None:
            return
        pid = key[0]
        t = begin_ts
        while t < end_ts:
            samples.append(
                StackSample(start_time + t / 1_000_000.0, pid, frozen)
            )
            t += tick_us

    # py-spy generates events in chronological stream
    for event in events:
        phase = event.get("ph")
        if phase not in ("B", "E"):
            continue

        default_pid = target_pid if target_pid is not None else 0
        key = (int(event.get("pid", default_pid)), int(event.get("tid", 0)))
        ts = float(event.get("ts", 0))

        emit_segment(key, ts)
        segment_starts[key] = ts

        r_stack = raw_stacks.setdefault(key, [])
        q_stack = qualified_stacks.setdefault(key, [])
        name = event.get("name", "")

        if phase == "B":
            filename = event.get("args", {}).get("filename")
            qualified = qualify_frame_name(name, filename, project_root)
            r_stack.append(name)
            q_stack.append(qualified)
            frozen_stacks[key] = tuple(q_stack)
        else:
            if not r_stack:
                continue
            # Search from top of stack downwards for the matching frame name
            found_idx = -1
            for i in range(len(r_stack) - 1, -1, -1):
                if r_stack[i] == name:
                    found_idx = i
                    break
            if found_idx != -1:
                del r_stack[found_idx:]
                del q_stack[found_idx:]
            else:
                r_stack.pop()
                q_stack.pop()
            frozen_stacks[key] = tuple(q_stack)

    # Frames still open at end of file (interrupted recording) have no
    # known end time; their trailing segment is dropped, not guessed.
    return sorted(samples, key=lambda sample: sample.timestamp)
