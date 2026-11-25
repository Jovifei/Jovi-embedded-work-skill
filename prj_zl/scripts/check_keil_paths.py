#!/usr/bin/env python3
"""Read-only checks of literal Keil XML paths, not a build or firmware audit.

Exit 0: checked literal paths pass. Exit 2: path/XML/membership issue found.
Exit 3: no such issue, but dynamic or host-inaccessible paths need review.
"""
import argparse
import csv
import json
import ntpath
import os
from pathlib import Path
import re
import xml.etree.ElementTree as ET


FIELDS = {"FilePath", "IncludePath", "ScatterFile", "PathWithFileName"}
SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".s", ".asm"}


def local_tag(element):
    return element.tag.rsplit("}", 1)[-1]


def case_candidate(path):
    """Return existing spelling and mismatch before resolve can erase case.

    Exact names win on case-sensitive volumes; otherwise require a unique
    case-insensitive match. Follow the real directory when traversing '..'.
    """
    cursor = Path(path.anchor)
    mismatch = False
    try:
        for part in path.parts[1:]:
            if part == "..":
                cursor = cursor.resolve().parent
                continue
            matches = [p for p in cursor.iterdir() if p.name.casefold() == part.casefold()]
            exact = next((p for p in matches if p.name == part), None)
            if exact is not None:
                cursor = exact
            elif len(matches) == 1:
                cursor = matches[0]
                mismatch = True
            else:
                return None
        return cursor, mismatch
    except OSError:
        return None


def inspect_path(project, field, raw):
    value = raw.strip().strip('"')
    result = {"field": field, "value": value}
    if re.search(r"\$|%[^%]+%|@L|!L", value):
        return {**result, "status": "manual", "reason": "dynamic path; resolve in the actual toolchain"}
    drive, _ = ntpath.splitdrive(value)
    if drive and os.name != "nt":
        return {**result, "status": "manual", "reason": "Windows drive/UNC unavailable on this host"}
    try:
        candidate = Path(value.replace("\\", "/"))
        requested = project.parent / candidate
        spelling = case_candidate(requested)
        path = requested.resolve()
        result["resolved"] = str(path)
        if spelling is not None:
            actual, mismatch = spelling
            if mismatch:
                return {**result, "status": "case_mismatch", "existing_spelling": str(actual)}
        if not path.exists():
            return {**result, "status": "missing"}
        if spelling is None:
            return {**result, "status": "manual", "reason": "existing path spelling could not be verified unambiguously"}
        expected_directory = field == "IncludePath"
        if expected_directory and not path.is_dir():
            return {**result, "status": "not_directory"}
        if not expected_directory and not path.is_file():
            return {**result, "status": "not_file"}
        return {**result, "status": "exists"}
    except (OSError, ValueError) as exc:
        return {**result, "status": "manual", "reason": str(exc)}


def inspect_project(project):
    project = Path(project).resolve()
    result = {"project": str(project), "paths": [], "duplicates": []}
    try:
        document = ET.parse(project).getroot()
    except (OSError, ET.ParseError) as exc:
        return {**result, "parse_error": str(exc)}
    if local_tag(document) not in ("Project", "ProjectOpt"):
        return {**result, "parse_error": "expected Keil Project or ProjectOpt root"}
    target_count = 0
    seen_sources = {}

    def visit(element, target):
        nonlocal target_count
        if local_tag(element) == "Target":
            target_count += 1
            name = next((e.text for e in element if local_tag(e) == "TargetName"), None)
            target = f"{name or 'unnamed'} [{target_count}]"
        field = local_tag(element)
        if field in FIELDS and element.text and element.text.strip():
            values = next(csv.reader([element.text], delimiter=";", skipinitialspace=True)) if field == "IncludePath" else [element.text]
            for raw in values:
                if not raw.strip():
                    continue
                row = {**inspect_path(project, field, raw), "target": target}
                result["paths"].append(row)
                if field == "FilePath" and row.get("resolved"):
                    source = Path(row["resolved"])
                    key = (target, str(source))
                    if source.suffix.lower() in SOURCE_SUFFIXES:
                        if key in seen_sources:
                            result["duplicates"].append({"target": target, "resolved": str(source), "first": seen_sources[key], "again": raw, "note": "check target/file exclusion options before changing membership"})
                        else:
                            seen_sources[key] = raw
        for child in element:
            visit(child, target)

    visit(document, "project")
    if not result["paths"]:
        result["manual_notes"] = ["no supported nonempty path fields; no path coverage established"]
    return result


def inspect_projects(projects):
    rows = [inspect_project(project) for project in projects]
    issues = sum(bool(row.get("parse_error")) + len(row["duplicates"]) + sum(p["status"] not in ("exists", "manual") for p in row["paths"]) for row in rows)
    manual = sum(len(row.get("manual_notes", [])) + sum(p["status"] == "manual" for p in row["paths"]) for row in rows)
    code = 2 if issues else 3 if manual else 0
    return {"status": {0: "LITERAL_PATHS_PASS", 2: "PATHS_FAILED", 3: "MANUAL_REVIEW_REQUIRED"}[code],
            "boundary": "Literal XML paths only; not Keil preprocessing, linking, vector, firmware behavior or board validation.",
            "issue_count": issues, "manual_count": manual, "projects": rows}, code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("projects", nargs="+", type=Path, help="explicit .uvprojx/.uvoptx files")
    args = parser.parse_args()
    report, code = inspect_projects(args.projects)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
