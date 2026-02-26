import subprocess
from codecarbon import EmissionsTracker

NUM_USERS = 50
SPAWN_RATE = 5         
DURATION = "3m"
HOST = "http://localhost:8000"

tracker = EmissionsTracker(
    project_name="school-management-baseline",
    output_dir=".",
    output_file="emissions_baseline.csv"
)

tracker.start()
locust_process = subprocess.Popen([
    "locust",
    "-f", "locustfile.py",
    "--headless",
    "--users", str(NUM_USERS),
    "--spawn-rate", str(SPAWN_RATE),
    "--run-time", DURATION,
    "--host", HOST,
    "--csv", "baseline_results"
])

locust_process.wait()
emissions = tracker.stop()
