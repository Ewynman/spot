#!/usr/bin/env python3

import importlib.util
from pathlib import Path
import unittest


SCRIPT_PATH = Path(__file__).parents[1] / "format-firebase-release-notes.py"
SPEC = importlib.util.spec_from_file_location("firebase_release_notes", SCRIPT_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FormatFirebaseReleaseNotesTests(unittest.TestCase):
    def test_extracts_changes_and_removes_markdown(self) -> None:
        markdown = """\
<!-- CURSOR_AGENT_PR_BODY_BEGIN -->
## Changes
- Add **clean** release notes
- Keep [`useful details`](https://example.com)

## Testing
- [x] Pipeline passed

## Checklist
- [ ] All boilerplate
<!-- CURSOR_AGENT_PR_BODY_END -->
<div><a href="https://example.com">Open in Web</a></div>
"""

        result = MODULE.format_release_notes(markdown)

        self.assertEqual(
            result,
            "• Add clean release notes\n• Keep useful details",
        )
        self.assertNotIn("Testing", result)
        self.assertNotIn("[x]", result)
        self.assertNotIn("**", result)
        self.assertNotIn("Open in Web", result)

    def test_cleans_body_without_changes_heading(self) -> None:
        markdown = """\
Fixes the `drawer` behavior.

1. First item
2. Second item
"""

        self.assertEqual(
            MODULE.format_release_notes(markdown),
            "Fixes the drawer behavior.\n\n• First item\n• Second item",
        )

    def test_truncates_at_a_line_boundary(self) -> None:
        markdown = "## Changes\n- " + ("a" * 30) + "\n- " + ("b" * 30)

        result = MODULE.format_release_notes(markdown, max_characters=40)

        self.assertEqual(result, "• " + ("a" * 30) + "…")
        self.assertLessEqual(len(result), 40)


if __name__ == "__main__":
    unittest.main()
