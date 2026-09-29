#!/usr/bin/env python3
"""Deterministic documentation helpers; no firmware edits or semantic PASS generation."""
from __future__ import annotations
import argparse
import fnmatch
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

VERSION = "2.0.0"
SKILL = Path(__file__).resolve().parents[1]
KINDS = {"modules": "模块", "functions": "函数", "reference": "专题", "learning": "阶段"}
REQUIRED_DIRS = [*KINDS, "graphs/modules", "graphs/functions", "graphs/overview", "assets", "source_snapshot", "verification"]
INPUT_RECORDS = {"baseline.json", "source_manifest.json", "inventory.json", "learning_plan.json"}

class StudyError(RuntimeError):
    pass

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())

def confined(root: Path, relative: str) -> Path:
    """Reject traversal and symlinks, including symlinked parents."""
    rel = Path(relative)
    if not relative or rel.is_absolute() or ".." in rel.parts or "\\" in relative:
        raise StudyError(f"Unsafe relative path: {relative}")
    root = root.resolve()
    path = root / rel
    for part in [path, *path.parents]:
        if part == root:
            break
        if part.is_symlink():
            raise StudyError(f"Symlink is not allowed: {part}")
    if not path.resolve().is_relative_to(root):
        raise StudyError(f"Path escapes root: {relative}")
    return path

def write_text(path: Path, text: str) -> None:
    if path.is_symlink() or path.with_name(path.name + ".tmp").is_symlink():
        raise StudyError(f"Refusing symlink write: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text, encoding="utf-8", newline="\n")
    os.replace(tmp, path)

def dump_json(path: Path, obj: object) -> None:
    write_text(path, json.dumps(obj, ensure_ascii=False, indent=2) + "\n")

def load_json(path: Path) -> dict:
    try:
        obj = json.loads(path.read_text(encoding="utf-8-sig"))
    except (ValueError, OSError) as exc:
        raise StudyError(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(obj, dict):
        raise StudyError(f"JSON object required: {path}")
    return obj

def git_info(repo: Path) -> dict:
    def run(*args: str) -> str:
        try:
            p = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, timeout=10, check=False)
            return p.stdout.decode("utf-8", errors="replace").strip() if p.returncode == 0 else ""
        except (OSError, subprocess.SubprocessError):
            return ""
    return {"head": run("rev-parse", "HEAD") or None, "status": run("status", "--porcelain=v1"), "captured_utc": datetime.now(timezone.utc).isoformat(timespec="seconds")}

def match(rel: str, patterns: list[str]) -> bool:
    """Segment globs: ** matches zero or more directories, * stays in a segment."""
    def parts_match(parts: tuple[str, ...], pattern: tuple[str, ...]) -> bool:
        if not pattern:
            return not parts
        if pattern[0] == "**":
            return parts_match(parts, pattern[1:]) or bool(parts and parts_match(parts[1:], pattern))
        return bool(parts and fnmatch.fnmatchcase(parts[0], pattern[0]) and parts_match(parts[1:], pattern[1:]))
    return any(parts_match(tuple(rel.split("/")), tuple(p.split("/"))) for p in patterns)

def collect_sources(repo: Path, cfg: dict) -> list[Path]:
    include = cfg.get("include", [])
    if not isinstance(include, list) or not include or not all(isinstance(p, str) for p in include):
        raise StudyError("Nonempty include patterns required")
    found = []
    for p in repo.rglob("*"):
        rel = p.relative_to(repo).as_posix()
        if rel.startswith((".git/", "docs/code-study/", "docs/product-doc/")) or not p.is_file():
            continue
        if match(rel, include) and not match(rel, cfg.get("exclude", [])):
            found.append(confined(repo, rel))
    if not found:
        raise StudyError("Selected source scope is empty")
    return sorted(found)

def safe_book(repo: Path, book_id: str) -> Path:
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,79}", book_id):
        raise StudyError("book_id must be 1..80 lowercase letters, digits, _ or -")
    return confined(repo, "docs/code-study/" + book_id)

