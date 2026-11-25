"""Meaningful path-migration failures for prj_zl's read-only checker."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "prj_zl/scripts/check_keil_paths.py"
SPEC = importlib.util.spec_from_file_location("check_keil_paths", SCRIPT)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class KeilPaths(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "app/src").mkdir(parents=True)
        (self.root / "app/inc").mkdir()
        (self.root / "Project/MDK").mkdir(parents=True)
        (self.root / "app/src/main.c").write_text("int main(void) { return 0; }\n")
        (self.root / "app/inc/Var.h").write_text("/* fixture */\n")
        self.project = self.root / "Project/MDK/app.uvprojx"

    def put(self, content):
        self.project.write_text(content)
        return CHECKER.inspect_projects([self.project])

    def target(self, name="App", paths=None):
        paths = paths or [r"..\..\app\src\main.c"]
        return "<Target><TargetName>" + name + "</TargetName><IncludePath>..\\..\\app\\inc</IncludePath><Groups>" + "".join("<File><FilePath>" + p + "</FilePath></File>" for p in paths) + "</Groups></Target>"

    def test_same_source_in_distinct_targets_is_valid_and_read_only(self):
        report, code = self.put("<Project><Targets>" + self.target() + self.target("Boot") + "</Targets></Project>")
        before = self.project.read_bytes()
        self.assertEqual(code, 0)
        self.assertEqual(len(report["projects"][0]["paths"]), 4)
        CHECKER.inspect_projects([self.project])
        self.assertEqual(self.project.read_bytes(), before)

    def test_missing_file_is_not_hidden_by_valid_include(self):
        report, code = self.put("<Project>" + self.target(paths=[r"..\..\driver\src\pwm.c"]) + "</Project>")
        self.assertEqual(code, 2)
        self.assertIn("missing", [p["status"] for p in report["projects"][0]["paths"]])

    def test_wrong_case_finds_existing_spelling(self):
        report, code = self.put("<Project><FilePath>../../app/inc/var.h</FilePath></Project>")
        self.assertEqual(code, 2)
        row = report["projects"][0]["paths"][0]
        self.assertEqual(row["status"], "case_mismatch")
        self.assertTrue(row["existing_spelling"].endswith("Var.h"))

    def test_case_spelling_survives_canonical_resolution(self):
        original_resolve = Path.resolve

        def canonicalize(path, *args, **kwargs):
            # Model a filesystem resolver that returns the stored spelling,
            # as Windows can do. This is not a native Windows execution.
            if path.name == "var.h":
                path = path.with_name("Var.h")
            return original_resolve(path, *args, **kwargs)

        with mock.patch.object(Path, "resolve", canonicalize):
            report, code = self.put("<Project><FilePath>../../app/inc/var.h</FilePath></Project>")
        self.assertEqual(code, 2)
        row = report["projects"][0]["paths"][0]
        self.assertEqual(row["status"], "case_mismatch")
        self.assertTrue(row["existing_spelling"].endswith("Var.h"))

    def test_duplicate_normalized_source_in_one_target_is_reported(self):
        report, code = self.put("<Project>" + self.target(paths=["../../app/src/main.c", "../../app/src/./main.c"]) + "</Project>")
        self.assertEqual(code, 2)
        self.assertEqual(len(report["projects"][0]["duplicates"]), 1)

    def test_dynamic_references_need_review_not_pass_or_missing(self):
        report, code = self.put("<Project><IncludePath>$(DevicePack)/Include;%SDK_ROOT%/inc</IncludePath></Project>")
        self.assertEqual(code, 3)
        self.assertEqual(report["manual_count"], 2)
        self.assertEqual(report["issue_count"], 0)

    @unittest.skipIf(sys.platform == "win32", "Windows can resolve native drives")
    def test_windows_absolute_path_is_manual_on_posix(self):
        report, code = self.put(r"<Project><IncludePath>C:\SDK\Include;\\server\sdk\inc</IncludePath></Project>")
        self.assertEqual(code, 3)
        self.assertEqual(report["manual_count"], 2)

    def test_namespace_and_uvoptx_paths_do_not_require_output_to_exist(self):
        report, code = self.put('<Project xmlns="urn:fixture"><PathWithFileName>../../app/src/main.c</PathWithFileName><OutputDirectory>Objects/</OutputDirectory><ListingPath>List/</ListingPath></Project>')
        self.assertEqual(code, 0)
        self.assertEqual(len(report["projects"][0]["paths"]), 1)
        self.assertFalse((self.project.parent / "Objects").exists())

    def test_empty_or_unrelated_xml_cannot_claim_path_pass(self):
        for xml, expected in [("<Project />", 3), ("<Unrelated />", 2)]:
            with self.subTest(xml=xml):
                report, code = self.put(xml)
                self.assertEqual(code, expected)
                self.assertNotEqual(report["status"], "LITERAL_PATHS_PASS")

    def test_cli_exit_codes_and_json(self):
        for xml, expected in [("<Project>" + self.target() + "</Project>", 0),
                              ("<Project><FilePath>missing.c</FilePath></Project>", 2),
                              ("<Project><IncludePath>$(PACK)</IncludePath></Project>", 3),
                              ("<Project>", 2)]:
            with self.subTest(expected=expected, xml=xml):
                self.project.write_text(xml)
                run = subprocess.run([sys.executable, str(SCRIPT), str(self.project)], text=True, capture_output=True)
                self.assertEqual(run.returncode, expected, run.stderr)
                self.assertIn("status", json.loads(run.stdout))


if __name__ == "__main__":
    unittest.main()
