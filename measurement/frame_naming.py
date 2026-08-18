from pathlib import Path


def qualify_frame_name(
    name: str,
    filename: str | None,
    project_root: Path | None,
) -> str:
    """Prefix a bare frame name with its dotted path, relative to
    project_root — e.g. 'get_response' becomes 'bakerydemo.core.get_response'
    when the file lives inside the project. Frames outside project_root
    (stdlib/vendor, or no project_root given) keep the bare name, which
    naturally won't match any application-prefix filter.
    """
    if filename is None or project_root is None:
        return name
    try:
        rel = Path(filename).resolve().relative_to(project_root.resolve())
    except ValueError:
        return name
    module = ".".join(rel.with_suffix("").parts)
    return f"{module}.{name}" if module else name
