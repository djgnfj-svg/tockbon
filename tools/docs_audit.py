#!/usr/bin/env python3
"""문서 정합 검사 — 「에러 0 · 전 스위트 그린 · 그런데 정본이 거짓말한다」를 잡는 그물.

Godot 헤드리스 스위트는 문서를 한 글자도 안 읽으므로 구조적으로 못 잡는다. 여기서 재는 것:
단계 표↔폴더 일치 · 미등재/떠도는 .md · 죽은 경로 참조 · 완료 문서를 「정본」이라 부르는 자리 ·
CLAUDE.md 비대 · 그래프(프론트매터 owns 충돌 · 죽은 엣지 · 순환).

    python tools/docs_audit.py          # 사람이 읽는 리포트
    python tools/docs_audit.py --quiet  # 마커만 (그물용)
    python tools/docs_audit.py --ready  # 지금 동시에 착수 가능한 문서

⚠ 폴더명이 곧 README 헤딩 키워드다 — 헤딩에서 폴더명을 빼면 그 표를 못 찾아 전량 빨강이 된다.
⚠ 옛 접두 이름(`1_planned` 등)은 읽기 쪽으로만 계속 받는다 — 과거 문서가 그 표기를 쓴다.

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
README = DESIGN / "README.md"
CLAUDE_MD = ROOT / "CLAUDE.md"

# 🔴 단계 폴더 = README 표의 키워드. 순서가 곧 흐름이다(기획 → 개발 중 → 완료).
STAGES = ("planned", "building", "done")
DONE = STAGES[-1]  # 「정본이 아니다」를 재는 대상
# 옛 접두 표기(`1_planned` 등). 폴더는 사라졌지만 **참조는 여전히 잡아야** 한다 —
# 안 잡으면 낡은 경로가 죽은 링크인 채 침묵으로 통과한다.
STAGE_ALT = "|".join(f"(?:[123]_)?{s}" for s in STAGES)

# 🔴 `docs/` 루트 정본도 그래프 노드다. 자리로 상태를 못 재서 `stage: canon`을 쓴다.
# ⚠ DECISIONS·TODO·BACKLOG는 기록이지 자원을 정하는 문서가 아니라 일부러 뺐다(owns 충돌 오탐).
CANON = "canon"
CANON_DOCS = ("GDD.md", "PROGRESSION.md", "ONBOARDING_FLOW.md", "ART_SPEC.md", "VFX_SPEC.md")

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


# ── 그래프 층 ────────────────────────────────────────
# 자원 어휘. 🔴 오타가 곧 검출 실패다 — `monument`와 `monuments`는 안 겹친다.
VOCAB = {
    "genre", "run_flow", "progression", "monument", "spell_assembly",
    "jin_semantics", "glyph_data", "rune_data", "forge_ui", "enemy_feel",
    "enemy_ai", "economy", "equipment", "vfx_spec", "visual_spec",
    "world", "onboarding", "drawing_tools", "save_schema",
    "guide_shape",    # 진·룬 밑그림 모양 (guide_editor · jin_shape_image)
    "cast_control",   # 시전 중 조작 (spell_cast_visual)
    "player_vision",  # 플레이어 시야 — 폐기됐지만 죽은 노드가 계속 붙들고 있다
    # 🔴 아래 둘은 죽은 문서(`dungeon_structure`)에서 살아남은 자원이라 갈랐다 —
    #    `run_flow`로 묶으면 딸려 사라진다.
    "mob_spawning",   # 무엇이 어디에 서나 (dungeon_structure)
    "rune_fill",      # 룬을 그린 크기 → 상태이상 세기 (nested)
    # 🔴 아래 셋은 `run_flow`(런이 어떻게 흐르나)와 일부러 갈랐다 — 이쪽은 **방 한 칸의 내부**다.
    "room_layout",    # 방 크기·경계·카메라·방 전환
    "door_choice",    # 문 개수 · 문 위 보상 미리보기
    "room_reward",    # 방을 깨면 무엇이 어떻게 손에 들어오나 (상자)
}
FM_LIST = re.compile(r"^\[(.*)\]$")


def front_matter(md: str) -> dict | None:
    """맨 앞 `---` 블록을 뜯는다. PyYAML을 안 쓴다(의존성 0 유지)."""
    if not md.startswith("---"):
        return None
    end = md.find("\n---", 3)
    if end < 0:
        return None
    fm: dict = {}
    for ln in md[3:end].splitlines():
        if ":" not in ln or ln.lstrip().startswith("#"):
            continue
        k, _, v = ln.partition(":")
        k, v = k.strip(), v.strip()
        m = FM_LIST.match(v)
        if m:
            fm[k] = [x.strip().strip("`'\"") for x in m.group(1).split(",") if x.strip()]
        elif v in ("true", "false"):
            fm[k] = v == "true"
        else:
            fm[k] = v
    return fm


def load_graph(problems: list[str]) -> dict[str, dict]:
    """단계 폴더 + `docs/` 루트 정본에서 노드를 읽는다. 자리(stage)와 프론트매터의 불일치도 잡는다.
    🔴 루트 정본까지 보는 이유: `takbon-design/` 안만 보면 정본 문서와의 겹침을 통째로 못 본다.
    """
    nodes: dict[str, dict] = {}
    targets = [(DESIGN / s / p.name, s) for s in STAGES for p in sorted((DESIGN / s).glob("*.md"))]
    targets += [(ROOT / "docs" / f, CANON) for f in CANON_DOCS if (ROOT / "docs" / f).exists()]
    for path, s in targets:
        rel = path.relative_to(ROOT).as_posix()
        fm = front_matter(read(path))
        if fm is None:
            problems.append(f"[그래프] 프론트매터가 없다: {rel}  ← node·stage·owns·needs를 맨 앞에 붙여라")
            continue
        node = fm.get("node")
        if not node:
            problems.append(f"[그래프] `node`가 없다: {rel}")
            continue
        if fm.get("stage") != s:
            problems.append(f"[그래프] stage가 자리와 다르다: {rel} — 자리는 {s}, 적힌 건 {fm.get('stage')!r}")
        if node in nodes:
            problems.append(f"[그래프] node 이름이 겹친다: {node} ({rel} · {nodes[node]['path']})")
            continue
        owns = fm.get("owns") or []
        needs = fm.get("needs") or []
        for r in owns:
            if r not in VOCAB:
                problems.append(f"[그래프] 어휘 밖 owns: {node} → {r!r}  ← VOCAB에 넣거나 오타를 고쳐라")
        nodes[node] = {
            "path": rel, "stage": s, "owns": owns, "needs": needs,
            "dead": bool(fm.get("dead")), "blocked": fm.get("blocked"),
            "anchor": bool(fm.get("anchor")),
        }
    return nodes


def check_graph(nodes: dict[str, dict], problems: list[str], conflicts: list[str]) -> None:
    """🔴 충돌과 구조 오류를 **다른 통에 담는다.**
    충돌은 「버그」가 아니라 「아직 안 정했다」는 사실이다. 늘 빨간 채로 두면 사람이 빨강을
    무시하게 되고 진짜 버그가 같이 묻힌다. ⇒ 판정(FAIL)은 구조 오류만 · 충돌은 찍되 초록을 안 깬다.
    """
    live = {n: d for n, d in nodes.items() if not d["dead"]}

    # [8] owns 충돌 — 이 층의 존재 이유다. 산 노드 둘이 같은 자원을 정하면 둘 다 에러 0인 채 갈라진다.
    by_res: dict[str, list[str]] = {}
    for n, d in live.items():
        for r in d["owns"]:
            by_res.setdefault(r, []).append(n)
    for r, owners in sorted(by_res.items()):
        if len(owners) < 2:
            continue
        # 🔴 겹침에는 **종류가 있다.** 하나로 뭉뚱그리면 오탐이 섞여 사람이 빨강을 무시한다.
        anchored = [n for n in owners if live[n]["anchor"]]
        kinds = {live[n]["stage"] for n in owners}
        if anchored:
            # ⚠ 「앵커가 이긴다」로 단정하면 **인과가 거꾸로 갈 수 있다** — GDD의 그 줄이 애초에
            #    그 설계문서에서 쓰인 것이면 둘은 싸우는 게 아니라 같은 말이다.
            tail = f"  ← 🔒 앵커 {anchored[0]} 가 낀다. **GDD가 그 설계에서 쓰인 것인지 먼저 봐라** — 아니면 GDD가 이긴다"
        elif kinds <= {CANON, DONE}:
            tail = "  ← 정본↔완료다. 규격을 정본이 흡수한 자리면 정상이다"
        else:
            tail = "  ← 하나로 정하기 전엔 코드를 얹지 마라"
        # ⚠ 노드 이름과 자원 이름이 같은 게 넷이다(`glyph_data`·`progression`·`vfx_spec`…).
        #    자리를 붙여야 「자원 X를 노드 X가 정한다」가 안 헷갈린다.
        who = " · ".join(f"{n}[{live[n]['stage']}]" for n in sorted(owners))
        conflicts.append(f"`{r}` 를 {len(owners)}곳이 정한다: {who}{tail}")

    # [9] 엣지 무결성
    for n, d in nodes.items():
        for dep in d["needs"]:
            if dep not in nodes:
                problems.append(f"[그래프] 없는 노드를 needs: {n} → {dep!r}")
            elif nodes[dep]["dead"] and not d["dead"]:
                problems.append(f"[그래프] 죽은 노드를 전제로 삼는다: {n} → {dep}")

    # 순환 — DFS 3색
    state: dict[str, int] = {}

    def walk(n: str, trail: list[str]) -> None:
        if state.get(n) == 2:
            return
        if state.get(n) == 1:
            cyc = trail[trail.index(n):] + [n]
            problems.append(f"[그래프] needs 순환: {' → '.join(cyc)}")
            return
        state[n] = 1
        for dep in nodes.get(n, {}).get("needs", []):
            if dep in nodes:
                walk(dep, trail + [n])
        state[n] = 2

    for n in nodes:
        walk(n, [])


def print_ready(nodes: dict[str, dict]) -> None:
    """지금 **동시에** 착수 가능한 문서 — 그래프를 만든 실제 목적."""
    live = {n: d for n, d in nodes.items() if not d["dead"]}
    counts: dict[str, int] = {}
    for d in live.values():
        for r in d["owns"]:
            counts[r] = counts.get(r, 0) + 1
    contested = {r for r, c in counts.items() if c > 1}

    print("── 지금 동시에 착수 가능 ────────────────────────")
    ready, held = [], []
    for n, d in sorted(live.items()):
        # 완료·정본은 「착수 대상」이 아니다 — 전자는 끝났고 후자는 늘 거기 있다.
        if d["stage"] in (DONE, CANON):
            continue
        why = []
        if d["blocked"]:
            why.append(f"막힘: {d['blocked']}")
        for dep in d["needs"]:
            # 정본(canon)·완료(done)는 이미 굳은 전제라 막는 게 아니다.
            if dep in live and live[dep]["stage"] not in (DONE, CANON):
                why.append(f"{dep} 미확정")
        for r in d["owns"]:
            if r in contested:
                why.append(f"`{r}` 소유 경합")
        (held if why else ready).append((n, d, why))
    for n, d, _why in ready:
        print(f"  ✅ {n:<22} [{d['stage']}] owns: {', '.join(d['owns']) or '—'}")
    if not ready:
        print("  (없다)")
    print("\n── 막혀 있다 ───────────────────────────────────")
    for n, _d, why in held:
        print(f"  ⏸ {n:<22} {' · '.join(why)}")
    dead = sorted(n for n, d in nodes.items() if d["dead"])
    if dead:
        print(f"\n── 죽은 문서 {len(dead)} ─────────────────────────────\n  {' · '.join(dead)}")


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
    stage_files: dict[str, list[str]] = {}
    for s in STAGES:
        d = DESIGN / s
        if d.is_dir():
            stage_files[s] = sorted(p.name for p in d.glob("*.md"))
        else:
            stage_files[s] = []
            problems.append(f"[구조] 단계 폴더가 없다: docs/takbon-design/{s}/")

    # [1][3] 표 ↔ 파일
    out("── 설계 문서 인덱스 ─────────────────────────────")
    for s in STAGES:
        rows = table_entries(readme, s)
        out(f"  {s:<11} 파일 {len(stage_files[s]):>2}  |  표 {len(rows):>2}")
        for f in stage_files[s]:
            if f not in rows:  # 파일은 있는데 표에 없다
                problems.append(f"[{s}] 표에 없다: {f}  ← 세96·101·105에 세 번 재발한 그 병이다")
        for r in rows:
            if r not in stage_files[s]:  # 표에 있는데 파일이 없다
                problems.append(f"[{s}] 표에만 있다(파일 없음): {r}")

    # [2] 단계 폴더 밖에 굴러다니는 .md
    # 🔴 자리가 곧 상태다 — 자리가 없으면 상태도 없다.
    for f in sorted(p.name for p in DESIGN.glob("*.md") if p.name != "README.md"):
        problems.append(
            f"[구조] 단계 폴더 밖에 있다: docs/takbon-design/{f}"
            f"  ← {' · '.join(STAGES)} 중 하나로 넣고 README 표에 올려라"
        )

    # [4] 죽은 경로 참조
    out("\n── 죽은 경로 참조 ───────────────────────────────")
    pat = re.compile(rf"docs/takbon-design/(?:(?:{STAGE_ALT})/)?[A-Za-z0-9_]+\.md")
    # 🔴 경로 표기가 둘이다 — 리포 루트부터 쓴 것과 bare 상대 경로(`done/…`). README 표와
    #    설계문서가 후자를 쓴다. 단계 이름은 열거라 옛 접두(`1_`) 표기도 같이 잡는다.
    pat_bare = re.compile(rf"(?<![\w/])(?:{STAGE_ALT})/[A-Za-z0-9_]+\.md")
    scanned = 0
    for md in sorted(ROOT.glob("docs/**/*.md")) + [CLAUDE_MD] + sorted(
        ROOT.glob(".claude/**/*.md")
    ):
        rel = md.relative_to(ROOT).as_posix()
        if any(rel.startswith(d) for d in SKIP_REF_DIRS) or not md.exists():
            continue
        scanned += 1
        body = read(md)
        refs = set(pat.findall(body))
        refs |= {f"docs/takbon-design/{b}" for b in pat_bare.findall(body)}
        for ref in refs:
            if not (ROOT / ref).exists():
                problems.append(f"[죽은 링크] {rel} → {ref}")
        # 🔴 옛 2단계 잔재. `_archive`는 이제 `done`이고 폴더 자체가 없다.
        #    위 정규식은 `_archive/…`를 매치하지 않아 이 검사가 없으면 통째로 침묵한다.
        if "_archive" in body:
            problems.append(
                f"[옛 구조] {rel} 이 `_archive`를 가리킨다 → `done`으로 고쳐라"
                " (역사를 서술하는 자리면 「휴지통」처럼 경로가 아닌 말로 바꿔라)"
            )
    out(f"  {scanned}개 문서를 훑었다")

    # [5] 휴지통을 「정본」이라 부르는 자리
    # 🔴 README는 일부러 뺀다 — 인덱스라 거기서 「정본」을 말하는 건 정상이고 오탐만 난다.
    out(f"\n── {DONE}을 정본이라 부르는 곳 ────────────────────")
    hits = 0
    NEGATIONS = ("정본이 아니다", "정본으로 참조", "정본이었다")
    # 현역 = 완료를 뺀 앞 단계들. 거기 본문이 완료 문서를 정본이라 가리키는 게 진짜 위험이다.
    targets = [p for s in STAGES[:-1] for p in (DESIGN / s).glob("*.md")]
    targets += [p for p in ROOT.glob("docs/*.md")]
    for md in sorted(targets):
        for ln_no, ln in enumerate(read(md).splitlines(), 1):
            if "정본" not in ln or f"{DONE}/" in ln or any(n in ln for n in NEGATIONS):
                continue
            for a in stage_files[DONE]:
                if a[:-3] in ln:
                    hits += 1
                    problems.append(
                        f"[정본 오인] {md.relative_to(ROOT).as_posix()}:{ln_no} "
                        f"— 완료 문서 {a} 를 「정본」이라 부른다"
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

    # [7][8][9] 그래프
    out("\n── 그래프 ───────────────────────────────────────")
    nodes = load_graph(problems)
    conflicts: list[str] = []
    check_graph(nodes, problems, conflicts)
    live = sum(1 for d in nodes.values() if not d["dead"])
    out(f"  노드 {len(nodes)} (산 것 {live}) · 엣지 {sum(len(d['needs']) for d in nodes.values())}")
    if "--ready" in sys.argv:
        print()
        print_ready(nodes)
        print()

    # 🔴 충돌은 판정을 안 깬다 — 「아직 안 정했다」는 사실이지 버그가 아니다.
    #    다만 조용히 두면 아무도 모른다 — 항상 찍는다.
    if conflicts:
        print(f"\n── ⚠ 소유 경합 {len(conflicts)} (미결이다 · 판정엔 안 센다) ──────")
        for c in conflicts:
            print(f"  ⚠ {c}")

    out("\n" + "─" * 50)
    tail = f" · CONFLICTS:{len(conflicts)}" if conflicts else ""
    if problems:
        for p in problems:
            print(f"  🔴 {p}")
        print(f"\nDOCS_AUDIT_FAIL:{len(problems)}{tail}")
        return 1
    out("  구조 문제 없음")
    print(f"DOCS_AUDIT_OK{tail}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
