#!/usr/bin/env python3
"""Real file:// reader checks. Requires installed Playwright and Chromium; never installs.

These are representative UI checks, not editorial or firmware verification.
"""
from __future__ import annotations
import argparse
import json
import re
import shutil
from pathlib import Path
from urllib.parse import quote, urlsplit
from code_study import StudyError, dump_json, entries, fingerprint


def run(book: Path, base_url: str | None = None) -> dict:
    baseline = fingerprint(book)
    out = {"status": "NOT_RUN", "content_digest": baseline, "transport": "local-http" if base_url else "file", "checks": [], "limitations": []}
    if base_url and (urlsplit(base_url).scheme != "http" or urlsplit(base_url).hostname not in {"127.0.0.1", "localhost", "::1"}):
        raise StudyError("Only an explicit loopback HTTP preview is allowed")
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        out["limitations"].append("Playwright unavailable; no dependency was installed.")
        return out
    data = entries(book)
    articles = [e for e in data if e["kind"] == "阶段" and not e["path"].endswith("README.md")]
    if not articles:
        out["status"] = "FAIL"; out["limitations"].append("No actual learning chapter to test.")
        return out
    # Prefer a nested chapter: this is the regression the previous scanner missed.
    article = sorted(articles, key=lambda e: (-e["path"].count("/"), e["path"]))[0]
    checks = out["checks"]
    def record(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"id": name, "pass": bool(ok), "detail": detail})
    try:
        with sync_playwright() as pw:
            try:
                browser = pw.chromium.launch(headless=True)
            except Exception as exc:
                executable = shutil.which("chromium") or shutil.which("chromium-browser")
                if not executable:
                    out["limitations"].append("Chromium launch unavailable: " + str(exc))
                    return out
                try:
                    browser = pw.chromium.launch(headless=True, executable_path=executable)
                    out["browser_executable"] = executable
                except Exception as fallback:
                    out["limitations"].append("Installed Chromium could not launch: " + str(fallback))
                    return out
            try:
                page = browser.new_page(viewport={"width": 1280, "height": 850})
                errors = []; requests = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("request", lambda req: requests.append(req.url) if req.url.startswith(("http://", "https://")) and not (base_url and req.url.startswith(base_url.rstrip("/") + "/")) else None)
                url = base_url.rstrip("/") + "/index.html" if base_url else (book / "index.html").as_uri()
                try:
                    page.goto(url, wait_until="load")
                except Exception as exc:
                    if "ERR_BLOCKED_BY_ADMINISTRATOR" in str(exc):
                        out["limitations"].append("Navigation blocked by administrator policy; not bypassed. " + str(exc))
                        return out
                    raise
                record("file_load", page.locator("#query").is_visible())
                # Query a real title, then assert the specific chapter is among positive hits.
                page.fill("#query", article["title"])
                page.wait_for_timeout(150)
                paths = page.locator(".result").evaluate_all("els => els.map(el => el.dataset.path)")
                record("known_chapter_hit", article["path"] in paths and len(paths) > 0, article["path"])
                # A phrase from the interior confirms a title-only index cannot pass.
                candidates = re.findall(r"[\u4e00-\u9fff]{5,20}|[A-Za-z_][A-Za-z_0-9]{7,30}", article["text"])
                phrase = next((word for word in candidates if word not in article["title"]), None)
                if phrase:
                    page.fill("#query", phrase); page.wait_for_timeout(150)
                    paths = page.locator(".result").evaluate_all("els => els.map(el => el.dataset.path)")
                    record("body_text_hit", article["path"] in paths, phrase)
                else:
                    record("body_text_hit", False, "Chapter lacks testable interior prose")
                missing = "__code_study_nonexistent_probe_72d51679__"
                while any(missing in e["text"] for e in data): missing += "x"
                page.fill("#query", missing); page.wait_for_timeout(150)
                record("no_results", page.locator(".result").count() == 0 and "0" in page.locator("#status").inner_text())
                page.fill("#query", "")
                page.goto(url + "#p=" + quote(article["path"], safe=""), wait_until="load")
                page.wait_for_timeout(150)
                record("chapter_read", article["title"] in page.locator("#content").inner_text())
                record("reading_navigation", page.locator("#back").is_visible() and page.locator("#next").count() == 1 and page.locator("#previous").count() == 1)
                if re.search(r"(?m)^\s*\|.*\|", article["text"]):
                    record("table_rendered", page.locator("#content table").count() > 0)
                if "<details>" in article["text"]:
                    details = page.locator("#content details").first
                    record("answer_present", details.count() > 0)
                    if details.count():
                        details.locator("summary").click(); record("answer_expands", details.get_attribute("open") is not None)
                image = page.locator("#content img.diagram").first
                if image.count():
                    image.scroll_into_view_if_needed(); page.wait_for_function("[...document.querySelectorAll('#content img.diagram')].every(i => i.complete && i.naturalWidth > 0)")
                    image.click(); record("diagram_zoom", page.locator("#image-dialog").evaluate("el => el.open"))
                    page.locator("#close-image").click(); record("diagram_close", not page.locator("#image-dialog").evaluate("el => el.open"))
                else:
                    record("diagram_present", False, "Representative learning chapter has no rendered diagram")
                page.set_viewport_size({"width": 390, "height": 844})
                page.screenshot(path=str(book / "verification/browser-mobile.png"), full_page=True)
                record("mobile_no_page_overflow", page.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 2"))
                record("mobile_query_visible", page.locator("#query").is_visible())
                page.set_viewport_size({"width": 1280, "height": 850})
                page.screenshot(path=str(book / "verification/browser-desktop.png"), full_page=True)
                sources = [e for e in data if e["kind"] == "源码" and e["text"].splitlines()]
                if sources:
                    source = sources[0]; line = min(2, len(source["text"].splitlines()))
                    page.goto(url + "#p=" + quote(source["path"], safe="") + "&line=" + str(line), wait_until="load")
                    page.wait_for_timeout(150)
                    selected = page.locator("#content .source-lines li.selected")
                    record("source_line_highlight", selected.count() == 1 and selected.inner_text() == source["text"].splitlines()[line - 1])
                else:
                    out["limitations"].append("No local source snapshot; source-line UI check not applicable.")
                record("no_script_errors", not errors, "; ".join(errors))
                record("no_network_requests", not requests, "; ".join(requests))
            finally:
                browser.close()
        record("unchanged_content_during_test", fingerprint(book) == baseline)
        out["status"] = "PASS" if checks and all(item["pass"] for item in checks) else "FAIL"
    except Exception as exc:
        out["status"] = "FAIL"; out["limitations"].append(str(exc))
    out["limitations"].append("Representative UI only; full graph meaning, every chapter and firmware are not verified by this script.")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--book", type=Path, required=True)
    parser.add_argument("--base-url", help="Explicit localhost HTTP preview; never counts as file:// verification")
    args = parser.parse_args(); book = args.book.resolve()
    try:
        (book / "verification").mkdir(parents=True, exist_ok=True)
        result = run(book, args.base_url)
        dump_json(book / "verification/browser_validation.json", result)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["status"] == "PASS" else 2 if result["status"] == "NOT_RUN" else 1
    except (StudyError, OSError, ValueError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, ensure_ascii=False)); return 2

if __name__ == "__main__":
    raise SystemExit(main())
