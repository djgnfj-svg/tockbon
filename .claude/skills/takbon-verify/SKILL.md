---
name: takbon-verify
description: 탁본(TAKBON) 프로젝트의 검증 규율. Godot 헤드리스 테스트를 돌리거나, 손댄 코드가 실제로 도는지 확인하거나, "테스트는 그린인데 게임이 안 된다"를 만났을 때 반드시 이 스킬을 읽어라. 헤드리스가 못 잡는 것(클릭 도달·렌더·시간 경과)·`-s` 스크립트의 침묵 통과·뮤테이션으로 검출력 증명·`push_input`으로 실게임 확인·전체 테스트 스위트 명령을 담는다. 초록불을 근거로 쓰기 전에 이 스킬을 먼저 본다.
---

# 탁본 검증 규율

이 프로젝트에서 제일 비싸게 배운 것 = **"테스트가 그린이다"는 "동작한다"가 아니다.** 세션 22·23·25·26이 전부 초록불을 믿었다가 사용자가 직접 플레이해서 버그를 찾았다. 아래는 그 반복을 막는 규율이다.

## 0. 원칙 한 줄

> **사용자가 "안 된다"고 하면 초록불보다 사용자가 옳다.** 검증이 계층을 건너뛰었을 가능성을 먼저 의심해라 (세션 25: 리드가 "발사 정상"이라고 여러 번 틀리게 말했다 — 검증이 전부 Control 계층을 우회했기 때문).

## 1. 전체 테스트 스위트 (반드시 Bash에서)

PowerShell은 자식 프로세스 stdout을 안 보여준다 — **테스트는 Bash 툴로 돌려라.**

