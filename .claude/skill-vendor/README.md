# skill-vendor — 제네릭 스킬 벤더링 & 상류 대조

`.claude/skills/`의 제네릭 Godot 스킬(43개)은 **godot-prompter 플러그인 상류를 한국어로 번역한 사본**이다.
번역하는 순간 영어 원본과 갈라지므로, 여기서 그 갈라짐을 **관리**한다 (막는 게 아니라).

## 무엇이 들어 있나

- `VERSION` — 번역 기준이 된 상류 버전 (현재 `1.11.0`).
- `upstream-1.11.0/` — 번역 당시의 **영어 원본 박제본** (SKILL.md + references 전문). diff 기준점일 뿐,
  에이전트가 로드하지 않는다. 🔴 **`.claude/skills/`에서는 references를 지웠으므로, 심화문서 영어 전문이
  필요하면 여기(또는 상류 github)에서 꺼내 온다.**
- `check-upstream.sh` — 상류가 바뀌었는지 대조하는 스크립트.

## references는 skills/에 없다

`.claude/skills/`의 각 스킬은 SKILL.md 한 장씩만 있다 (트리를 깨끗이 하려고 references/ 심화문서를 지웠다).
심화 레시피(전체 코드 예제 등)가 필요하면 **여기 `upstream-1.11.0/<스킬>/references/`** 또는 상류 github에서
읽는다. SKILL.md 본문에는 이제 references를 가리키는 링크가 없다(죽은 링크라 정리했다).

## 왜 박제본을 두나

우리 한국어본과 새 상류를 직접 비교하면 **번역 때문에 전부 다르게** 나와 쓸모없다.
"상류가 실제로 바꾼 부분"만 뽑으려면 **번역 당시의 영어 원본(박제본) vs 새 영어 상류**를 비교해야 한다.

## 한 달에 한 번 (또는 생각날 때)

```bash
bash .claude/skill-vendor/check-upstream.sh
```

- 상류 버전이 그대로면 → "할 일 없음" 출력하고 끝.
- 상류 버전이 올랐으면 → 바뀐 스킬 파일 목록 출력. 그 파일만 새 상류에서 확인해 한국어본에 반영하고,
  스크립트가 안내하는 대로 새 기준점으로 갱신한다.

## 상류 정보

- repo: https://github.com/jame581/GodotPrompter
- 플러그인 캐시: `~/.claude/plugins/cache/skillsmith/godot-prompter/<버전>/skills/`
- 상류는 51개 스킬을 제공하지만, 우리는 2D·GDScript·데스크톱에 무관한 8개를 뺀 43개만 벤더링한다
  (뺀 목록·기준은 `CLAUDE.md` 하네스 변경 이력 세션39 참조).