def init(repo: Path, config_path: Path) -> Path:
    repo = repo.resolve()
    cfg = load_json(config_path)
    if cfg.get("delivery_mode", "project-directory") != "project-directory" or cfg.get("generate_archive", False):
        raise StudyError("Helper supports project-directory only; explicit archives are a separate task")
    mode = cfg.get("snapshot_mode", "selected")
    if mode not in {"selected", "none"}:
        raise StudyError("snapshot_mode must be selected or none")
    book = safe_book(repo, str(cfg.get("book_id", "")))
    if book.exists():
        raise StudyError(f"Refusing to overwrite existing book: {book}")
    git_before = git_info(repo)
    # Validate the entire source selection before creating any book files.
    selected = []; total = 0
    for src in collect_sources(repo, cfg):
        rel = src.relative_to(repo).as_posix(); raw = src.read_bytes(); total += len(raw)
        if len(raw) > int(cfg.get("max_file_bytes", 2097152)) or total > int(cfg.get("max_total_bytes", 33554432)):
            raise StudyError(f"Source size limit exceeded: {rel}")
        enc = cfg.get("encoding_overrides", {}).get(rel, "utf-8")
        try:
            text = raw.decode(enc, errors="strict")
        except (UnicodeError, LookupError) as exc:
            raise StudyError(f"Source decoding failed: {rel}: {exc}") from exc
        selected.append((raw, {"path": rel, "snapshot_path": "source_snapshot/" + rel if mode == "selected" else None, "bytes": len(raw), "lines": len(text.splitlines()), "sha256": sha256_bytes(raw), "text_sha256": sha256_bytes(text.replace("\r\n", "\n").replace("\r", "\n").encode()), "encoding": enc}))
    for asset in ["index.html", "search.js", "style.css"]:
        if not (SKILL / "assets/search" / asset).is_file():
            raise StudyError(f"Missing installed skill asset: {asset}")
    for d in REQUIRED_DIRS:
        confined(book, d).mkdir(parents=True, exist_ok=True)
    for raw, item in selected:
        if item["snapshot_path"]:
            dst = confined(book, item["snapshot_path"]); dst.parent.mkdir(parents=True, exist_ok=True); dst.write_bytes(raw)
    manifest = [item for _, item in selected]
    study = {**cfg, "schema_version": 3, "tool_version": VERSION, "delivery_mode": "project-directory", "generate_archive": False}
    dump_json(book / "study.json", study)
    dump_json(book / "verification/baseline.json", {"label": cfg.get("baseline_label"), "git": git_before, "source_digest": sha256_bytes("".join(x["path"] + "\0" + x["sha256"] for x in manifest).encode())})
    dump_json(book / "verification/source_manifest.json", {"schema_version": 1, "mode": mode, "files": manifest})
    dump_json(book / "verification/inventory.json", {"discovery": {"status": "TO_FILL"}, "file_coverage": [], "modules": [], "symbols": [], "edges": [], "articles": []})
    dump_json(book / "verification/learning_plan.json", {"chapters": [], "uncovered": []})
    dump_json(book / "verification/progress.json", {"status": "IN_PROGRESS"})
    write_text(book / "README.md", "# " + str(cfg.get("project", "源码学习")) + "\n\n请完成真实学习正文；目录初始化不代表成品。\n\n[分阶段学习](learning/README.md)\n")
    write_text(book / "source_snapshot/README.md", "# 冻结源码\n\n只读学习证据，不是升级包；不要复制回产品源码。\n")
    rebuild_index(book)
    return book

def entries(book: Path) -> list[dict]:
    out = []
    for folder, kind in KINDS.items():
        for p in sorted((book / folder).rglob("*.md")):
            p = confined(book, p.relative_to(book).as_posix()); txt = p.read_text(encoding="utf-8")
            title = next((x[2:].strip() for x in txt.splitlines() if x.startswith("# ")), p.stem)
            out.append({"title": title, "path": p.relative_to(book).as_posix(), "kind": kind, "text": txt})
    for rel in ["README.md", "source_snapshot/README.md"]:
        p = confined(book, rel)
        if p.is_file():
            txt = p.read_text(encoding="utf-8"); out.append({"title": txt.splitlines()[0].lstrip("# ") if txt else p.name, "path": rel, "kind": "说明", "text": txt})
    for item in load_json(book / "verification/source_manifest.json").get("files", []):
        sr = item.get("snapshot_path")
        if sr:
            p = confined(book, sr)
            if p.is_file():
                out.append({"title": item["path"], "path": sr, "kind": "源码", "text": p.read_bytes().decode(item.get("encoding", "utf-8"), errors="strict")})
    return out

def index_text(book: Path) -> str:
    payload = {"format": 3, "baseline": load_json(book / "study.json").get("baseline_label"), "full_text": True, "entries": entries(book)}
    # Also safe if a caller later embeds this JSON inside a script element.
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    return "window.CODE_STUDY_DATA=" + body + ";\n"

def rebuild_index(book: Path) -> None:
    for name in ["index.html", "search.js", "style.css"]:
        target = name if name == "index.html" else "assets/" + name
        write_text(confined(book, target), (SKILL / "assets/search" / name).read_text(encoding="utf-8"))
    write_text(confined(book, "assets/search-index.js"), index_text(book))