```bash
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드 (고리 라운드트립) · 부팅만으로 자동저장 준비되나(load_game 호출 전 확인) · 세88: **시드 집합 명시 열거 3키**(개수 검사로 바꾸면 장치가 죽는다) + 시작 도안 1장·**슬롯 2·3이 비었다**
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd   # 고리 조립 계약 (세85: per-piece·칸 규칙 은퇴 — 진 Db 로드·glyph_slots 부재·은퇴 API 재발 감지)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd      # 손그림 탁본 (🔴폐지 스위치를 되돌리면 살아나는 축의 유일한 상시 그물 — 합성 밑그림 계약 포함)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd      # 고리 발사 (진→투사체·착탄·적 take_hit)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd     # 고리 도안 통합 (등급⇔펑 경계·퍼펙트)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd            # 베이스캠프 발사 배선 (물리 레이어 계약·좌클릭)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chapter_auto.gd         # 챕터 숲 루프 (스폰 두 경로·클리어 codex·extraction·bag_lost·잠금 · 세88: 배치/보상 **명시 상수 표**·상시 출구 exit+처치후 portal 둘 다·**클리어 문구를 hud.say_line으로**)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_workshop_auto.gd        # 공방 제작 (station 분리·제작·장착 라운드트립 · 세88: **해금 레시피 8장**·라이브 패널 경로·빈 id 키 없음(키 존재로 재라)·목록 사전순)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_audio_auto.gd           # 사운드 배선 (17 SFX 로드·EventBus 9종 연결)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_rune_unlock_auto.gd     # 🔴 룬 해금 (세85에 `test_decode_auto`에서 개명 — 해독대가 은퇴해 이름이 거짓이었다): **룬 6종 로드 + 6종 개별 확인**이 세50 Color 침묵사의 유일한 감지기다
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_quests_auto.gd          # 진행 목표(퀘스트) (KILL/EXTRACT/UNLOCK·requires 사슬·소급 완료)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_dialogue_box_auto.gd    # 온보딩 대사 상자 (줄 넘김·ESC 건너뛰기·ui_modal_open)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd     # 바닥 드롭 픽업 + 자석 흡수 (layer0/mask2 계약·줍기 지연·자석 반경/취소불가·1회 뱅킹 · 세88 **두루마리**: codex_unlocked 1회·가방 무변경·item_collected 안 쏨·빈 페이로드가 재호출 고리 없이 사라진다·마름모 금지 + **PNG 로드**)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd        # 몬스터 AI (방어·재생·분산 경감 · 세88 **AI leash**: 밖이면 안 오고 안이면 온다 **둘 다** + leash 뒤에도 gale 쿨다운이 돈다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd          # 룬 상태이상·원소 반응 (반응표·바람 확산·중첩 갱신)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_hud_toast_auto.gd       # HUD 획득 토스트 (같은 id 합치기+맨뒤 이동·최대3줄 FIFO·수명)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_snake_boss_auto.gd      # 뱀 보스 (Db로드·약점배율·페이즈2 전이·세그먼트 추종·위브 전진)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gale_boss_auto.gd       # gale 보스 (Db로드+17키·페이즈2·돌풍 피해/밀림·볼리 발수·적탄 히트/수명·반응 룬=BOLT/WATER)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd     # 진행 관문 (until_unlock 확정드롭/해금중단 — 세61부터 in-memory 관문 주입으로 기계를 잼·불변식 스캔은 관문 0줄 동안 자명 통과 — 정본 docs/PROGRESSION.md) · 세88 **드롭표 전수**(잡몹 5종이 어느 재료·어느 두루마리를 떨구나 · unlock_id ↔ until_unlock **병용 금지** · 대역마다 다른 고리 · 확률·수량은 F5 튜닝값이라 안 잰다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_vfx_auto.gd       # 마법 연출 배선 (세션59: vfx 연결 2종·트레일 형제 스폰+그룹 무가입·spell_impact emit 캐리어/탄 각각 — 🔴 렌더(색·펄스·자전·트레일)는 못 잡음 · [3] null 가드의 검출자는 SCRIPT ERROR grep)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_book_jin_auto.gd   # 책 진 셀 격자·아이콘 (세61 목록 편입: Db 진 ≥1·격자/아이콘 계약은 합성 8조합으로 잼)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_feel_auto.gd            # 손맛 개편 (세63: player_hurt 단일 발신+사망 가드·플래시 material per-instance·modulate 불가침·hurt 굽기·그림자·dust·카메라 킥·허수아비 파리티 — 🔴 "보인다"는 못 잡음: 세63에 그림자 가림·먼지 뭉개짐을 실게임만 잡았다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_floating_wand_auto.gd   # 떠있는 지팡이 + 발사 총구 계약 (세65: 미장착=숨김+발사 origin 몸중심 폴백·장착=지팡이 끝 muzzle_position 발사·총구 기하 단일 소스 — 🔴 둥둥/회전/flip/겉보기는 실게임만)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_layers_auto.gd       # 🔴 진별 해석 M1 — 층(밴드) 순서 = 연산 순서 (세79: 심장 = 폭발(확산(불)) 1개 큰 반경 vs 확산(폭발(불)) 3개 작은 반경 — 개수·대소 관계로만 잼(balance 수치 미기입)·빈 밴드도 층 자리 지킴·씨앗·build_assembly가 rings 다겹 실음 — 🔴 폭발이 "크게 터졌다"로 보이나는 실게임만)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_fusion_auto.gd       # 🔴 진별 해석 M2 — 룬 2개 + 융합진 (세81: 심장 = 한 발이 두 상태 → 반응(SHOCK)·자리 순서 무의존·합산 0.7×두 룬 단독합·도배 방지 enemy_hit 발신 == 1·룬 1개 회귀 완전 동일 — 🔴 룬 소켓 클릭·반응 가시성은 실게임만)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_glyph_data_auto.gd       # 🔴 문양 효과·표현 데이터화 + 응축 (세82: GlyphCode 전 9값 Db 로드·behavior/params 파싱·심장 = 응축은 폭발의 반대를 **단조성**으로(대소 비교만으론 부호 뒤집기를 못 잡는다)·계열 분기가 실제로 _apply_layer를 지나나·code 중복 결정적 승자 — 🔴 응축이 "집중 한 방"으로 보이나는 실게임만)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_scene_contract_auto.gd   # 🔴🔴 씬 계약 — mouse_filter 정적 그물 (세84 #14: 게임플레이 씬을 **스캔**해 「보이는 채로 화면 덮는 Control이면 mouse_filter==IGNORE」. **두 번 밟은 최다 재발 버그**(세25·26 — 바닥이 좌클릭 먹어 발사가 조용히 죽는데 전 스위트 그린)가 처음으로 헤드리스에 걸린다 — 실패 형태가 늘 「씬에서 그 줄이 빠진다」라서 .tscn 프로퍼티로 잴 수 있다. 씬 목록 하드코딩 안 함 = 새 씬 자동 포함. 🔴 F5의 대체가 아니라 1차 방어선)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ui_text_auto.gd          # 🔴 표시부 계약 (세84 감사 #12·#21·#35·#36 — 그전엔 그물 0건이었다): 융합 씨앗 문자열·`runes_of` 경유(표시부가 design.rune만 읽어 **두 번째 룬이 사라지던** 자리)·rune_slot_positions 정본 호출·ItemText 단일 소스 + **사본 재발 감지 스캔**·행 캡 관계식·say 수명 · 세88 **CodexText**(종류마다 안내가 다르다: 룬=진 중심·진=바탕·고리=밴드 · 획득물 아닌 키엔 문장을 안 만든다) + **count_text 사본 스캔** — 🔴 겉보기는 실게임만
```

