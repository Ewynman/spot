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
    def test_includes_views(self):
        self.assertTrue(
            coverage_scope.is_in_coverage_scope(
                "/runner/repo/Spot/Views/Home/MapView.swift"
            )
        )

    def test_includes_services(self):
        self.assertTrue(
            coverage_scope.is_in_coverage_scope(
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


if __name__ == "__main__":
    unittest.main()