def render(book: Path) -> int:
    dot = shutil.which("dot")
    if not dot:
        raise StudyError("Graphviz dot unavailable; no dependency installed")
    count = 0
    for p in sorted(book.rglob("*.dot")):
        rel = p.relative_to(book).as_posix()
        if rel.startswith(("source_snapshot/", "verification/")):
            continue
        src = confined(book, rel); target = confined(book, p.with_suffix(".svg").relative_to(book).as_posix())
        subprocess.run([dot, "-Tsvg", str(src), "-o", str(target)], check=True, timeout=60); count += 1
    return count

def text_without_fences(text: str) -> str:
    return re.sub(r"(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$", "", text)

def local_links(md: Path) -> list[str]:
    txt = text_without_fences(md.read_text(encoding="utf-8"))
    return [m.group(1) or m.group(2) for m in re.finditer(r"!?\[[^\]\n]*\]\((?:<([^>]+)>|([^\s)]+))", txt)]

def function_page_issues(path: Path) -> list[str]:
    txt = path.read_text(encoding="utf-8"); issues = []
    for section in ["## 1. 完整函数体与原注释", "## 5. 代码解释"]:
        if section not in txt:
            issues.append("missing_" + section)
        elif "```" not in txt.split(section, 1)[1].split("\n## ", 1)[0]:
            issues.append("missing_code_block_" + section)
    if re.search(r"L\d+.*(?:执行语句|循环继续条件|判断条件)", txt):
        issues.append("mechanical_line_transcript")
    return issues

def svg_issues(p: Path) -> list[str]:
    try:
        root = ET.fromstring(p.read_text(encoding="utf-8"))
        for el in root.iter():
            if el.tag.split("}")[-1].lower() in {"script", "foreignobject"}:
                return ["active_svg_content"]
            for key, val in el.attrib.items():
                if key.split("}")[-1].lower().startswith("on") or val.strip().lower().startswith(("javascript:", "data:text/html")):
                    return ["active_svg_content"]
        return []
    except (ET.ParseError, UnicodeError):
        return ["invalid_svg"]

def check(book: Path, repo: Path | None = None) -> dict:
    book = book.resolve(); issues = []
    def issue(error: str, **detail):
        issues.append({"error": error, **detail})
    cfg = load_json(confined(book, "study.json"))
    htmls = sorted(p.relative_to(book).as_posix() for p in book.rglob("*.html"))
    if htmls != ["index.html"]:
        issue("unique_html_required", found=htmls)
    articles = [p for folder in KINDS for p in sorted((book / folder).rglob("*.md"))]
    for folder in KINDS:
        if not list((book / folder).rglob("*.md")):
            issue("empty_section", folder=folder)
    for p in [book / "README.md", *articles]:
        if not p.is_file():
            issue("missing_article", file=str(p)); continue
        confined(book, p.relative_to(book).as_posix())
        text = text_without_fences(p.read_text(encoding="utf-8"))
        if re.search(r"\{\{[^{}]+\}\}", text):
            issue("unfilled_template", file=p.relative_to(book).as_posix())
        for raw in local_links(p):
            u = urlsplit(html.unescape(raw))
            if u.scheme or raw.startswith("//") or not u.path:
                continue
            dest = (p.parent / unquote(u.path)).resolve()
            if not dest.is_relative_to(book) or not dest.exists():
                issue("broken_link", file=p.relative_to(book).as_posix(), target=raw)
            elif u.fragment and re.fullmatch(r"L\d+(?:-L?\d+)?", u.fragment) and dest.is_file():
                match_line = re.fullmatch(r"L(\d+)(?:-L?(\d+))?", u.fragment)
                start, end = int(match_line[1]), int(match_line[2] or match_line[1])
                if start < 1 or end < start or end > len(dest.read_bytes().splitlines()):
                    issue("source_line_out_of_range", target=raw)
    for p in (book / "functions").rglob("*.md"):
        for err in function_page_issues(p):
            issue(err, file=p.relative_to(book).as_posix())
    for p in book.rglob("*.svg"):
        if p.relative_to(book).parts[0] != "source_snapshot":
            for err in svg_issues(confined(book, p.relative_to(book).as_posix())):
                issue(err, file=p.relative_to(book).as_posix())
    manifest = load_json(book / "verification/source_manifest.json")
    if not manifest.get("files"):
        issue("empty_source_manifest")
    for item in manifest.get("files", []):
        sr = item.get("snapshot_path")
        if sr:
            p = confined(book, sr)
            if not p.is_file() or sha256_file(p) != item["sha256"]:
                issue("snapshot_hash_changed", file=item["path"])
        if repo is not None:
            src = confined(repo, item["path"])
            if not src.is_file() or sha256_file(src) != item["sha256"]:
                issue("source_drift", file=item["path"])
    inv = load_json(book / "verification/inventory.json")
    if inv.get("discovery", {}).get("status") in {None, "TO_FILL"}:
        issue("inventory_not_reviewed")
    covered = {x.get("path") for x in inv.get("file_coverage", []) if isinstance(x, dict)}
    missing = {x["path"] for x in manifest.get("files", [])} - covered
    if missing:
        issue("source_coverage_missing", files=sorted(missing))
    idx = confined(book, "assets/search-index.js")
    if not idx.is_file() or idx.read_text(encoding="utf-8") != index_text(book):
        issue("stale_or_missing_index")
    report = {"result": "PASS" if not issues else "FAIL", "tool_version": VERSION, "counts": {k: len(list((book / k).rglob("*.md"))) for k in KINDS}, "issues": issues, "limitations": ["Structure only; source meanings, general Markdown anchors and function-body fidelity require editorial review."]}
    dump_json(confined(book, "verification/validation.json"), report)
    return report

