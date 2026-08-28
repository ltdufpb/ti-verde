#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json

# Fatores de Intensidade de Carbono (gCO2e / kWh)
# Fontes: ONS / MCTI (Brasil - Sistema Interligado Nacional) e IEA
CARBON_PRESETS: dict[str, float] = {
    "sin-brasil": 61.7,       # Média anual SIN Brasil
    "brasil": 61.7,
    "sin-nordeste": 45.2,     # Submercado Nordeste (alta penetração eólica/solar)
    "nordeste": 45.2,
    "ufpb": 45.2,             # Campus UFPB / João Pessoa
    "sin-sudeste": 68.4,      # Submercado Sudeste / Centro-Oeste
    "sudeste": 68.4,
    "sin-sul": 63.1,          # Submercado Sul
    "sul": 63.1,
    "sin-norte": 75.0,        # Submercado Norte
    "norte": 75.0,
    "eu-average": 230.0,      # Média União Europeia
    "us-average": 380.0,      # Média Estados Unidos
    "global-average": 475.0,  # Média Global (IEA)
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Calculadora de Emissões de Carbono e Eficiência Energética de Software"
    )
    parser.add_argument("--energy-j", type=float, required=True, help="Energia total em Joules")
    parser.add_argument(
        "--carbon-intensity",
        type=float,
        help="Intensidade de carbono em gCO2e/kWh (opcional se usar --preset)",
    )
    parser.add_argument(
        "--preset",
        type=str,
        choices=list(CARBON_PRESETS.keys()),
        help="Preset geográfico de emissão (ex: sin-nordeste, ufpb, sin-brasil, eu-average)",
    )
    parser.add_argument("--requests", type=int, help="Número de requisições atendidas")
    args = parser.parse_args()

    intensity = args.carbon_intensity
    if args.preset:
        intensity = CARBON_PRESETS[args.preset]
    elif intensity is None:
        # Padrão: SIN Brasil
        intensity = 61.7

    if args.energy_j < 0 or intensity < 0:
        parser.error("Energia e intensidade de carbono devem ser não-negativas.")
    if args.requests is not None and args.requests <= 0:
        parser.error("Requisições devem ser maiores que zero.")

    energy_kwh = args.energy_j / 3_600_000
    emissions = energy_kwh * intensity

    result = {
        "energy_joules": args.energy_j,
        "energy_kwh": energy_kwh,
        "carbon_intensity_g_per_kwh": intensity,
        "preset_used": args.preset if args.preset else "custom/default",
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