⚠ **이 목록이 세션51에 5개 뒤처져 있었고, 세84에 또 4개 뒤처진 걸 발견했다**
(`test_jin_layers`·`test_jin_fusion`·`test_glyph_data`·`test_ui_text` — **지난 세 세션의 심장 테스트가 전부 빠져 있었다**).
정본은 CLAUDE.md의 「검증 명령」 절이다 — **새 테스트를 더하면 두 곳을 같이 갱신해라.** 목록이 갈라지면
이 스킬을 읽은 에이전트가 "전 스위트를 돌렸다"고 믿으면서 절반만 돌린다.
🔴 **세84 교훈: 이 경고가 여기 적혀 있는데도 세 세션 연속 갈라졌다** — 경고문에 의존하지 말고
**대조를 기계로 해라.** ⚠ **두 파일을 한 명령으로 돌려라** — "스킬 파일에도 같은 걸 돌려라"는 괄호
안내로 두면 그게 바로 갈라지는 자리다(세87까지 실제로 그 형태였다). 세션 종료 전 이걸 돌린다:
```bash
for d in CLAUDE.md .claude/skills/takbon-verify/SKILL.md; do
  for t in $(ls tests/*_auto.gd); do grep -q "$(basename $t)" "$d" || echo "누락 $d: $(basename $t)"; done
  grep -oE 'test_[a-z_]+_auto\.gd' "$d" | sort -u | while read n; do [ -f "tests/$n" ] || echo "유령 $d: $n"; done
done   # 출력이 비어야 한다 (누락 = 목록 뒤처짐 · 유령 = 삭제·개명된 테스트가 목록에 남음)
```

**목록에서 빠진 테스트는 낡아 죽는다** — 세션 7이 문법을 바꾸며 두 테스트가 "목록에 없다"는 이유로 조용히 깨진 채 방치됐다(세션 8에 발견). 새 테스트를 더하면 이 목록도 갱신해라.

