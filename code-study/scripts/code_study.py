#!/usr/bin/env python3
"""Project-local code-study support tool.

Deterministic helper only: it creates the docs/code-study skeleton, snapshots selected
text sources, rebuilds the offline full-text index, renders DOT with an existing
Graphviz install, and validates structure/fingerprints. It never edits product source.
"""
from __future__ import annotations
import argparse, fnmatch, hashlib, html, json, os, re, shutil, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

VERSION = "1.3.0"
SKILL = Path(__file__).resolve().parents[1]
KINDS = {"modules":"模块","functions":"函数","reference":"专题","learning":"阶段"}
REQUIRED_DIRS = ["modules","functions","reference","learning","graphs/modules","graphs/functions","graphs/overview","assets","source_snapshot","verification"]

class StudyError(RuntimeError):
    pass

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())

def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text, encoding="utf-8", newline="\n")
    os.replace(tmp, path)

def dump_json(path: Path, obj: object) -> None:
    write_text(path, json.dumps(obj, ensure_ascii=False, indent=2) + "\n")

def load_json(path: Path) -> dict:
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise StudyError(f"无法读取JSON: {path}: {exc}") from exc
    if not isinstance(obj, dict):
        raise StudyError(f"JSON顶层必须是对象: {path}")
    return obj

def git_info(repo: Path) -> dict:
    def run(*args: str) -> str:
        try:
            p = subprocess.run(["git","-C",str(repo),*args], check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=10)
            return p.stdout.decode("utf-8", errors="replace").strip() if p.returncode == 0 else ""
        except Exception:
            return ""
    return {"head": run("rev-parse","HEAD") or None, "status": run("status","--porcelain=v1"), "captured_utc": datetime.now(timezone.utc).isoformat(timespec="seconds")}

def match(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(rel, p) or (p.startswith("**/") and fnmatch.fnmatchcase(rel, p[3:])) for p in patterns)

def collect_sources(repo: Path, cfg: dict) -> list[Path]:
    include = cfg.get("include") or []
    exclude = cfg.get("exclude") or []
    if not include:
        raise StudyError("include不能为空")
    found = []
    for p in repo.rglob("*"):
        if not p.is_file() or p.is_symlink():
            continue
        rel = p.relative_to(repo).as_posix()
        if rel.startswith(".git/") or rel.startswith("docs/code-study/") or "/docs/code-study/" in rel:
            continue
        if match(rel, include) and not match(rel, exclude):
            found.append(p)
    if not found:
        raise StudyError("声明的源码范围为空")
    return sorted(found)

def safe_book(repo: Path, book_id: str) -> Path:
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,79}", book_id):
        raise StudyError("book_id仅允许小写字母/数字/_/-，长度1..80")
    root = (repo / "docs" / "code-study" / book_id).resolve()
    expected = (repo.resolve() / "docs" / "code-study").resolve()
    if not root.is_relative_to(expected):
        raise StudyError("输出目录越界")
    return root

