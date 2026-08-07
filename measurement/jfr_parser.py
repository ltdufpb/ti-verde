import json
import subprocess
from datetime import datetime
from pathlib import Path

from analyze_measurement import StackSample


def parse_jfr(path: Path, target_pid: int) -> list[StackSample]:
    """Parse a .jfr file into StackSample objects"""
    command = [
        "jfr",
        "print",
        "--json",
        "--events", "jdk.ExecutionSample",
        "--stack-depth", "64",
        str(path),
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)

    samples = []
    for event in data["recording"]["events"]:
        raw_time = event["values"]["startTime"]
        dt = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
        timestamp = dt.timestamp()

        frames = event["values"]["stackTrace"]["frames"]
        stack = tuple(
            f"{frame['method']['type']['name']}.{frame['method']['name']}"
            for frame in frames
        )

        samples.append(StackSample(timestamp, target_pid, stack))

    return sorted(samples, key=lambda sample: sample.timestamp)
