"""Shared Spot production coverage scope rules for CI scripts.

Includes all `Spot/**/*.swift` production sources (including Views) for
whole-file / informational metrics.

Changed-line enforcement (PR gate) excludes `Spot/Views/**`: SwiftUI `body`
is not executed by SpotTests, so View call-site rewires cannot meet an 80%
unit-test gate. Extract logic into Utils/ViewModels/Services for the gate;
cover View bodies via local SpotUITests when needed.

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


def is_in_changed_line_enforcement_scope(path: str) -> bool:
    """True when changed lines in this file are subject to the 80% PR gate."""
    if not is_in_coverage_scope(path):
        return False
    relative = spot_relative_parts(path)
    if relative is None:
        return False
    # View bodies are not exercised by SpotTests; enforce via extractions logic.
    if relative and relative[0] == "Views":
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


def parse_name_status_line(line: str) -> tuple[str, str, str | None] | None:
    """Parse one `git diff --name-status` line.

    Returns `(status_code, new_path, old_path_or_none)`.
    `status_code` is the leading status without rename similarity (A/M/R/…).
    """
    parts = line.rstrip("\n").split("\t")
    if not parts or not parts[0]:
        return None
    raw_status = parts[0]
    status = raw_status[0]
    if status == "R":
        if len(parts) < 3:
            return None
        return status, parts[2], parts[1]
    if status in {"A", "M", "C", "T"}:
        if len(parts) < 2:
            return None
        return status, parts[1], None
    return None


def rename_similarity(raw_status: str) -> int | None:
    """Return rename similarity percent for `R100`-style statuses."""
    if not raw_status.startswith("R"):
        return None
    digits = raw_status[1:]
    if not digits.isdigit():
        return None
    return int(digits)


def changed_files_from_name_status(
    name_status_text: str,
    *,
    for_enforcement: bool = True,
) -> list[tuple[str, str | None]]:
    """Return `(new_path, old_path_or_none)` entries for coverage analysis.

    Pure renames (`R100`) are omitted — no executable lines changed.
    Partial renames keep `old_path` so callers can `git diff -- old new`.
    """
    scope = (
        is_in_changed_line_enforcement_scope
        if for_enforcement
        else is_in_coverage_scope
    )
    results: list[tuple[str, str | None]] = []
    for line in name_status_text.splitlines():
        parts = line.rstrip("\n").split("\t")
        if not parts or not parts[0]:
            continue
        raw_status = parts[0]
        parsed = parse_name_status_line(line)
        if parsed is None:
            continue
        status, new_path, old_path = parsed
        if status == "R":
            similarity = rename_similarity(raw_status)
            if similarity == 100:
                continue
        if not scope(new_path):
            continue
        results.append((new_path, old_path))
    return results
