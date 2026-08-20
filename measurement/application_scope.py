from pathlib import Path

OVERHEAD_LABEL = "[framework/language overhead]"


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


def truncate_stack_to_scope(
    stack: tuple[str, ...],
    application_prefixes: tuple[str, ...],
) -> tuple[str, ...]:
    """Collapse leading non-app frames of a stack into one overhead label, keeping app frames as-is."""
    app_frames = tuple(
        frame for frame in stack if frame.startswith(application_prefixes)
    )
    if not app_frames:
        return (OVERHEAD_LABEL,)
    if len(app_frames) == len(stack):
        return stack
    return (OVERHEAD_LABEL,) + app_frames


def truncate_stacks_to_scope(
    stacks: dict[tuple[str, ...], float],
    application_prefixes: tuple[str, ...],
) -> dict[tuple[str, ...], float]:
    """Apply truncate_stack_to_scope to every stack, merging ones that collapse to the same result."""
    result: dict[tuple[str, ...], float] = {}
    for stack, value in stacks.items():
        truncated = truncate_stack_to_scope(stack, application_prefixes)
        result[truncated] = result.get(truncated, 0.0) + value
    return result
