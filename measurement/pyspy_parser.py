import json
from pathlib import Path

from analyze_measurement import StackSample


def parse_pyspy(path: Path, target_pid: int, start_time: float) -> list[StackSample]:
    """Parse a py-spy speedscope file into StackSample objects"""
    with open(path) as file:
        data = json.load(file)

    profile = data["profiles"][0]
    frames = data["shared"]["frames"]

    samples = []
    elapsed_time = 0.0
    for stack_indices, weight in zip(profile["samples"], profile["weights"]):
        timestamp = start_time + elapsed_time
        stack = tuple(frames[i]["name"] for i in stack_indices)
        samples.append(StackSample(timestamp, target_pid, stack))
        elapsed_time += weight

    return sorted(samples, key=lambda sample: sample.timestamp)
