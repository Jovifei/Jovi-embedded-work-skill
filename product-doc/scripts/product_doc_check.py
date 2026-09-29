#!/usr/bin/env python3
"""Read-only mechanical checks for a source-grounded product document bundle.

This does not evaluate firmware expressions, generate prose, approve specifications,
render Word, or assert that a browser/board test has passed.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

COLUMNS = 'id,category,name,value,unit,kind,scope,symbol,expression,source,line_start,line_end,usage_source,usage_line_start,usage_line_end,evidence,calculation,uncertainty'.split(',')
EVIDENCE = {'SOURCE_CONFIG', 'ACTIVE_LOGIC', 'DERIVED', 'MEASURED', 'UNKNOWN'}

class ValidationError(ValueError):
    pass

def within(root: Path, relative: str) -> Path:
    rel = Path(relative)
    if not relative or rel.is_absolute() or '..' in rel.parts or '\\' in relative:
        raise ValidationError('Unsafe path: ' + relative)
    root = root.resolve(); path = root / rel
    for p in [path, *path.parents]:
        if p == root:
            break
        if p.is_symlink():
            raise ValidationError('Symlink is not allowed: ' + relative)
    if not path.resolve().is_relative_to(root):
        raise ValidationError('Path escapes root: ' + relative)
    return path

def read_table(path: Path, columns: list[str]) -> list[dict]:
    with path.open(encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        fields = reader.fieldnames or []
        if len(fields) != len(set(fields)) or not set(columns) <= set(fields):
            raise ValidationError('Missing or duplicate columns: ' + str(path))
        rows = list(reader)
        if not rows or any(None in row or any(v is None for v in row.values()) for row in rows):
            raise ValidationError('Empty or malformed table: ' + str(path))
        return rows

def validate(book: Path, source_root: Path) -> dict:
    book = book.resolve(); source_root = source_root.resolve(); errors = []; counts = {}; source_lines = {}
    def fail(code: str, **kw):
        errors.append({'error': code, **kw})
    manifest_path = within(book, 'verification/source_manifest.json')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    if not isinstance(manifest, dict) or not isinstance(manifest.get('files'), list) or not manifest['files']:
        raise ValidationError('Nonempty source_manifest.files list required')
    for item in manifest['files']:
        if not isinstance(item, dict) or not isinstance(item.get('path'), str):
            fail('invalid_manifest_entry'); continue
        name = item['path']
        try:
            p = within(source_root, name); raw = p.read_bytes()
            if name in source_lines:
                fail('duplicate_manifest_source', source=name)
            expected = item.get('sha256', '')
            if not re.fullmatch('[0-9a-f]{64}', expected) or hashlib.sha256(raw).hexdigest() != expected:
                fail('source_hash_mismatch', source=name)
            source_lines[name] = raw.decode(item.get('encoding', 'utf-8'), errors='strict').splitlines()
        except (ValidationError, OSError, UnicodeError, LookupError) as exc:
            fail('source_unreadable_or_unsafe', source=name, detail=str(exc))
    rows = read_table(within(book, 'parameters.csv'), COLUMNS); seen = set()
    def check_ref(row: dict, prefix: str, required: bool) -> None:
        path_key = 'source' if not prefix else 'usage_source'
        start_key, end_key = prefix + 'line_start', prefix + 'line_end'
        path = row[path_key].strip()
        if not path:
            if required: fail('source_reference_required', id=row['id'], field=path_key)
            return
        if path not in source_lines:
            fail('source_not_in_manifest', id=row['id'], source=path); return
        try:
            start, end = int(row[start_key]), int(row[end_key])
            if not 1 <= start <= end <= len(source_lines[path]):
                raise ValueError('range')
        except ValueError:
            fail('invalid_source_range', id=row['id'], source=path)
    for row in rows:
        rid = row['id'].strip(); evidence = row['evidence'].strip()
        if not rid or rid in seen:
            fail('empty_or_duplicate_parameter_id', id=rid)
        seen.add(rid)
        for field in ['category', 'name', 'unit', 'kind', 'scope']:
            if not row[field].strip(): fail('missing_parameter_field', id=rid, field=field)
        if evidence not in EVIDENCE:
            fail('invalid_evidence_type', id=rid); continue
        counts[evidence] = counts.get(evidence, 0) + 1
        if evidence == 'UNKNOWN' and not row['uncertainty'].strip():
            fail('unknown_requires_explanation', id=rid)
        if evidence != 'UNKNOWN' and not row['value'].strip():
            fail('value_required', id=rid)
        if evidence == 'DERIVED' and not row['calculation'].strip():
            fail('derived_requires_calculation', id=rid)
        if evidence == 'SOURCE_CONFIG' and not row['usage_source'].strip() and not row['uncertainty'].strip():
            fail('default_without_usage_requires_caveat', id=rid)
        check_ref(row, '', evidence != 'UNKNOWN')
        check_ref(row, 'usage_', evidence in {'ACTIVE_LOGIC', 'DERIVED'})
    chapters = sorted((book / 'chapters').rglob('*.md'))
    if not chapters: fail('no_product_chapters')
    for name in ['README.md', 'index.html', 'verification/baseline.json']:
        if not within(book, name).is_file(): fail('missing_required_file', file=name)
    for p in [book / 'README.md', *chapters]:
        if not p.is_file(): continue
        p = within(book, p.relative_to(book).as_posix())
        text = p.read_text(encoding='utf-8')
        text = re.sub(r'(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$', '', text)
        if re.search(r'\{\{[^{}]+\}\}', text): fail('unfilled_template', file=p.name)
        for m in re.finditer(r'!?\[[^\]\n]*\]\(([^\s)]+)', text):
            url = urlsplit(m[1])
            if url.scheme or not url.path or m[1].startswith('//'): continue
            target = (p.parent / unquote(url.path)).resolve()
            if not target.is_relative_to(book) or not target.is_file():
                fail('broken_or_escaping_document_link', file=p.name, target=m[1])
    graphs = sorted((book / 'graphs').rglob('*.svg'))
    if not graphs: fail('no_rendered_flow_diagrams')
    for p in graphs:
        try:
            p = within(book, p.relative_to(book).as_posix()); root = ET.fromstring(p.read_text(encoding='utf-8'))
            if not p.with_suffix('.dot').is_file(): fail('missing_editable_diagram_source', file=p.name)
            for element in root.iter():
                if element.tag.split('}')[-1].lower() in {'script', 'foreignobject'}:
                    fail('active_svg_content', file=p.name)
                if any(k.split('}')[-1].lower().startswith('on') or v.strip().lower().startswith('javascript:') for k, v in element.attrib.items()):
                    fail('active_svg_content', file=p.name)
        except (ET.ParseError, OSError, ValidationError):
            fail('invalid_svg', file=p.name)
    applicability_path = within(book, 'verification/applicability.json')
    applicability = json.loads(applicability_path.read_text(encoding='utf-8-sig')) if applicability_path.is_file() else {}
    if not isinstance(applicability, dict):
        raise ValidationError('applicability must be an object')
    for filename, required in [('acceptance.csv', ['id', 'function', 'preconditions', 'input_and_duration', 'expected_behavior', 'observation', 'method', 'safety_limits', 'status', 'evidence']), ('protection.csv', ['id', 'name', 'trigger_expression', 'sample_type', 'confirm_time', 'enabled_when', 'immediate_action', 'delayed_action', 'latch', 'recovery_expression', 'recovery_time', 'restart_policy', 'source_reference'])]:
        path = within(book, filename)
        decision = applicability.get(filename, {})
        if filename == 'protection.csv' and isinstance(decision, dict) and decision.get('status') == 'NOT_APPLICABLE':
            if not str(decision.get('reason', '')).strip(): fail('inapplicable_requires_reason', file=filename)
            continue
        if not path.is_file():
            fail('missing_required_table', file=filename); continue
        try:
            items = read_table(path, required)
            ids = [r['id'].strip() for r in items]
            if any(not rid for rid in ids) or len(ids) != len(set(ids)): fail('duplicate_or_empty_table_id', file=filename)
            if filename == 'acceptance.csv':
                for row in items:
                    if row['status'] not in {'NOT_RUN', 'PASS', 'FAIL', 'BLOCKED', 'NOT_APPLICABLE'}:
                        fail('invalid_acceptance_status', id=row['id'])
                    if row['status'] in {'PASS', 'FAIL'} and not row['evidence'].strip():
                        fail('test_result_without_evidence', id=row['id'])
        except ValidationError as exc:
            fail('invalid_table', file=filename, detail=str(exc))
    return {'result': 'PASS' if not errors else 'FAIL', 'parameters': len(rows), 'chapters': len(chapters), 'diagrams': len(graphs), 'evidence_counts': counts, 'issues': errors, 'not_checked': ['Meaning of formulas and limits', 'Effective build configuration', 'Measurement authenticity', 'General Markdown anchors', 'Browser/Word visual appearance', 'Firmware and board behavior']}

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__); ap.add_argument('--book', type=Path, required=True); ap.add_argument('--source-root', type=Path, required=True)
    args = ap.parse_args()
    try:
        report = validate(args.book, args.source_root)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0 if report['result'] == 'PASS' else 1
    except (OSError, ValueError, TypeError, KeyError) as exc:
        print(json.dumps({'result': 'ERROR', 'detail': str(exc)}, ensure_ascii=False)); return 2

if __name__ == '__main__':
    raise SystemExit(main())
