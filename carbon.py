#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--energy-j", type=float, required=True)
    parser.add_argument("--carbon-intensity", type=float, required=True)
    parser.add_argument("--requests", type=int)
    args = parser.parse_args()

    if args.energy_j < 0 or args.carbon_intensity < 0:
        parser.error("Energy and carbon intensity must be non-negative.")
    if args.requests is not None and args.requests <= 0:
        parser.error("Requests must be greater than zero.")

    energy_kwh = args.energy_j / 3_600_000
    emissions = energy_kwh * args.carbon_intensity

    result = {
        "energy_joules": args.energy_j,
        "energy_kwh": energy_kwh,
        "carbon_intensity_g_per_kwh": args.carbon_intensity,
        "emissions_g_co2e": emissions,
        "requests": args.requests,
        "energy_j_per_request": (
            args.energy_j / args.requests if args.requests else None
        ),
        "emissions_g_per_1000_requests": (
            emissions / args.requests * 1000 if args.requests else None
        ),
    }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
