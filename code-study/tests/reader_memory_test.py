#!/usr/bin/env python3
"""Synthetic in-memory DOM regression, NOT file:// or deployment verification.

Renders known test strings in about:blank without navigating to blocked resources.
The diagram is supplied as test data; this does not test filesystem asset loading.
"""
from __future__ import annotations
import base64
import json
from pathlib import Path
import re
import shutil
import sys
from playwright.sync_api import sync_playwright

SKILL = Path(__file__).resolve().parents[1]

def main() -> int:
    html = (SKILL / 'assets/search/index.html').read_text(encoding='utf-8')
    html = re.sub(r'<script\b[^>]*src=[^>]*>\s*</script>', '', html)
    html = re.sub(r'<link\b[^>]*>', '', html)
    entries = [
        {'path': 'learning/README.md', 'title': '学习入口', 'kind': '阶段', 'text': '# 学习入口\n[第一章](01-start/start.md)'},
        {'path': 'learning/01-start/start.md', 'title': '先准备', 'kind': '阶段', 'text': '# 先准备\n\n机械释放观察只在正文中。\n\n![测试图](../../graphs/flow.svg)\n\n|参数|说明|\n|---|---|\n|`x\\|y`|保持原文|\n\n<details><summary>展开答案</summary>\n\n答案是先停好。\n\n</details>\n\n[task](../../functions/task.md)\n\n[源码](../../source_snapshot/control.c#L2)\n\n<script>window.owned=true</script>\n'},
        {'path': 'learning/02-run/run.md', 'title': '再运行', 'kind': '阶段', 'text': '# 再运行\n虚构第二章。'},
        {'path': 'functions/task.md', 'title': 'task', 'kind': '函数', 'text': '# task\n\n```c\nint task(void) { return 0; }\n```'},
        {'path': 'source_snapshot/control.c', 'title': 'control.c', 'kind': '源码', 'text': '/* <script>window.owned=true</script> */\nint task(void) { return 0; }\n'}]
    checks = []
    def verify(label, value):
        checks.append({'id': label, 'pass': bool(value)})
    with sync_playwright() as pw:
        executable = shutil.which('chromium') or shutil.which('chromium-browser')
        browser = pw.chromium.launch(headless=True, **({'executable_path': executable} if executable else {}))
        try:
            page = browser.new_page(viewport={'width': 1280, 'height': 850})
            errors = []; page.on('pageerror', lambda e: errors.append(str(e)))
            page.set_content(html)
            page.add_style_tag(content=(SKILL / 'assets/search/style.css').read_text(encoding='utf-8'))
            page.add_script_tag(content='window.CODE_STUDY_DATA=' + json.dumps({'baseline': 'Synthetic DOM test only', 'entries': entries}, ensure_ascii=False))
            page.add_script_tag(content=(SKILL / 'assets/search/search.js').read_text(encoding='utf-8'))
            page.fill('#query', '机械释放观察')
            verify('nested_body_hit', page.locator('.result').count() == 1)
            page.locator('.result').click(); page.wait_for_timeout(100)
            verify('chapter_loaded', '先准备' in page.locator('#content').inner_text())
            verify('table_rendered', page.locator('#content tbody td').count() == 2)
            verify('table_code_pipe', page.locator('#content tbody td').first.inner_text() == 'x|y')
            page.locator('#content summary').click()
            verify('answer_open', page.locator('#content details').get_attribute('open') is not None)
            verify('raw_html_not_executed', page.evaluate('window.owned === undefined'))
            # Known fixture image, not a local resource fetch or a security-policy override.
            svg = '<svg xmlns="http://www.w3.org/2000/svg" width="450" height="120"><rect width="450" height="120" fill="#eef5f5"/><text x="28" y="65" font-size="20">PREPARE -- CHECK -- START</text></svg>'
            image = page.locator('#content img.diagram')
            image.evaluate('(img, data) => img.src=data', 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode())
            image.wait_for(state='visible'); image.click()
            verify('diagram_zoom_open', page.locator('#image-dialog').evaluate('d => d.open'))
            page.locator('#close-image').click(); verify('diagram_zoom_close', not page.locator('#image-dialog').evaluate('d => d.open'))
            page.locator('#next').click(); page.wait_for_timeout(100)
            verify('next_chapter', '再运行' in page.locator('#content').inner_text())
            page.locator('#previous').click(); page.wait_for_timeout(100)
            page.locator('#content a', has_text='task').click(); page.wait_for_timeout(100)
            verify('function_link', 'return 0' in page.locator('#content').inner_text())
            page.locator('#back').click(); page.wait_for_timeout(100)
            verify('back_to_chapter', '先准备' in page.locator('#content').inner_text())
            page.locator('#content a', has_text='源码').click(); page.wait_for_timeout(100)
            verify('source_highlight', page.locator('#L2.selected').count() == 1)
            verify('source_verbatim', page.locator('#L2 code').inner_text() == 'int task(void) { return 0; }')
            verify('source_not_executed', page.evaluate('window.owned === undefined'))
            page.fill('#query', 'nonexistent-23f14ae'); verify('no_results', page.locator('.result').count() == 0)
            page.fill('#query', ''); page.select_option('#kind', '函数'); verify('type_filter', page.locator('.result').count() == 1)
            page.set_viewport_size({'width': 390, 'height': 844})
            verify('mobile_overflow', page.evaluate('document.documentElement.scrollWidth <= innerWidth + 2'))
            verify('no_js_errors', not errors)
            out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else None
            if out_dir:
                out_dir.mkdir(parents=True, exist_ok=True)
                page.screenshot(path=str(out_dir / 'memory-mobile.png'), full_page=True)
                page.set_viewport_size({'width': 1280, 'height': 850})
                page.select_option('#kind', ''); page.fill('#query', '机械释放观察'); page.locator('.result').click(); page.wait_for_timeout(100)
                page.locator('#content img.diagram').evaluate('(img, data) => img.src=data', 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode())
                page.screenshot(path=str(out_dir / 'memory-desktop.png'), full_page=True)
        finally:
            browser.close()
    result = {'status': 'PASS' if all(c['pass'] for c in checks) else 'FAIL', 'transport': 'synthetic-memory', 'checks': checks, 'not_checked': ['file URL navigation', 'filesystem images and scripts', 'actual project book', 'editorial correctness']}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'PASS' else 1

if __name__ == '__main__':
    raise SystemExit(main())
