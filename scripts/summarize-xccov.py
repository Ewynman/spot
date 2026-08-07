#!/usr/bin/env python3
"""Summarize xccov data for Spot's production coverage boundary."""

import importlib.util
import json
import sys
from pathlib import Path


def _load_coverage_scope():
    script_dir = Path(__file__).resolve().parent
    scope_path = script_dir / "coverage_scope.py"
    spec = importlib.util.spec_from_file_location("coverage_scope", scope_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


coverage_scope = _load_coverage_scope()

APP_TARGET_NAMES = ("Spot.app", "Spot")


def summarize(report: dict) -> dict:
    targets = report.get("targets", [])
    target = next(
        (
            candidate
            for name in APP_TARGET_NAMES
            for candidate in targets
            if candidate.get("name") == name
        ),
        None,
    )
    if target is None:
        raise ValueError(
            f"Spot app target not found (expected one of: {', '.join(APP_TARGET_NAMES)})"
        )

    covered_lines = 0
    executable_lines = 0
    file_count = 0

    for file_report in target.get("files", []):
        path = file_report.get("path", "")
        if not coverage_scope.is_in_coverage_scope(path):
            continue

        executable = int(file_report.get("executableLines", 0))
        covered = int(file_report.get("coveredLines", 0))
        if executable <= 0:
            continue

        executable_lines += executable
        covered_lines += covered
        file_count += 1

    if executable_lines == 0:
        raise ValueError("Spot app target has no executable lines in the production scope")

    return {
        "percent": round(covered_lines * 100 / executable_lines, 1),
        "coveredLines": covered_lines,
        "executableLines": executable_lines,
        "fileCount": file_count,
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <xccov-report.json>", file=sys.stderr)
        return 2

    try:
        with open(sys.argv[1], encoding="utf-8") as report_file:
            summary = summarize(json.load(report_file))
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
        print(f"Unable to summarize coverage: {error}", file=sys.stderr)
        return 1

    print(json.dumps(summary, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