def fingerprint(book: Path) -> str:
    h = hashlib.sha256()
    for p in sorted(x for x in book.rglob("*") if x.is_file()):
        rel = p.relative_to(book).as_posix()
        if rel.startswith("verification/") and rel not in {"verification/" + x for x in INPUT_RECORDS}:
            continue
        p = confined(book, rel); h.update(rel.encode()); h.update(b"\0"); h.update(p.read_bytes()); h.update(b"\0")
    return h.hexdigest()

def drift(book: Path, repo: Path) -> dict:
    changes = []
    for item in load_json(book / "verification/source_manifest.json").get("files", []):
        p = confined(repo, item["path"]); actual = sha256_file(p) if p.is_file() else None
        if actual != item["sha256"]:
            changes.append({"path": item["path"], "expected": item["sha256"], "actual": actual})
    out = {"result": "PASS" if not changes else "DRIFT", "files": changes}
    dump_json(confined(book, "verification/drift.json"), out); return out

def finalize(book: Path, repo: Path) -> dict:
    cfg = load_json(book / "study.json")
    if book.resolve() != safe_book(repo.resolve(), cfg["book_id"]).resolve():
        raise StudyError("finalize requires the exact project docs/code-study/<book-id> directory")
    report = check(book, repo); fp = fingerprint(book)
    def optional(name: str):
        p = confined(book, "verification/" + name)
        return load_json(p) if p.is_file() else {}
    review = optional("editorial_review.json"); browser = optional("browser_validation.json")
    chapters = {p.relative_to(book).as_posix() for p in (book / "learning").rglob("*.md") if p.name != "README.md"}
    reviewed = {x.get("path") for x in review.get("chapter_reviews", []) if isinstance(x, dict) and x.get("status") == "PASS"}
    ready = bool(chapters) and chapters <= reviewed and report["result"] == "PASS" and all(x.get("status") == "PASS" and x.get("content_digest") == fp for x in [review, browser]) and bool(review.get("reviewer")) and browser.get("transport") == "file"
    out = {"status": "DIRECTORY_READY" if ready else "DIRECTORY_INCOMPLETE", "content_digest": fp, "structure": report["result"], "editorial": review.get("status", "NOT_RUN"), "browser": browser.get("status", "NOT_RUN"), "unreviewed_chapters": sorted(chapters - reviewed), "scope": "Documentation only; not firmware or hardware release approval"}
    dump_json(confined(book, "verification/completion.json"), out); return out

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__); sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("init"); p.add_argument("--repo", type=Path, required=True); p.add_argument("--config", type=Path, required=True)
    for cmd in ["render", "index", "check", "drift", "fingerprint", "finalize"]:
        p = sub.add_parser(cmd); p.add_argument("--book", type=Path, required=True)
        if cmd in {"check", "drift", "finalize"}:
            p.add_argument("--repo", type=Path, required=cmd != "check")
    a = ap.parse_args()
    try:
        if a.cmd == "init":
            print(init(a.repo, a.config)); return 0
        book = a.book.resolve()
        if a.cmd == "render": print(render(book)); return 0
        if a.cmd == "index": rebuild_index(book); print("OK"); return 0
        if a.cmd == "fingerprint": print(fingerprint(book)); return 0
        repo = a.repo.resolve() if getattr(a, "repo", None) else None
        out = check(book, repo) if a.cmd == "check" else drift(book, repo) if a.cmd == "drift" else finalize(book, repo)
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return 0 if out.get("result") == "PASS" or out.get("status") == "DIRECTORY_READY" else 1
    except (StudyError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr); return 2

if __name__ == "__main__":
    raise SystemExit(main())