def init(repo: Path, config_path: Path) -> Path:
    cfg = load_json(config_path)
    if cfg.get("delivery_mode", "project-directory") != "project-directory" or cfg.get("generate_archive", False):
        raise StudyError("只支持project-directory且generate_archive=false")
    book = safe_book(repo, str(cfg.get("book_id", "")))
    if book.exists():
        raise StudyError(f"拒绝覆盖已有学习书: {book}")
    files = collect_sources(repo, cfg)
    book.mkdir(parents=True)
    for d in REQUIRED_DIRS:
        (book / d).mkdir(parents=True, exist_ok=True)
    for name in ["style.css","search.js"]:
        src = SKILL / "assets" / "search" / name
        shutil.copy2(src, book / "assets" / name)
    shutil.copy2(SKILL / "assets" / "search" / "index.html", book / "index.html")
    mode = cfg.get("snapshot_mode", "selected")
    manifest = []
    max_file = int(cfg.get("max_file_bytes", 2*1024*1024)); max_total = int(cfg.get("max_total_bytes", 32*1024*1024)); total = 0
    overrides = cfg.get("encoding_overrides", {})
    for src in files:
        rel = src.relative_to(repo).as_posix(); raw = src.read_bytes(); total += len(raw)
        if len(raw) > max_file or total > max_total:
            raise StudyError(f"源码快照大小超限: {rel}")
        enc = overrides.get(rel, "utf-8")
        try:
            text = raw.decode(enc, errors="strict")
        except Exception as exc:
            raise StudyError(f"源码解码失败 {rel} ({enc}): {exc}") from exc
        snap_rel = None
        if mode == "selected":
            snap = book / "source_snapshot" / rel
            snap.parent.mkdir(parents=True, exist_ok=True); snap.write_bytes(raw); snap_rel = snap.relative_to(book).as_posix()
        manifest.append({"path":rel,"snapshot_path":snap_rel,"bytes":len(raw),"lines":len(text.splitlines()) or 1,"sha256":sha256_bytes(raw),"text_sha256":sha256_bytes(text.replace("\r\n","\n").replace("\r","\n").encode()),"encoding":enc})
    study = {"schema_version":2,"tool_version":VERSION,"project":cfg.get("project"),"book_id":cfg["book_id"],"baseline_label":cfg.get("baseline_label"),"language":cfg.get("language","zh-CN"),"snapshot_mode":mode,"delivery_mode":"project-directory","generate_archive":False,"source_scope":{"include":cfg.get("include",[]),"exclude":cfg.get("exclude",[])}}
    dump_json(book / "study.json", study)
    dump_json(book / "verification" / "baseline.json", {"label":cfg.get("baseline_label"),"source_digest":sha256_bytes("".join(x["path"]+"\0"+x["sha256"] for x in manifest).encode()),"git":git_info(repo)})
    dump_json(book / "verification" / "source_manifest.json", {"schema_version":1,"mode":mode,"files":manifest})
    dump_json(book / "verification" / "inventory.json", {"discovery":{"status":"TO_FILL"},"file_coverage":[],"modules":[],"symbols":[],"edges":[],"articles":[]})
    dump_json(book / "verification" / "progress.json", {"status":"IN_PROGRESS","modules":{},"functions":{},"reference":{},"learning":{}})
    shutil.copy2(SKILL / "assets" / "templates" / "book-readme.md", book / "README.md")
    write_text(book / "source_snapshot" / "README.md", "# 冻结源码\n\n只读学习证据，不是升级包；不要复制回产品源码。\n")
    rebuild_index(book)
    return book

def text_without_fences(text: str) -> str:
    return re.sub(r"(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$", "", text)

def entries(book: Path) -> list[dict]:
    out=[]
    for folder, kind in KINDS.items():
        for p in sorted((book/folder).glob("*.md")):
            txt=p.read_text(encoding="utf-8"); title=next((x[2:].strip() for x in txt.splitlines() if x.startswith("# ")),p.stem)
            out.append({"title":title,"path":p.relative_to(book).as_posix(),"kind":kind,"text":txt})
    for p in [book/"README.md", book/"source_snapshot/README.md"]:
        if p.is_file():
            txt=p.read_text(encoding="utf-8"); out.append({"title":txt.splitlines()[0].lstrip("# ") if txt else p.name,"path":p.relative_to(book).as_posix(),"kind":"说明","text":txt})
    manifest = load_json(book/"verification/source_manifest.json")
    for item in manifest.get("files",[]):
        sr=item.get("snapshot_path")
        if sr and (book/sr).is_file():
            p=book/sr; out.append({"title":item["path"],"path":sr,"kind":"源码","text":p.read_text(encoding=item.get("encoding","utf-8"))})
    return out

def rebuild_index(book: Path) -> None:
    payload={"format":2,"baseline":load_json(book/"study.json").get("baseline_label"),"full_text":True,"entries":entries(book)}
    write_text(book/"assets/search-index.js", "window.CODE_STUDY_DATA="+json.dumps(payload,ensure_ascii=False,separators=(",",":"))+";\n")

