import json
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

from analyze_measurement import StackSample


def parse_jfr(path: Path, target_pid: int | None = None) -> list[StackSample]:
    """Parse a .jfr file into StackSample objects"""
    if shutil.which("jfr"):
        command = [
            "jfr",
            "print",
            "--json",
            "--events", "jdk.ExecutionSample",
            "--stack-depth", "64",
            str(path),
        ]
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        raw_json = result.stdout
    else:
        # Fallback: executa o jfr de dentro do container Docker se não estiver no host
        out = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True,
            text=True,
            check=True,
        )
        containers = [c.strip() for c in out.stdout.splitlines() if c.strip()]
        container = None
        for c in containers:
            check_jfr = subprocess.run(
                ["docker", "exec", c, "sh", "-c", "command -v jfr"],
                capture_output=True,
            )
            if check_jfr.returncode == 0:
                container = c
                break

        if not container:
            raise RuntimeError(
                "Comando 'jfr' não foi encontrado no PATH do host nem em containers Docker ativos."
            )

        container_tmp = f"/tmp/.jfr-parse-{path.name}"
        subprocess.run(["docker", "cp", str(path), f"{container}:{container_tmp}"], check=True)
        try:
            command = [
                "docker",
                "exec",
                container,
                "jfr",
                "print",
                "--json",
                "--events", "jdk.ExecutionSample",
                "--stack-depth", "64",
                container_tmp,
            ]
            result = subprocess.run(
                command, check=True, capture_output=True, text=True
            )
            raw_json = result.stdout
        finally:
            subprocess.run(
                ["docker", "exec", container, "rm", "-f", container_tmp],
                capture_output=True,
            )

    data = json.loads(raw_json)

    samples = []
    pid_val = target_pid if target_pid is not None else 0
    events = data.get("recording", {}).get("events", []) if isinstance(data, dict) else []
    for event in events:
        raw_time = event.get("values", {}).get("startTime")
        if not raw_time:
            continue
        dt = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
        timestamp = dt.timestamp()

        frames = event.get("values", {}).get("stackTrace", {}).get("frames", [])
        stack = tuple(
            f"{frame['method']['type']['name']}.{frame['method']['name']}"
            for frame in reversed(frames)
            if "method" in frame and "type" in frame["method"]
        )
        if stack:
            samples.append(StackSample(timestamp, pid_val, stack))

    return sorted(samples, key=lambda sample: sample.timestamp)