✅ **스위트는 실세이브를 못 건드린다** (세59에 격리됐다 — 그전엔 스위트 한 번에 타이틀 「이어하기」가 사라져 사용자가 실제로 밟았다). `SaveManager`가 `-s` 부팅(헤드리스 테스트)을 감지하면 세이브 뿌리를 **`user://save_test`**로 가른다(`save_manager`의 `_save_root` 선언 + `_is_test_boot()`). 그래서 테스트의 `wipe_save()`는 **테스트 세이브만 지우는 뒷정리**다. 격리 그물 = `test_save_auto [0]`(`-s` 부팅이면 `save_root()`에 `save_test` — 격리 로직이 지워지면 여기가 빨개진다, 뮤테이션 확인됨).

🔴 **남는 진짜 주의 = 실게임은 격리가 없다.** F5·에디터 run·익스포트·MCP는 `-s`가 없어 **진짜 `user://save`를 쓴다** — 세65에 리드가 실게임 `new_game()`으로 실세이브를 덮어 실제로 날렸다. **세이브를 건드리기 전 무조건 백업해라**: `%APPDATA%/Godot/app_userdata/tockbon`(세65·85 — 세86도 이 절차로 도안 6장 실세이브를 살렸다).

## 2. 헤드리스가 못 잡는 것 (실게임으로만 확인된다)

### 2-1. "클릭이 닿는다" — `push_input` + 실게임
🔴🔴 **헤드리스는 마우스가 Control에 닿는지 모른다.** 세션 25: 화면을 덮는 `Ground`(ColorRect)의 `mouse_filter`가 기본값 **STOP**이라 바닥이 좌클릭을 다 먹어 **발사가 통째로 죽었는데 전 스위트가 그린이었다.** 에러도 경고도 없다. 리드 검증이 전부 `_fire()` 직접 호출·`attack_basic` 액션 주입이라 Control 계층을 건너뛰어 두 세션을 못 잡았고, `push_input` 테스트를 새로 써도 헤드리스에선 그냥 통과했다(렌더가 없어 히트 테스트가 실제와 다르다).

- **화면을 덮는 Control을 새로 깔았으면 `mouse_filter = 2`(IGNORE)를 적었는지 확인하고, 에디터로 띄운 실제 게임에 `viewport.push_input(InputEventMouseButton)`을 밀어 0회→1회를 확인해라.** 액션 주입은 이 버그를 못 잡는다.
- 이건 베이스만의 얘기가 아니다 — **새 씬을 만들 때마다 되살아난다**(세션 26 숲에서 재발).

### 2-2. "보인다" — MCP 스샷
헤드리스는 "존재"만 확인하고 "보인다"는 못 본다(탁본 `z_index=-1`로 안 보였던 사례). **렌더·레이아웃을 건드렸으면 에디터로 띄워 스샷으로 확인해라.** 룬 탭·`refine_panel`/`workshop_panel`/`shop_panel` 렌더 · Tab 패널 레이아웃(탭 목록의 정본은 `tab_panel.TAB_NAMES` — 지금 **4탭**, 개수를 여기 베끼지 마라) · 완성 연출(`RingBoard.play_finish()`)은 전부 스샷으로만 검증된다. ⚠ **`decode_panel`은 세85에 은퇴했다**(해독대 + q05 한 세트) — 없는 패널을 확인하러 가지 마라.

### 2-3. 소리가 난다 — 버스 라우팅
헤드리스는 오디오 드라이버가 없어 소리가 실제로 나는지 못 잡는다. `playing==true`·버스 라우팅은 에디터 실게임 exec로 확인.

### 2-4. 시간이 흐른다 — 마나 회복·DoT 틱·자동 저장
발사 연사 차단은 `fire()`를 거쳐야, **마나 회복**(`balance.mana_regen_per_sec`)·**상태이상 DoT 틱**·**자동 저장 틱**(`Clock.day_started` → SaveManager)은 시간이 흘러야 드러난다. 테스트가 우회하면 검출력 0 → 실게임 좌클릭·경과로 확인(세션 35는 이 확인을 못 해서 미검증으로 남았다). ⚠ **허기는 세58에 은퇴했다**(`game_state.gd`가 「읽는 곳이 0」이라 적어 뒀다) — 옛 예시였다.
🔴 **종료 시 저장은 이 항목의 최악 사례다**(세84): 트리거가 셋 있어도 **창 닫기 훅이 0건**이면 마을 작업이 **에러 없이 롤백**되는데 **헤드리스 검출력이 0**이다. 재는 법 = 게임만 독립 실행(`--path .`) → 실행 중 세이브 파일을 지우고 `CloseMainWindow()`(= X 버튼의 `WM_CLOSE`) → **파일이 재생성되나 + 프로세스가 실제로 죽나**(세85에 이렇게 잡았다). ⚠ 세이브를 건드리기 전 백업.