def render(book: Path) -> int:
    dot=shutil.which("dot")
    if not dot: raise StudyError("未找到Graphviz dot；未安装则记录NOT_RUN，不伪造SVG")
    n=0
    for p in sorted((book/"graphs").rglob("*.dot")):
        target=p.with_suffix(".svg"); subprocess.run([dot,"-Tsvg",str(p),"-o",str(target)],check=True); n+=1
    return n

def function_page_issues(path: Path) -> list[str]:
    txt=path.read_text(encoding="utf-8")
    issues=[]
    if "## 1. 完整函数体与原注释" not in txt: issues.append("missing_section1")
    if "## 5. 代码解释" not in txt: issues.append("missing_section5")
    if len(re.findall(r"```[^\n]*\n",txt)) < 2: issues.append("needs_original_and_explanation_code_fences")
    s1=txt.split("## 1. 完整函数体与原注释",1)[1].split("\n## ",1)[0] if "## 1. 完整函数体与原注释" in txt else ""
    if re.search(r"学习注释|【源码事实】|【控制流推导】|【设计意图推断】",s1): issues.append("section1_contains_learning_annotation")
    s5=txt.split("## 5. 代码解释",1)[1].split("\n## ",1)[0] if "## 5. 代码解释" in txt else ""
    if re.search(r"(?m)^\s*[-*]\s*\*\*?L\d+|L\d+.*(?:执行语句|循环继续条件|判断条件)",s5): issues.append("mechanical_line_transcript")
    return issues

def local_links(md: Path) -> list[str]:
    txt=text_without_fences(md.read_text(encoding="utf-8")); return [m.group(1) or m.group(2) for m in re.finditer(r"!?\[[^\]\n]*\]\((?:<([^>]+)>|([^\s)]+))",txt)]

def check(book: Path, repo: Path|None=None) -> dict:
    issues=[]
    if not (book/"study.json").is_file(): raise StudyError("不是有效学习书")
    htmls=[p.relative_to(book).as_posix() for p in book.rglob("*.html")]
    if htmls != ["index.html"]: issues.append({"error":"unique_html_required","found":htmls})
    for folder in KINDS:
        for p in (book/folder).glob("*.md"):
            for raw in local_links(p):
                u=urlsplit(html.unescape(raw));
                if u.scheme or raw.startswith("//") or not u.path: continue
                dest=(p.parent/unquote(u.path)).resolve()
                if not dest.is_relative_to(book.resolve()) or not dest.exists(): issues.append({"error":"broken_link","file":p.relative_to(book).as_posix(),"target":raw})
    for p in (book/"functions").glob("*.md"):
        for err in function_page_issues(p): issues.append({"error":err,"file":p.relative_to(book).as_posix()})
    for p in (book/"graphs").rglob("*.svg"):
        try: ET.parse(p)
        except ET.ParseError as exc: issues.append({"error":"bad_svg","file":p.relative_to(book).as_posix(),"detail":str(exc)})
    manifest=load_json(book/"verification/source_manifest.json")
    for item in manifest.get("files",[]):
        sr=item.get("snapshot_path")
        if sr:
            p=book/sr
            if not p.is_file() or sha256_file(p)!=item["sha256"]: issues.append({"error":"snapshot_hash_changed","file":item["path"]})
        if repo is not None:
            src=repo/item["path"]
            if not src.is_file() or sha256_file(src)!=item["sha256"]: issues.append({"error":"source_drift","file":item["path"]})
    rebuild_index(book)
    report={"result":"PASS" if not issues else "FAIL","tool_version":VERSION,"counts":{"modules":len(list((book/"modules").glob("*.md"))),"functions":len(list((book/"functions").glob("*.md"))),"reference":len(list((book/"reference").glob("*.md"))),"learning":len(list((book/"learning").glob("*.md"))),"svg":len(list((book/"graphs").rglob("*.svg")))} ,"issues":issues}
    dump_json(book/"verification/validation.json",report); return report

