#!/usr/bin/env python3
"""문서 정합 검사 — takbon-docs 축의 「눈」.

이 리포의 고유 실패 양식을 잰다: **에러 0 · 전 스위트 그린 · 그런데 정본이 거짓말한다.**
Godot 헤드리스 스위트는 문서를 한 글자도 안 읽으므로 구조적으로 못 잡는다.

재는 것 (전부 정적 사실이라 정적으로 잴 수 있다 — 세84 교훈):
  [1] 설계 README 「현역」 표 줄 수 == ls docs/takbon-design/*.md - 1(README)
  [2] 설계 README 「휴지통」 표 줄 수 == ls docs/takbon-design/_archive/*.md
  [3] 표에 등재되지 않은 문서 (세96·101·105에 세 번 재발했다)
  [4] 죽은 경로 참조 — docs/takbon-design/…md 를 가리키는데 파일이 없다
  [5] 휴지통 문서를 「정본」이라 부르는 현역 서술 (휴지통은 정본이 아니다)
  [6] CLAUDE.md 비대화 — 세98에 39.5KB→13KB로 줄인 뒤의 상한

    python tools/docs_audit.py          # 사람이 읽는 리포트
    python tools/docs_audit.py --quiet  # 마커만 (그물용)

판정은 마지막 줄 마커로 한다: DOCS_AUDIT_OK / DOCS_AUDIT_FAIL:<건수>
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Windows 콘솔 기본 코드페이지(cp949)는 한글 박스문자·이모지에서 죽는다 — 출력을 UTF-8로 고정한다.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "docs" / "takbon-design"
ARCHIVE = DESIGN / "_archive"
README = DESIGN / "README.md"
CLAUDE_MD = ROOT / "CLAUDE.md"

# 세98에 39.5KB → 13KB로 줄였다. 이 축의 존재 이유 중 하나가 「다시 붇는 것」을 막는 것이다.
# 🔴 넘겼다고 바로 빨강이 아니다 — 넘으면 「무엇을 스킬로 내릴지」를 묻는 신호다.
CLAUDE_MD_LIMIT_KB = 18

# 참조를 세지 않는 곳: _reports는 gitignore 휘발물이고, README 자신은 인덱스라 전부 든다.
SKIP_REF_DIRS = ("docs/_reports/",)


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def table_entries(md: str, heading_kw: str) -> list[str]:
    """`## …<heading_kw>…` 절 안의 표에서 첫 칸의 `파일명.md`를 뽑는다."""
    lines = md.splitlines()
    start = next(
        (i for i, ln in enumerate(lines) if ln.startswith("##") and heading_kw in ln),
        None,
    )
    if start is None:
        return []
    names: list[str] = []
    for ln in lines[start + 1 :]:
        if ln.startswith("## "):  # 다음 절에서 끊는다
            break
        m = re.match(r"^\|\s*`([^`]+\.md)`\s*\|", ln)
        if m:
            names.append(m.group(1))
    return names


def main() -> int:
    quiet = "--quiet" in sys.argv
    problems: list[str] = []

    def out(msg: str = "") -> None:
        if not quiet:
            print(msg)

    if not README.exists():
        print(f"DOCS_AUDIT_FAIL:1  ({README} 가 없다)")
        return 1

    readme = read(README)
    live_files = sorted(p.name for p in DESIGN.glob("*.md") if p.name != "README.md")
    arch_files = sorted(p.name for p in ARCHIVE.glob("*.md")) if ARCHIVE.exists() else []
    live_rows = table_entries(readme, "현역")
    arch_rows = table_entries(readme, "휴지통")

    out("── 설계 문서 인덱스 ─────────────────────────────")
    out(f"  현역   파일 {len(live_files):>2}  |  표 {len(live_rows):>2}")
    out(f"  휴지통 파일 {len(arch_files):>2}  |  표 {len(arch_rows):>2}")

    # [1][2][3] 표 ↔ 파일
    for label, files, rows in (("현역", live_files, live_rows), ("휴지통", arch_files, arch_rows)):
        missing = [f for f in files if f not in rows]      # 파일은 있는데 표에 없다
        stale = [r for r in rows if r not in files]        # 표에 있는데 파일이 없다
        for f in missing:
            problems.append(f"[{label}] 표에 없다: {f}  ← 세96·101·105에 세 번 재발한 그 병이다")
        for r in stale:
            problems.append(f"[{label}] 표에만 있다(파일 없음): {r}")

    # [4] 죽은 경로 참조
    out("\n── 죽은 경로 참조 ───────────────────────────────")
    pat = re.compile(r"docs/takbon-design/(?:_archive/)?[A-Za-z0-9_]+\.md")
    scanned = 0
    for md in sorted(ROOT.glob("docs/**/*.md")) + [CLAUDE_MD] + sorted(
        ROOT.glob(".claude/**/*.md")
    ):
        rel = md.relative_to(ROOT).as_posix()
        if any(rel.startswith(d) for d in SKIP_REF_DIRS) or not md.exists():
            continue
        scanned += 1
        for ref in set(pat.findall(read(md))):
            if not (ROOT / ref).exists():
                problems.append(f"[죽은 링크] {rel} → {ref}")
    out(f"  {scanned}개 문서를 훑었다")

    # [5] 휴지통을 「정본」이라 부르는 자리
    # 🔴 README는 일부러 뺀다 — 휴지통 표는 「무엇이 어디에 있나」를 설명하는 자리라
    #    거기서 「정본」을 말하는 건 정상이고, 넣으면 오탐만 3건 난다(세106 실측).
    #    오탐을 내는 그물은 사람이 빨강을 무시하게 만든다 = 세104가 종료코드 판정을 걷은 그 이유.
    #    여기서 잡아야 할 진짜 위험은 **현역 문서 본문**이 휴지통을 정본이라 가리키는 것이다.
    out("\n── 휴지통을 정본이라 부르는 곳 ──────────────────")
    hits = 0
    NEGATIONS = ("정본이 아니다", "정본으로 참조", "정본이었다")
    targets = [p for p in DESIGN.glob("*.md") if p.name != "README.md"]
    targets += [p for p in ROOT.glob("docs/*.md")]
    for md in sorted(targets):
        for ln_no, ln in enumerate(read(md).splitlines(), 1):
            if "정본" not in ln or "_archive/" in ln or any(n in ln for n in NEGATIONS):
                continue
            for a in arch_files:
                if a[:-3] in ln:
                    hits += 1
                    problems.append(
                        f"[정본 오인] {md.relative_to(ROOT).as_posix()}:{ln_no} "
                        f"— 휴지통 문서 {a} 를 「정본」이라 부른다"
                    )
    out(f"  {hits}건")

    # [6] CLAUDE.md 비대화
    out("\n── CLAUDE.md 크기 ───────────────────────────────")
    if CLAUDE_MD.exists():
        kb = CLAUDE_MD.stat().st_size / 1024
        out(f"  {kb:.1f}KB (상한 {CLAUDE_MD_LIMIT_KB}KB)")
        if kb > CLAUDE_MD_LIMIT_KB:
            problems.append(
                f"[비대] CLAUDE.md {kb:.1f}KB > {CLAUDE_MD_LIMIT_KB}KB "
                "— 무엇을 스킬·설계문서로 내릴지 정해라(세98에 39.5→13KB로 줄였다)"
            )

    out("\n" + "─" * 50)
    if problems:
        for p in problems:
            print(f"  🔴 {p}")
        print(f"\nDOCS_AUDIT_FAIL:{len(problems)}")
        return 1
    out("  문제 없음")
    print("DOCS_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
