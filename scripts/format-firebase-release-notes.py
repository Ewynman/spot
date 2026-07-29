#!/usr/bin/env python3
"""Convert a pull request body into concise Firebase release-note text."""

from __future__ import annotations

import argparse
import html
import re
import sys


CHANGES_HEADINGS = {"change", "changes", "summary", "what changed", "what's changed"}


def _changes_section(markdown: str) -> str:
    """Prefer the PR's changes section and omit testing/checklist boilerplate."""
    lines = markdown.splitlines()
    start: int | None = None
    level: int | None = None

    for index, line in enumerate(lines):
        match = re.match(r"^\s*(#{1,6})\s+(.+?)\s*#*\s*$", line)
        if not match:
            continue

        heading = re.sub(r"[*_`]", "", match.group(2)).strip().casefold()
        if start is None and heading in CHANGES_HEADINGS:
            start = index + 1
            level = len(match.group(1))
            continue

        if start is not None and len(match.group(1)) <= level:
            return "\n".join(lines[start:index])

    if start is not None:
        return "\n".join(lines[start:])
    return markdown


def _plain_text(markdown: str) -> str:
    text = re.sub(r"<!--.*?-->", "", markdown, flags=re.DOTALL)
    text = _changes_section(text)

    # Remove non-release metadata commonly appended by automation.
    text = re.sub(r"<(?:div|picture)\b.*?</(?:div|picture)>", "", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)

    # Keep link labels, but discard image/link destinations and Markdown decoration.
    text = re.sub(r"!\[([^\]]*)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"^[ \t]*#{1,6}[ \t]+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*[-*+][ \t]+\[[ xX]\][ \t]+", "• ", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*[-*+][ \t]+", "• ", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*\d+[.)][ \t]+", "• ", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*>[ \t]?", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*```[^\n]*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"[*_~`]", "", text)
    text = html.unescape(text)

    lines = [re.sub(r"[ \t]+", " ", line).strip() for line in text.splitlines()]
    compact: list[str] = []
    for line in lines:
        if line or (compact and compact[-1]):
            compact.append(line)
    return "\n".join(compact).strip()


def format_release_notes(markdown: str, max_characters: int = 1200) -> str:
    """Return clean plain text, truncated at a line boundary when possible."""
    plain = _plain_text(markdown)
    if len(plain) <= max_characters:
        return plain

    truncated = plain[: max_characters - 1].rstrip()
    last_break = truncated.rfind("\n")
    if last_break >= max_characters // 2:
        truncated = truncated[:last_break].rstrip()
    return f"{truncated}…"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-characters", type=int, default=1200)
    args = parser.parse_args()
    if args.max_characters < 2:
        parser.error("--max-characters must be at least 2")

    formatted = format_release_notes(sys.stdin.read(), args.max_characters)
    if formatted:
        print(formatted)


if __name__ == "__main__":
    main()
