#!/usr/bin/env python3
"""Small helpers used by tests or reviewers to flag mechanical function prose."""
from __future__ import annotations
import re
from pathlib import Path

SECTION1='## 1. 完整函数体与原注释'
SECTION5='## 5. 代码解释'


def section(text: str, title: str) -> str:
    if title not in text: return ''
    tail=text.split(title,1)[1]
    return tail.split('\n## ',1)[0]


def section1_issues(path: Path) -> list[str]:
    text=path.read_text(encoding='utf-8'); body=section(text,SECTION1); issues=[]
    if not body: return ['missing_section1']
    if '```' not in body: issues.append('section1_missing_code_fence')
    if re.search(r'学习注释|【源码事实】|【控制流推导】|【设计意图推断】',body): issues.append('section1_contains_learning_annotation')
    return issues


def section5_issues(path: Path) -> list[str]:
    text=path.read_text(encoding='utf-8'); body=section(text,SECTION5); issues=[]
    if not body: return ['missing_section5']
    if '```' not in body: issues.append('section5_missing_code_fence')
    if re.search(r'L\d+.*(?:执行语句|循环继续条件|判断条件)',body): issues.append('mechanical_line_transcript')
    return issues
