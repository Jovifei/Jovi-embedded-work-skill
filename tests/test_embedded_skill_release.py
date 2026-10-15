"""Validate release metadata/resources; behavior is evaluated separately by agents.

Run with Python UTF-8 mode. PyYAML is also used by skill-creator's validator.
The established underscore command names are intentional compatibility names.
"""
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
SKILLS = ("code_zl", "code_sc", "code_wrt")
OFFICIAL = Path.home() / ".codex/skills/.system/skill-creator/scripts/quick_validate.py"


def read_skill(name):
    text = (ROOT / name / "SKILL.md").read_text(encoding="utf-8-sig")
    match = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.S)
    if not match:
        raise ValueError(f"{name}: missing YAML frontmatter")
    metadata = yaml.safe_load(match.group(1))
    version = re.search(r"^\*\*Version:\s*(V\d+\.\d+\.\d+)\*\*", text, re.M)
    if not version:
        raise ValueError(f"{name}: missing release version")
    return text, metadata, version.group(1)


def prose_without_fences(text):
    result = []
    marker = None
    for line in text.splitlines():
        fence = re.match(r"\s*(`{3,}|~{3,})", line)
        if fence:
            current = fence.group(1)[0]
            marker = None if marker == current else current
        elif marker is None:
            result.append(line)
    return "\n".join(result)


class EmbeddedSkillRelease(unittest.TestCase):
    def test_frontmatter_and_command_compatibility(self):
        for name in SKILLS:
            with self.subTest(skill=name):
                text, metadata, _ = read_skill(name)
                self.assertIsInstance(metadata, dict)
                self.assertEqual(metadata["name"], name)
                self.assertIsInstance(metadata["description"], str)
                self.assertTrue(metadata["description"].strip())
                self.assertLessEqual(len(metadata["description"]), 1024)
                self.assertNotIn("\ufffd", text)

    def test_evaluation_versions_and_unique_scenarios(self):
        for name in SKILLS:
            with self.subTest(skill=name):
                _, _, version = read_skill(name)
                data = json.loads((ROOT / name / "evals/evals.json").read_text(encoding="utf-8-sig"))
                self.assertEqual(data["skill_name"], name)
                self.assertEqual(data["version"], version)
                cases = data["evals"]
                self.assertTrue(cases)
                ids = [case["id"] for case in cases]
                self.assertEqual(len(ids), len(set(ids)))
                for case in cases:
                    self.assertTrue(case["prompt"].strip())
                    self.assertTrue(case["expected_behavior"].strip())

    def test_readme_current_tables_and_changelog(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8-sig")
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8-sig")
        for name in SKILLS:
            with self.subTest(skill=name):
                _, _, version = read_skill(name)
                matches = re.findall(r"^\|\s*`" + re.escape(name) + r"`\s*\|\s*\*\*(V[\d.]+)\*\*", readme, re.M)
                self.assertGreaterEqual(len(matches), 2)
                self.assertEqual(set(matches), {version})
                tree = next(line for line in readme.splitlines() if re.search(r"[├└]── " + re.escape(name) + r"/", line))
                self.assertIn(version, tree)
                releases = re.findall(r"^\|\s*" + re.escape(name) + r"\s*\|[^\n]+", changelog, re.M)
                self.assertTrue(releases)
                self.assertIn(f"**{version}**", releases[0])

    def test_packaged_resources_and_links(self):
        for name in SKILLS:
            for path in (ROOT / name).rglob("*.md"):
                text = path.read_text(encoding="utf-8-sig")
                with self.subTest(path=path.relative_to(ROOT)):
                    self.assertNotIn("\ufffd", text)
                    for target in re.findall(r"\[[^\]\n]*\]\(([^)\n]+)\)", prose_without_fences(text)):
                        target = target.strip("<>").split("#", 1)[0]
                        if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                            continue
                        self.assertTrue((path.parent / target).is_file(), f"{path}: missing {target}")
            for path in (ROOT / name).rglob("*.json"):
                with self.subTest(path=path.relative_to(ROOT)):
                    json.loads(path.read_text(encoding="utf-8-sig"))

    @unittest.skipUnless(OFFICIAL.is_file(), "optional installed skill-creator validator unavailable")
    def test_official_other_rules_with_explicit_legacy_name_projection(self):
        spec = importlib.util.spec_from_file_location("skill_creator_validation", OFFICIAL)
        validator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(validator)
        for name in SKILLS:
            with self.subTest(skill=name):
                valid, message = validator.validate_skill(ROOT / name)
                self.assertFalse(valid)
                self.assertIn("hyphen-case", message)
                text, _, _ = read_skill(name)
                projected, count = re.subn(r"(?m)^name:\s*" + re.escape(name) + r"\s*$", "name: " + name.replace("_", "-"), text, count=1)
                self.assertEqual(count, 1)
                with tempfile.TemporaryDirectory(prefix="embedded-skill-validator-") as directory:
                    (Path(directory) / "SKILL.md").write_text(projected, encoding="utf-8")
                    accepted, other_message = validator.validate_skill(directory)
                    self.assertTrue(accepted, other_message)


if __name__ == "__main__":
    unittest.main()