## 3. `-s` 스크립트의 침묵 통과

🔴 **`-s` SceneTree 테스트는 런타임 에러가 나도 "OK"를 찍을 수 있다.** 세션 22: `test_ring_trace_auto`가 리팩터로 옮겨간 내부 필드(`_slots`)를 더듬다 에러로 함수가 **중단**됐는데 `failures=0`이라 통과로 보였다. 세션 23 재발(`_deploy_now` 옛 인자 수).

- **grep을 `_OK`만 하지 말고 `SCRIPT ERROR`도 같이 봐라.**
- `_check`가 **실패할 때만 출력**하면 침묵이 곧 통과다 — 함수가 죽어도 조용하다.
- **테스트는 공개 API로만 검증해라.** 내부 필드(`_슬롯`)는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.

## 4. 초록불을 근거로 쓰지 마라 — 뮤테이션으로 검출력 증명

🔴🔴 **고친 코드를 일부러 되돌려 정확히 몇 개가 실패하는지 확인한다.** 세션 22·23이 전부 이 방식으로 잡았다. 세션 23의 기존 테스트 하나(`정밀도 < 0.8`)는 **옛 관대한 판정도 통과**해 검출력이 0이었다 — 그린이지만 아무것도 안 지키고 있었다.

- 규칙을 바꿨으면: 규칙을 어긴 입력을 넣어 테스트가 **빨개지는지** 봐라. 안 빨개지면 그 테스트는 그 규칙을 검증하지 않는다.

### 4-1. 🔴🔴 뮤테이션 되돌리기에 `git checkout <file>`을 쓰지 마라 (세85 — 리드가 실제로 밟았다)

그 명령은 「뮤테이션만」이 아니라 **워킹트리를 통째로 HEAD로 되돌린다.** 병렬 갈래가 도는 세션에선 그 한 줄이 **남의 미커밋 작업을 지운다**(세85에 에이전트 3갈래의 파일 3개가 날아가 재작업했다). `git restore`·`git reset`도 같다.

- 반드시 **`cp f f.bak` → 뮤테이션 → `cp f.bak f` → `rm f.bak`** + **md5 대조**로 원상복구를 증명해라.
- 🔴 더 무서운 건 **복구 뒤 전 스위트가 그대로 그린이었다는 것**이다 — 날아간 게 「아직 그물이 없는 신규 기능」이면 **초록불이 소실을 덮는다**. 즉 소실 여부를 초록불로 판정할 수 없다.

### 4-2. 🔴 뮤테이션이 **적용됐는지부터** 확인해라 (세86)

python/sed 치환이 **조용히 실패**했는데 확인을 안 해 「검출 0」이라는 **거짓 결론**을 냈다(멀쩡한 그물을 헐겁다고 판정할 뻔). 이후 `grep -c`로 적용을 확인하자 같은 자리에서 6건이 검출됐다.

- 뮤테이션 직후 **`grep -c '<바뀐 문자열>' <파일>`**로 실제로 바뀌었는지 재고 나서 테스트를 돌려라.
- 🔴 이건 세85의 「도구가 틀리면 근거가 안 된다」가 **한 세션 만에 재현**된 것이다.

### 4-3. 🔴 fail 집계를 이 프로젝트 형식으로 해라 (세85)

