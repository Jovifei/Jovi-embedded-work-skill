#!/usr/bin/env python3
"""Optional real-browser smoke test for a generated code-study book."""
from __future__ import annotations
import argparse, hashlib, json, sys
from pathlib import Path


def digest(book: Path) -> str:
    h=hashlib.sha256()
    for p in sorted(x for x in book.rglob('*') if x.is_file() and x.name not in {'browser_validation.json','completion.json'}):
        h.update(p.relative_to(book).as_posix().encode()); h.update(b'\0'); h.update(p.read_bytes()); h.update(b'\0')
    return h.hexdigest()


def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument('--book',type=Path,required=True); a=ap.parse_args(); book=a.book.resolve()
    out={'status':'NOT_RUN','content_digest':digest(book),'checks':[],'limitations':[]}
    try:
        from playwright.sync_api import sync_playwright
    except Exception:
        out['limitations'].append('Playwright/Chromium unavailable; no dependency was installed automatically.')
        (book/'verification').mkdir(parents=True,exist_ok=True)
        (book/'verification/browser_validation.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(out,ensure_ascii=False,indent=2)); return 2
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True); page=browser.new_page(viewport={'width':1280,'height':800})
            errors=[]; page.on('pageerror',lambda e: errors.append(str(e)))
            page.goto((book/'index.html').as_uri(),wait_until='load')
            page.fill('#query','函数'); page.wait_for_timeout(150)
            status=page.locator('#status').inner_text(); results=page.locator('.result').count()
            out['checks']=[{'id':'file_url_load','pass':True},{'id':'search_status','pass':'条结果' in status},{'id':'search_results','pass':results>=0},{'id':'page_errors','pass':not errors,'detail':errors}]
            page.set_viewport_size({'width':390,'height':844}); out['checks'].append({'id':'mobile_query_visible','pass':page.locator('#query').is_visible()})
            browser.close()
        out['status']='PASS' if all(x['pass'] for x in out['checks']) else 'FAIL'
    except Exception as exc:
        out['status']='FAIL'; out['limitations'].append(str(exc))
    (book/'verification').mkdir(parents=True,exist_ok=True)
    (book/'verification/browser_validation.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(out,ensure_ascii=False,indent=2)); return 0 if out['status']=='PASS' else 1

if __name__=='__main__': raise SystemExit(main())
