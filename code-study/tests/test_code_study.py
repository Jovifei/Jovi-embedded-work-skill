"""Synthetic fixtures only; no product firmware or claims about real hardware."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/code_study.py'
spec = importlib.util.spec_from_file_location('study', SCRIPT); study = importlib.util.module_from_spec(spec); spec.loader.exec_module(study)

class StudyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name); (self.repo / 'src').mkdir()
        self.raw = b'/* original comment */\r\nint task(void) { return 0; }\r\n'
        (self.repo / 'src/control.c').write_bytes(self.raw)
        self.config = self.repo / 'config.json'
        self.config.write_text(json.dumps({'project': 'Synthetic controller', 'book_id': 'fixture-a', 'baseline_label': 'fixture-only', 'include': ['src/**/*.c']}))
        self.book = study.init(self.repo, self.config)
    def complete_structure(self):
        (self.book / 'learning/stage-a').mkdir()
        (self.book / 'learning/README.md').write_text('# 学习入口\n\n[开始](stage-a/start.md)\n', encoding='utf-8')
        (self.book / 'learning/stage-a/start.md').write_text('# 先准备\n\n只属于正文的唯一词：机械释放观察。\n\n![步骤](../../graphs/overview/flow.svg)\n\n|值|说明|\n|---|---|\n|0|暂停|\n\n<details><summary>答案</summary>\n\n这是答案。\n\n</details>\n\n[task](../../functions/task.md)\n\n[源码](../../source_snapshot/src/control.c#L2)\n', encoding='utf-8')
        (self.book / 'modules/control.md').write_text('# 控制模块\n\n[学习](../learning/stage-a/start.md)\n', encoding='utf-8')
        (self.book / 'reference/overview.md').write_text('# 总览\n\n虚构测试，不是产品行为。\n', encoding='utf-8')
        (self.book / 'functions/task.md').write_text('# task\n\n## 1. 完整函数体与原注释\n\n```c\n/* original comment */\nint task(void) { return 0; }\n```\n\n## 5. 代码解释\n\n```c\nreturn 0;\n```\n\n返回零，没有实际硬件动作。\n', encoding='utf-8')
        (self.book / 'graphs/overview/flow.dot').write_text('digraph G { a [label="Prepare"]; b [label="Wait"]; a -> b; }')
        study.render(self.book)
        study.dump_json(self.book / 'verification/inventory.json', {'discovery': {'status': 'MANUAL_FIXTURE'}, 'file_coverage': [{'path': 'src/control.c', 'status': 'read'}]})
        study.dump_json(self.book / 'verification/learning_plan.json', {'chapters': ['learning/stage-a/start.md']})
        study.rebuild_index(self.book)
    def test_globs_match_zero_or_many_directories(self):
        self.assertTrue(study.match('src/root.c', ['src/**/*.c']))
        self.assertTrue(study.match('src/a/b/deep.c', ['src/**/*.c']))
        self.assertFalse(study.match('src/a/deep.c', ['src/*.c']))
        self.assertFalse(study.match('other/file.c', ['src/**/*.c']))
    def test_original_bytes_and_recursive_index(self):
        self.complete_structure()
        self.assertEqual((self.book / 'source_snapshot/src/control.c').read_bytes(), self.raw)
        self.assertTrue(any(e['path'] == 'learning/stage-a/start.md' and '机械释放观察' in e['text'] for e in study.entries(self.book)))
        self.assertEqual(study.check(self.book, self.repo)['result'], 'PASS')
    def test_nested_link_is_checked(self):
        self.complete_structure(); p = self.book / 'learning/stage-a/start.md'; p.write_text(p.read_text() + '\n[missing](absent.md)\n')
        report = study.check(self.book)
        self.assertIn('broken_link', {i['error'] for i in report['issues']})
    def test_check_does_not_mask_stale_index(self):
        self.complete_structure(); old = (self.book / 'assets/search-index.js').read_bytes()
        (self.book / 'learning/stage-a/start.md').write_text('# Changed\n')
        report = study.check(self.book)
        self.assertIn('stale_or_missing_index', {i['error'] for i in report['issues']})
        self.assertEqual((self.book / 'assets/search-index.js').read_bytes(), old)
    def test_reports_do_not_hash_themselves(self):
        self.complete_structure(); before = study.fingerprint(self.book)
        for name in ['browser_validation.json', 'editorial_review.json', 'validation.json', 'completion.json', 'drift.json']:
            study.dump_json(self.book / 'verification' / name, {'different': name})
        self.assertEqual(study.fingerprint(self.book), before)
        (self.book / 'learning/stage-a/start.md').write_text('# Different\n')
        self.assertNotEqual(study.fingerprint(self.book), before)
    def test_source_drift(self):
        self.complete_structure(); (self.repo / 'src/control.c').write_text('changed')
        self.assertEqual(study.drift(self.book, self.repo)['result'], 'DRIFT')
    def test_failed_cli_is_nonzero(self):
        result = subprocess.run([sys.executable, str(SCRIPT), 'check', '--book', str(self.book)], capture_output=True)
        self.assertEqual(result.returncode, 1)
    def test_finalize_requires_reviews(self):
        self.complete_structure()
        self.assertEqual(study.finalize(self.book, self.repo)['status'], 'DIRECTORY_INCOMPLETE')
    def test_matching_complete_reviews(self):
        self.complete_structure(); fp = study.fingerprint(self.book)
        study.dump_json(self.book / 'verification/editorial_review.json', {'status': 'PASS', 'content_digest': fp, 'reviewer': 'synthetic fixture, not real editorial', 'chapter_reviews': [{'path': 'learning/stage-a/start.md', 'status': 'PASS'}]})
        study.dump_json(self.book / 'verification/browser_validation.json', {'status': 'PASS', 'content_digest': fp, 'transport': 'file'})
        self.assertEqual(study.finalize(self.book, self.repo)['status'], 'DIRECTORY_READY')
        (self.book / 'learning/stage-a/start.md').write_text('# Changed\n')
        study.rebuild_index(self.book)
        self.assertEqual(study.finalize(self.book, self.repo)['status'], 'DIRECTORY_INCOMPLETE')
    def test_http_preview_cannot_satisfy_offline_completion(self):
        self.complete_structure(); fp = study.fingerprint(self.book)
        study.dump_json(self.book / 'verification/editorial_review.json', {'status': 'PASS', 'content_digest': fp, 'reviewer': 'synthetic only', 'chapter_reviews': [{'path': 'learning/stage-a/start.md', 'status': 'PASS'}]})
        study.dump_json(self.book / 'verification/browser_validation.json', {'status': 'PASS', 'content_digest': fp, 'transport': 'local-http'})
        self.assertEqual(study.finalize(self.book, self.repo)['status'], 'DIRECTORY_INCOMPLETE')
    def test_no_overwrite(self):
        with self.assertRaises(study.StudyError): study.init(self.repo, self.config)
    def test_no_escaping_book(self):
        with self.assertRaises(study.StudyError): study.safe_book(self.repo, '../../escape')
    def test_symlink_parent_is_rejected(self):
        alias = self.repo / 'alias'; alias.symlink_to(self.repo / 'src', target_is_directory=True)
        with self.assertRaises(study.StudyError): study.confined(self.repo, 'alias/control.c')
    def test_script_payload_is_escaped(self):
        self.complete_structure(); (self.book / 'learning/stage-a/start.md').write_text('# Unsafe\n</script><script>window.owned=1</script>\n')
        text = study.index_text(self.book)
        self.assertNotIn('</script>', text); self.assertIn('\\u003c', text)
    def test_bad_source_line_link(self):
        self.complete_structure(); (self.book / 'learning/stage-a/start.md').write_text('# Page\n[wrong](../../source_snapshot/src/control.c#L400)\n')
        self.assertIn('source_line_out_of_range', {i['error'] for i in study.check(self.book)['issues']})
    def test_malformed_source_aborts_before_writing(self):
        (self.repo / 'src/bad.c').write_bytes(b'\xff')
        conf = json.loads(self.config.read_text()); conf['book_id'] = 'new-fixture'; self.config.write_text(json.dumps(conf))
        with self.assertRaises(study.StudyError): study.init(self.repo, self.config)
        self.assertFalse((self.repo / 'docs/code-study/new-fixture').exists())
    def test_svg_script_rejected(self):
        self.complete_structure(); (self.book / 'graphs/overview/flow.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>')
        self.assertIn('active_svg_content', {i['error'] for i in study.check(self.book)['issues']})

if __name__ == '__main__': unittest.main()