리드가 실패 수를 `fail=N`으로 셌는데 **이 프로젝트는 `TEST_*_OK` / `TEST_*_FAIL`로 찍는다** → 뮤테이션 3건이 전부 「검출 실패」로 보였고, 멀쩡한 그물을 헐겁다 판정하며 에이전트의 정확한 보고를 뒤집을 뻔했다. **빨간불도 도구가 틀리면 근거가 안 된다.**

### 4-4. 🔴 「결과 값이 같다」는 「같은 길로 왔다」가 아니다 (세86)

UI 갈래 뮤테이션이 **그물이 헐거워 통과**했다 — 배열(`ring_equipped`)에 **직접 대입**해도 최종 값이 같아 보여 전부 그린이었다. **`equipment_changed` 발신 횟수**를 세고서야 빨개졌다.

- 「올바른 경로를 지났나」를 재려면 값이 아니라 **신호 발신 횟수·호출 횟수**를 세라.
- ⚠ 짝: **내가 만든 검사도 틀릴 수 있다**(세86 — 아이콘 「배치 각도」 검사가 반경 의존 편차로 **거짓 빨강**을 냈다. 검사 자체가 틀렸다). 빨개졌을 때도 「무엇이 빨개졌나」를 한 번 더 확인해라.

## 5. balance 수치를 런타임에 흔들어 검증할 수 없다

🔴 GDScript는 static 함수 안의 `const BAL.프로퍼티`를 **컴파일 타임에 굳힌다**. `RP.BAL.ring_stability_min`을 0.8로 바꿔도 `RP.threshold()`는 0.65를 돌려준다(같은 인스턴스인데도, 실측 확인). 게임엔 무해하지만 테스트는 조용히 거짓 통과한다.

- 대신 **두 함수의 경계가 어긋나지 않는지 전 구간을 훑어라**(`test_ring_design_auto`의 「사용 불가⇔펑」 방식). 이것도 뮤테이션으로 검출력을 확인했다.

## 6. 채점·손맛 수치는 헤드리스로 못 검증한다

테스트가 가이드 좌표를 그대로 찍으면 이탈이 0이라 **판정 반경을 뭘로 바꾸든 정밀도 100**이다 — 그린 게 아니라 아무것도 안 잰 것이다(세션 23의 착각). 손맛(챕터 보스방 손맛·문양 손맛·판정 반경·65점 기준선·드롭률 체감·피격 손맛 수치·완성 연출이 은은한가)은 **사용자가 마우스로 직접 그려/때려 봐야** 정해진다. 리드의 흔들림 시뮬레이션도 시뮬레이션이다.

## 검증 체크리스트 (손댄 것에 해당하는 줄만)

- [ ] 관련 테스트를 Bash로 돌렸다 — `_OK`와 **`SCRIPT ERROR` 둘 다** grep (실패 집계는 **`TEST_*_FAIL`** 형식이지 `fail=N`이 아니다)
- [ ] 규칙/버그 수정이면 **뮤테이션으로 검출력** 확인 (되돌려 빨개지나)
- [ ] 🔴 뮤테이션을 **`cp f f.bak`으로 백업**하고 되돌렸다 — **`git checkout`/`restore`/`reset` 금지** + md5 대조
- [ ] 🔴 뮤테이션이 **실제로 적용됐는지 `grep -c`로 확인**하고 나서 「검출 0」이라고 말했다
- [ ] 화면 덮는 Control을 깔았으면 `mouse_filter=2` + **실게임 `push_input` 클릭 도달** 확인
- [ ] 렌더/레이아웃을 건드렸으면 **MCP 스샷** 확인
- [ ] 소리/오디오면 실게임 `playing==true` 확인
- [ ] 손맛/채점 수치면 **사용자에게 직접 해 보라고** 넘긴다 (헤드리스로 결론 내지 않는다)
- [ ] 새 테스트를 더했으면 `takbon-verify`의 스위트 목록도 갱신