def fingerprint(book: Path) -> str:
    h=hashlib.sha256()
    for p in sorted(x for x in book.rglob("*") if x.is_file() and x.name not in {"validation.json","completion.json"}):
        rel=p.relative_to(book).as_posix()
        if rel.startswith("verification/") and rel.endswith("review.json"): continue
        h.update(rel.encode()); h.update(b"\0"); h.update(p.read_bytes()); h.update(b"\0")
    return h.hexdigest()

def drift(book: Path, repo: Path) -> dict:
    issues=[]; manifest=load_json(book/"verification/source_manifest.json")
    for item in manifest.get("files",[]):
        p=repo/item["path"]
        actual=sha256_file(p) if p.is_file() else None
        if actual!=item["sha256"]: issues.append({"path":item["path"],"expected":item["sha256"],"actual":actual})
    out={"result":"PASS" if not issues else "DRIFT","files":issues,"checked_utc":datetime.now(timezone.utc).isoformat(timespec="seconds")}; dump_json(book/"verification/drift.json",out); return out

def finalize(book: Path, repo: Path) -> dict:
    expected=(repo.resolve()/"docs"/"code-study").resolve()
    if not book.resolve().is_relative_to(expected): raise StudyError("finalize只允许项目docs/code-study/<book-id>/")
    report=check(book,repo); fp=fingerprint(book)
    review=load_json(book/"verification/editorial_review.json") if (book/"verification/editorial_review.json").is_file() else {}
    browser=load_json(book/"verification/browser_validation.json") if (book/"verification/browser_validation.json").is_file() else {}
    ready=report["result"]=="PASS" and review.get("status")=="PASS" and review.get("content_digest")==fp and browser.get("status")=="PASS" and browser.get("content_digest")==fp
    out={"status":"DIRECTORY_READY" if ready else "DIRECTORY_INCOMPLETE","content_digest":fp,"structure":report["result"],"editorial":review.get("status","NOT_RUN"),"browser":browser.get("status","NOT_RUN"),"generated_utc":datetime.now(timezone.utc).isoformat(timespec="seconds")}; dump_json(book/"verification/completion.json",out); return out

def main() -> int:
    ap=argparse.ArgumentParser(description=__doc__); sub=ap.add_subparsers(dest="cmd",required=True)
    p=sub.add_parser("init"); p.add_argument("--repo",type=Path,required=True); p.add_argument("--config",type=Path,required=True)
    p=sub.add_parser("render"); p.add_argument("--book",type=Path,required=True)
    p=sub.add_parser("index"); p.add_argument("--book",type=Path,required=True)
    p=sub.add_parser("check"); p.add_argument("--book",type=Path,required=True); p.add_argument("--repo",type=Path)
    p=sub.add_parser("drift"); p.add_argument("--book",type=Path,required=True); p.add_argument("--repo",type=Path,required=True)
    p=sub.add_parser("fingerprint"); p.add_argument("--book",type=Path,required=True)
    p=sub.add_parser("finalize"); p.add_argument("--book",type=Path,required=True); p.add_argument("--repo",type=Path,required=True)
    a=ap.parse_args()
    try:
        if a.cmd=="init": print(init(a.repo,a.config))
        elif a.cmd=="render": print(render(a.book.resolve()))
        elif a.cmd=="index": rebuild_index(a.book.resolve()); print("OK")
        elif a.cmd=="check": print(json.dumps(check(a.book.resolve(),a.repo.resolve() if a.repo else None),ensure_ascii=False,indent=2))
        elif a.cmd=="drift": print(json.dumps(drift(a.book.resolve(),a.repo.resolve()),ensure_ascii=False,indent=2))
        elif a.cmd=="fingerprint": print(fingerprint(a.book.resolve()))
        elif a.cmd=="finalize": print(json.dumps(finalize(a.book.resolve(),a.repo.resolve()),ensure_ascii=False,indent=2))
        return 0
    except (StudyError,OSError,subprocess.SubprocessError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr); return 2

if __name__=="__main__": raise SystemExit(main())
