#!/usr/bin/env bash
# godot-prompter 상류 대조 스크립트 (한 달에 한 번 실행)
#
# 우리 .claude/skills/의 제네릭 스킬은 godot-prompter 상류를 번역한 사본이다.
# 번역하는 순간 영어 원본과 갈라지므로, 상류가 바뀌었는지 주기적으로 대조한다.
#   - 상류 버전이 그대로면: 할 일 없음.
#   - 상류 버전이 올랐으면: 어느 스킬 파일이 바뀌었는지 출력 → 그 파일만 다시 번역.
#
# 원리: skill-vendor/upstream-<VERSION>/ 에 번역 당시의 "영어 원본"을 박제해 뒀다.
#       새 상류(플러그인 캐시)와 이 박제본을 diff 하면 = 상류가 실제로 바꾼 부분.
#       (우리 한국어 skills/ 와 비교하면 번역 때문에 전부 다르게 나와 쓸모없다 — 박제본과 비교해야 한다.)

set -euo pipefail

VENDOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_VERSION="$(cat "$VENDOR_DIR/VERSION")"
BASELINE="$VENDOR_DIR/upstream-$BASE_VERSION/skills"   # 우리가 이 안에 skills 없이 바로 스킬을 두면 아래에서 보정
[ -d "$BASELINE" ] || BASELINE="$VENDOR_DIR/upstream-$BASE_VERSION"

# 1) 설치된 godot-prompter 상류 위치·버전 찾기
CACHE="$HOME/.claude/plugins/cache/skillsmith/godot-prompter"
if [ ! -d "$CACHE" ]; then
  echo "⚠ 상류 캐시를 못 찾음: $CACHE"
  echo "  → godot-prompter 플러그인이 설치돼 있어야 대조 가능. (repo: https://github.com/jame581/GodotPrompter)"
  exit 2
fi
UP_VERSION="$(ls -1 "$CACHE" | sort -V | tail -1)"
UP_SKILLS="$CACHE/$UP_VERSION/skills"

echo "기준 번역 버전 : $BASE_VERSION"
echo "설치된 상류    : $UP_VERSION"
echo ""

if [ "$UP_VERSION" = "$BASE_VERSION" ]; then
  echo "✅ 상류가 그대로다 ($BASE_VERSION). 번역 다시 볼 것 없음."
  exit 0
fi

echo "🔔 상류가 올랐다: $BASE_VERSION → $UP_VERSION"
echo "   아래 파일이 상류에서 바뀌었다 = 우리 한국어본에 반영할 후보:"
echo ""

# 2) 박제본(영어 기준) vs 새 상류 diff — 우리가 가진 43개 스킬만 대상
changed=0; added=0; removed=0
for d in $(ls -1 "$BASELINE"); do
  base_skill="$BASELINE/$d"
  up_skill="$UP_SKILLS/$d"
  if [ ! -d "$up_skill" ]; then
    echo "  [삭제됨] $d — 상류에서 사라짐"
    removed=$((removed+1)); continue
  fi
  # 파일 단위 diff
  while IFS= read -r f; do
    rel="${f#$base_skill/}"
    if [ ! -f "$up_skill/$rel" ]; then
      echo "  [파일삭제] $d/$rel"
    elif ! diff -q "$f" "$up_skill/$rel" >/dev/null 2>&1; then
      echo "  [변경] $d/$rel"
      changed=$((changed+1))
    fi
  done < <(find "$base_skill" -name '*.md')
  # 상류에 새로 생긴 파일
  while IFS= read -r f; do
    rel="${f#$up_skill/}"
    [ -f "$base_skill/$rel" ] || { echo "  [파일추가] $d/$rel"; added=$((added+1)); }
  done < <(find "$up_skill" -name '*.md')
done

echo ""
echo "요약: 변경 $changed · 추가 $added · 삭제 $removed"
echo ""
echo "다음 할 일:"
echo "  1) 위 [변경]/[추가] 파일을 새 상류($UP_SKILLS/<파일>)에서 확인"
echo "  2) 바뀐 부분만 우리 .claude/skills/<스킬>/ 한국어본에 반영"
echo "  3) 반영 끝나면 새 기준점으로 갱신:"
echo "       cp -r <새 영어 스냅샷> $VENDOR_DIR/upstream-$UP_VERSION/"
echo "       echo '$UP_VERSION' > $VENDOR_DIR/VERSION"
echo "       rm -rf $VENDOR_DIR/upstream-$BASE_VERSION   # 옛 박제본 정리"
