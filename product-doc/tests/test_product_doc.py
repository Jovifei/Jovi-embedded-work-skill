"""Mechanical-check fixtures; no real product parameters or measurement evidence."""
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/product_doc_check.py'
spec = importlib.util.spec_from_file_location('product_check', SCRIPT); tool = importlib.util.module_from_spec(spec); spec.loader.exec_module(tool)

class ProductTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup); root = Path(self.temp.name)
        self.source = root / 'source'; self.source.mkdir(); self.raw = b'#define DEMO_LIMIT 42\nint allowed(int n) { return n < DEMO_LIMIT; }\n'
        (self.source / 'control.c').write_bytes(self.raw)
        self.book = root / 'book'; self.book.mkdir()
        for d in ['verification', 'chapters', 'graphs']: (self.book / d).mkdir()
        (self.book / 'verification/source_manifest.json').write_text(json.dumps({'files': [{'path': 'control.c', 'sha256': hashlib.sha256(self.raw).hexdigest(), 'encoding': 'utf-8'}]}))
        (self.book / 'verification/baseline.json').write_text('{"baseline":"synthetic only"}')
        (self.book / 'README.md').write_text('# Example\n[Chapter](chapters/start.md)\n')
        (self.book / 'index.html').write_text('<!doctype html><title>Synthetic only</title>')
        (self.book / 'chapters/start.md').write_text('# Example\n![Flow](../graphs/start.svg)\n')
        (self.book / 'graphs/start.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg"><text x="5" y="20">Example</text></svg>')
        (self.book / 'graphs/start.dot').write_text('digraph G { a -> b; }')
        self.row = dict.fromkeys(tool.COLUMNS, '')
        self.row.update(id='P1', category='Example', name='Limit', value='42', unit='count', kind='threshold', scope='fictional demonstration only', symbol='DEMO_LIMIT', expression='42', source='control.c', line_start='1', line_end='1', usage_source='control.c', usage_line_start='2', usage_line_end='2', evidence='ACTIVE_LOGIC')
        self.write_rows([self.row])
        (self.book / 'protection.csv').write_text('id,name,trigger_expression,sample_type,confirm_time,enabled_when,immediate_action,delayed_action,latch,recovery_expression,recovery_time,restart_policy,source_reference\nF1,Example,n>=limit,counter,none,example,stop,none,no,n<limit,none,manual,control.c:L2\n')
        (self.book / 'acceptance.csv').write_text('id,function,preconditions,input_and_duration,expected_behavior,observation,method,safety_limits,status,evidence\nA1,Example,fixture,n=42,stop,state,host,fictional,NOT_RUN,\n')
    def write_rows(self, rows):
        with (self.book / 'parameters.csv').open('w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=tool.COLUMNS); w.writeheader(); w.writerows(rows)
    def errors(self): return {r['error'] for r in tool.validate(self.book, self.source)['issues']}
    def test_protection_explicitly_inapplicable(self):
        (self.book / 'protection.csv').unlink()
        (self.book / 'verification/applicability.json').write_text(json.dumps({'protection.csv': {'status': 'NOT_APPLICABLE', 'reason': 'Synthetic no-protection variant'}}))
        self.assertEqual(tool.validate(self.book, self.source)['result'], 'PASS')
    def test_inapplicable_needs_reason(self):
        (self.book / 'verification/applicability.json').write_text(json.dumps({'protection.csv': {'status': 'NOT_APPLICABLE'}}))
        self.assertIn('inapplicable_requires_reason', {e['error'] for e in tool.validate(self.book, self.source)['issues']})
    def test_valid_fixture(self): self.assertEqual(tool.validate(self.book, self.source)['result'], 'PASS')
    def test_changed_source(self):
        (self.source / 'control.c').write_text('different'); self.assertIn('source_hash_mismatch', self.errors())
    def test_invalid_line(self):
        self.row['usage_line_end'] = '999'; self.write_rows([self.row]); self.assertIn('invalid_source_range', self.errors())
    def test_derived_needs_formula(self):
        self.row['evidence'] = 'DERIVED'; self.write_rows([self.row]); self.assertIn('derived_requires_calculation', self.errors())
    def test_unknown_needs_reason(self):
        self.row['evidence'] = 'UNKNOWN'; self.write_rows([self.row]); self.assertIn('unknown_requires_explanation', self.errors())
    def test_default_not_active_without_caveat(self):
        self.row.update(evidence='SOURCE_CONFIG', usage_source='', usage_line_start='', usage_line_end=''); self.write_rows([self.row]); self.assertIn('default_without_usage_requires_caveat', self.errors())
    def test_duplicate_id(self):
        self.write_rows([self.row, self.row]); self.assertIn('empty_or_duplicate_parameter_id', self.errors())
    def test_missing_scope(self):
        self.row['scope'] = ''; self.write_rows([self.row]); self.assertIn('missing_parameter_field', self.errors())
    def test_path_traversal(self):
        with self.assertRaises(tool.ValidationError): tool.within(self.source, '../outside')
    def test_symlink(self):
        (self.source / 'alias.c').symlink_to(self.source / 'control.c')
        with self.assertRaises(tool.ValidationError): tool.within(self.source, 'alias.c')
    def test_claimed_test_without_evidence(self):
        p = self.book / 'acceptance.csv'; p.write_text(p.read_text().replace('NOT_RUN', 'PASS'))
        self.assertIn('test_result_without_evidence', self.errors())
    def test_broken_link(self):
        (self.book / 'chapters/start.md').write_text('# Chapter\n[missing](absent.md)\n')
        self.assertIn('broken_or_escaping_document_link', self.errors())
    def test_nonzero_exit(self):
        self.row['scope'] = ''; self.write_rows([self.row])
        r = subprocess.run([sys.executable, str(SCRIPT), '--book', str(self.book), '--source-root', str(self.source)], capture_output=True)
        self.assertEqual(r.returncode, 1)
    def test_not_a_semantic_or_visual_pass(self):
        report = tool.validate(self.book, self.source)
        self.assertIn('Browser/Word visual appearance', report['not_checked'])
        self.assertIn('Meaning of formulas and limits', report['not_checked'])

if __name__ == '__main__': unittest.main()
