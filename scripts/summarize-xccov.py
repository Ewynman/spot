#!/usr/bin/env python3
"""Summarize xccov data for Spot's production coverage boundary."""

from __future__ import annotations

import argparse
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


def format_markdown(summary: dict, *, title: str) -> str:
    return "\n".join(
        [
            f"# {title}",
            "",
            "| Metric | Value |",
            "| --- | --- |",
            f"| Coverage | {summary['percent']}% |",
            f"| Covered lines | {summary['coveredLines']} |",
            f"| Executable lines | {summary['executableLines']} |",
            f"| Files in scope | {summary['fileCount']} |",
            "",
            "Scope: `Spot/` production Swift including Views; excludes `Models/Logs`, packages, and test targets.",
            "",
        ]
    )


def unavailable_markdown(*, title: str, reason: str) -> str:
    return "\n".join(
        [
            f"# {title}",
            "",
            "Coverage data was **not available** for this run.",
            "",
            f"Reason: {reason}",
            "",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Summarize Spot production-scope coverage from an xccov JSON report."
    )
    parser.add_argument(
        "report_json",
        nargs="?",
        help="Path to xcrun xccov --report --json output",
    )
    parser.add_argument(
        "--write-markdown",
        metavar="PATH",
        help="Also write a human-readable Markdown summary to PATH",
    )
    parser.add_argument(
        "--write-unavailable-markdown",
        metavar="PATH",
        help="Write an unavailable Markdown report to PATH and exit (no JSON input required)",
    )
    parser.add_argument(
        "--reason",
        default="Coverage data was not produced for this run",
        help="Reason text for --write-unavailable-markdown",
    )
    parser.add_argument(
        "--title",
        default="Spot production-scope coverage",
        help="Markdown report title",
    )
    args = parser.parse_args()

    if args.write_unavailable_markdown:
        Path(args.write_unavailable_markdown).write_text(
            unavailable_markdown(title=args.title, reason=args.reason),
            encoding="utf-8",
        )
        print(
            json.dumps(
                {
                    "percent": "unknown",
                    "coveredLines": 0,
                    "executableLines": 0,
                    "fileCount": 0,
                },
                separators=(",", ":"),
            )
        )
        return 0

    if not args.report_json:
        parser.error("report_json is required unless --write-unavailable-markdown is set")

    try:
        with open(args.report_json, encoding="utf-8") as report_file:
            summary = summarize(json.load(report_file))
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
        print(f"Unable to summarize coverage: {error}", file=sys.stderr)
        if args.write_markdown:
            Path(args.write_markdown).write_text(
                unavailable_markdown(title=args.title, reason=str(error)),
                encoding="utf-8",
            )
        return 1

    print(json.dumps(summary, separators=(",", ":")))
    if args.write_markdown:
        Path(args.write_markdown).write_text(
            format_markdown(summary, title=args.title),
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
