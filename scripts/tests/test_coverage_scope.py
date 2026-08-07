#!/usr/bin/env python3
"""Unit tests for scripts/coverage_scope.py."""

import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "coverage_scope.py"
SPEC = importlib.util.spec_from_file_location("coverage_scope", SCRIPT_PATH)
coverage_scope = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(coverage_scope)


class CoverageScopeTests(unittest.TestCase):
    def test_includes_views_in_informational_scope(self):
        self.assertTrue(
            coverage_scope.is_in_coverage_scope(
                "/runner/repo/Spot/Views/Home/MapView.swift"
            )
        )

    def test_excludes_views_from_changed_line_enforcement(self):
        self.assertFalse(
            coverage_scope.is_in_changed_line_enforcement_scope(
                "/runner/repo/Spot/Views/Home/MapView.swift"
            )
        )

    def test_includes_services(self):
        self.assertTrue(
            coverage_scope.is_in_coverage_scope(
                "/runner/repo/Spot/Services/Auth/AuthViewModel.swift"
            )
        )
        self.assertTrue(
            coverage_scope.is_in_changed_line_enforcement_scope(
                "/runner/repo/Spot/Services/Auth/AuthViewModel.swift"
            )
        )

    def test_excludes_models_logs(self):
        self.assertFalse(
            coverage_scope.is_in_coverage_scope(
                "/runner/repo/Spot/Models/Logs/AuthViewModelLogs.swift"
            )
        )

    def test_excludes_tests(self):
        self.assertFalse(
            coverage_scope.is_in_coverage_scope(
                "/runner/repo/SpotTests/Services/Auth/AuthViewModelTests.swift"
            )
        )
        self.assertFalse(
            coverage_scope.is_in_coverage_scope(
                "/runner/repo/SpotUITests/Authentication/AuthGateUITests.swift"
            )
        )

    def test_excludes_packages(self):
        self.assertFalse(
            coverage_scope.is_in_coverage_scope(
                "/SourcePackages/checkouts/supabase-swift/Sources/Auth.swift"
            )
        )

    def test_repo_relative_spot_path(self):
        self.assertEqual(
            coverage_scope.repo_relative_spot_path(
                "/Volumes/Dev/spot-ios-app/Spot/Utils/GeoHash.swift"
            ),
            "Spot/Utils/GeoHash.swift",
        )
        self.assertIsNone(
            coverage_scope.repo_relative_spot_path(
                "/Volumes/Dev/spot-ios-app/Spot/Models/Logs/GeoHashLogs.swift"
            )
        )

    def test_skips_pure_renames(self):
        status = "\n".join(
            [
                "R100\tSpot/Services/A.swift\tSpot/Services/Auth/A.swift",
                "M\tSpot/Utils/GeoHash.swift",
                "R085\tSpot/Services/Old.swift\tSpot/Services/Core/New.swift",
            ]
        )
        files = coverage_scope.changed_files_from_name_status(
            status, for_enforcement=True
        )
        paths = [path for path, _ in files]
        self.assertNotIn("Spot/Services/Auth/A.swift", paths)
        self.assertIn("Spot/Utils/GeoHash.swift", paths)
        self.assertIn("Spot/Services/Core/New.swift", paths)
        rename = dict(files)["Spot/Services/Core/New.swift"]
        self.assertEqual(rename, "Spot/Services/Old.swift")

    def test_enforcement_skips_view_edits(self):
        status = "M\tSpot/Views/Home/MapView.swift\nM\tSpot/Utils/MapDrawerLayoutPolicy.swift\n"
        files = coverage_scope.changed_files_from_name_status(
            status, for_enforcement=True
        )
        paths = [path for path, _ in files]
        self.assertEqual(paths, ["Spot/Utils/MapDrawerLayoutPolicy.swift"])


if __name__ == "__main__":
    unittest.main()
