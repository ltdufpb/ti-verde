def summarize_by_scope(
    energy_by_function: dict[str, float],
    application_prefixes: tuple[str, ...],
) -> dict[str, float]:
    """Keep only functions matching application_prefixes, discarding the rest"""
    return {
        function: value
        for function, value in energy_by_function.items()
        if function.startswith(application_prefixes)
    }
