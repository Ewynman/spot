import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "summarize-xccov.py"
SPEC = importlib.util.spec_from_file_location("summarize_xccov", SCRIPT_PATH)
summarize_xccov = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(summarize_xccov)


class SummarizeXccovTests(unittest.TestCase):
    def test_summarizes_production_scope_including_views_excluding_logs(self):
        report = {
            "targets": [
                {
                    "name": "FirebaseAuth",
                    "files": [
                        {
                            "path": "/SourcePackages/Firebase/Auth.swift",
                            "coveredLines": 0,
                            "executableLines": 1000,
                        }
                    ],
                },
                {
                    "name": "Spot.app",
                    "files": [
                        {
                            "path": "/runner/repo/Spot/Services/AuthService.swift",
                            "coveredLines": 75,
                            "executableLines": 100,
                        },
                        {
                            "path": "/runner/repo/Spot/Models/User.swift",
                            "coveredLines": 15,
                            "executableLines": 20,
                        },
                        {
                            "path": "/runner/repo/Spot/Views/Home/HomeView.swift",
                            "coveredLines": 30,
                            "executableLines": 100,
                        },
                        {
                            "path": "/runner/repo/Spot/Models/Logs/AuthViewModelLogs.swift",
                            "coveredLines": 0,
                            "executableLines": 50,
                        },
                    ],
                },
                {
                    "name": "SpotTests.xctest",
                    "files": [
                        {
                            "path": "/runner/repo/SpotTests/AuthServiceTests.swift",
                            "coveredLines": 50,
                            "executableLines": 50,
                        }
                    ],
                },
            ]
        }

        # 75+15+30 = 120 covered / 100+20+100 = 220 executable = 54.5%
        self.assertEqual(
            summarize_xccov.summarize(report),
            {
                "percent": 54.5,
                "coveredLines": 120,
                "executableLines": 220,
                "fileCount": 3,
            },
        )

    def test_accepts_target_name_without_app_suffix(self):
        report = {
            "targets": [
                {
                    "name": "Spot",
                    "files": [
                        {
                            "path": "Spot/Utils/Validator.swift",
                            "coveredLines": 2,
                            "executableLines": 3,
                        }
                    ],
                }
            ]
        }

        self.assertEqual(summarize_xccov.summarize(report)["percent"], 66.7)

    def test_rejects_report_without_spot_app_target(self):
        with self.assertRaisesRegex(ValueError, "Spot app target not found"):
            summarize_xccov.summarize({"targets": [{"name": "SpotTests.xctest"}]})

    def test_rejects_empty_production_scope(self):
        report = {
            "targets": [
                {
                    "name": "Spot.app",
                    "files": [
                        {
                            "path": "/runner/repo/Spot/Models/Logs/HomeViewLogs.swift",
                            "coveredLines": 1,
                            "executableLines": 1,
                        }
                    ],
                }
            ]
        }

        with self.assertRaisesRegex(ValueError, "no executable lines"):
            summarize_xccov.summarize(report)

    def test_format_markdown_includes_percent(self):
        md = summarize_xccov.format_markdown(
            {
                "percent": 54.5,
                "coveredLines": 120,
                "executableLines": 220,
                "fileCount": 3,
            },
            title="Unit coverage",
        )
        self.assertIn("# Unit coverage", md)
        self.assertIn("54.5%", md)
        self.assertIn("120", md)


if __name__ == "__main__":
    unittest.main()
