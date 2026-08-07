"""Shared Spot production coverage scope rules for CI scripts.

Includes all `Spot/**/*.swift` production sources (including Views).
Excludes log enum files under `Spot/Models/Logs/`, test targets, and
non-Spot paths (package dependencies).
"""

from __future__ import annotations

from pathlib import PurePosixPath


def spot_relative_parts(path: str) -> tuple[str, ...] | None:
    """Return path parts after the `Spot` segment, or None if not under Spot/."""
    parts = PurePosixPath(path).parts
    try:
        spot_index = parts.index("Spot")
    except ValueError:
        return None

    relative = parts[spot_index + 1 :]
    return relative if relative else None


def is_in_coverage_scope(path: str) -> bool:
    """True when xccov should count this file toward Spot production coverage."""
    parts = PurePosixPath(path).parts
    if "SpotTests" in parts or "SpotUITests" in parts:
        return False

    relative = spot_relative_parts(path)
    if relative is None:
        return False

    # Log event enums are declarative and not meaningful for unit coverage.
    if len(relative) >= 2 and relative[0] == "Models" and relative[1] == "Logs":
        return False

    return True


def repo_relative_spot_path(path: str) -> str | None:
    """Return `Spot/...` repo-relative path when `path` is in coverage scope."""
    if not is_in_coverage_scope(path):
        return None
    relative = spot_relative_parts(path)
    if relative is None:
        return None
    return str(PurePosixPath("Spot", *relative))
