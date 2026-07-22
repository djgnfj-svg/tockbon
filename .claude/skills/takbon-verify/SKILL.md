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
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드 (고리 라운드트립) · 부팅만으로 자동저장 준비되나(load_game 호출 전 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd   # 조립 상태기계 계약
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd      # 손그림 탁본 (완성도/정밀도·펜 보정)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd      # 고리 발사 (진→투사체·착탄·적 take_hit)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd     # 고리 도안 통합 (등급⇔펑 경계·퍼펙트)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd            # 베이스캠프 발사 배선 (물리 레이어 계약·좌클릭)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chapter_auto.gd         # 챕터 보스방 루프 (세58-B, 옛 test_forest_auto 계승 — 스폰 두 경로·클리어 codex·포탈 extraction·사망 bag_lost·잠금 판정)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_workshop_auto.gd        # 공방 장비 제작 (station 분리·제작·장착 라운드트립)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_audio_auto.gd           # 사운드 배선 (17 SFX 로드·EventBus 9종 연결)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_decode_auto.gd          # 탁본 해독 (조각 소비+룬 해금)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_quests_auto.gd          # 진행 목표(퀘스트) (KILL/EXTRACT/UNLOCK·requires 사슬·소급 완료)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_dialogue_box_auto.gd    # 온보딩 대사 상자 (줄 넘김·ESC 건너뛰기·ui_modal_open)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd     # 바닥 드롭 픽업 + 자석 흡수 (layer0/mask2 계약·줍기 지연·자석 반경/취소불가·1회 뱅킹)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd        # 몬스터 AI (방어·재생·분산 경감)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd          # 룬 상태이상·원소 반응 (반응표·바람 확산·중첩 갱신)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_hud_toast_auto.gd       # HUD 획득 토스트 (같은 id 합치기+맨뒤 이동·최대3줄 FIFO·수명)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_snake_boss_auto.gd      # 뱀 보스 (Db로드·약점배율·페이즈2 전이·세그먼트 추종·위브 전진)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chest_auto.gd           # 상자 + 능동 루팅 (drops_chest 분기·loot_panel 루팅·상자 자기소멸)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gale_boss_auto.gd       # gale 보스 (Db로드+17키·페이즈2·돌풍 피해/밀림·볼리 발수·적탄 히트/수명·반응 룬=BOLT/WATER)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd     # 진행 관문 (until_unlock 확정드롭/해금중단 — 세61부터 in-memory 관문 주입으로 기계를 잼·불변식 스캔은 관문 0줄 동안 자명 통과 — 정본 docs/PROGRESSION.md)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_vfx_auto.gd       # 마법 연출 배선 (세션59: vfx 연결 2종·트레일 형제 스폰+그룹 무가입·spell_impact emit 캐리어/탄 각각 — 🔴 렌더(색·펄스·자전·트레일)는 못 잡음 · [3] null 가드의 검출자는 SCRIPT ERROR grep)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_book_jin_auto.gd   # 책 진 셀 격자·아이콘 (세61 목록 편입: Db 진 ≥1·격자/아이콘 계약은 합성 8조합으로 잼)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_feel_auto.gd            # 손맛 개편 (세63: player_hurt 단일 발신+사망 가드·플래시 material per-instance·modulate 불가침·hurt 굽기·그림자·dust·카메라 킥·허수아비 파리티 — 🔴 "보인다"는 못 잡음: 세63에 그림자 가림·먼지 뭉개짐을 실게임만 잡았다)
```

⚠ **이 목록이 세션51에 5개 뒤처져 있었다** (dialogue_box·map_panel·drop_pickup·enemy_ai·status). 정본은
CLAUDE.md의 「검증 명령」 절이다 — **새 테스트를 더하면 두 곳을 같이 갱신해라.** 목록이 갈라지면
이 스킬을 읽은 에이전트가 "전 스위트를 돌렸다"고 믿으면서 절반만 돌린다.

**목록에서 빠진 테스트는 낡아 죽는다** — 세션 7이 문법을 바꾸며 두 테스트가 "목록에 없다"는 이유로 조용히 깨진 채 방치됐다(세션 8에 발견). 새 테스트를 더하면 이 목록도 갱신해라.

⚠ **스위트를 돌리면 `user://save`가 날아간다.** `SaveManager._ready`가 저장을 살려 놔서, `extraction_success`·`bag_lost`·`day_started`를 쏘는 테스트는 진짜 세이브 파일을 쓴다. 세이브를 건드리는 테스트는 끝에 `wipe_save()`로 뒷정리하지만 — **뒷정리는 지울 뿐 복구가 아니다.** 플레이하던 세이브가 있으면 스위트가 날린다. 새 시그널을 쏘는 테스트를 더할 땐 SaveManager가 물려 있는지 먼저 확인해라.

## 2. 헤드리스가 못 잡는 것 (실게임으로만 확인된다)

### 2-1. "클릭이 닿는다" — `push_input` + 실게임
🔴🔴 **헤드리스는 마우스가 Control에 닿는지 모른다.** 세션 25: 화면을 덮는 `Ground`(ColorRect)의 `mouse_filter`가 기본값 **STOP**이라 바닥이 좌클릭을 다 먹어 **발사가 통째로 죽었는데 전 스위트가 그린이었다.** 에러도 경고도 없다. 리드 검증이 전부 `_fire()` 직접 호출·`attack_basic` 액션 주입이라 Control 계층을 건너뛰어 두 세션을 못 잡았고, `push_input` 테스트를 새로 써도 헤드리스에선 그냥 통과했다(렌더가 없어 히트 테스트가 실제와 다르다).

- **화면을 덮는 Control을 새로 깔았으면 `mouse_filter = 2`(IGNORE)를 적었는지 확인하고, 에디터로 띄운 실제 게임에 `viewport.push_input(InputEventMouseButton)`을 밀어 0회→1회를 확인해라.** 액션 주입은 이 버그를 못 잡는다.
- 이건 베이스만의 얘기가 아니다 — **새 씬을 만들 때마다 되살아난다**(세션 26 숲에서 재발).

### 2-2. "보인다" — MCP 스샷
헤드리스는 "존재"만 확인하고 "보인다"는 못 본다(탁본 `z_index=-1`로 안 보였던 사례). **렌더·레이아웃을 건드렸으면 에디터로 띄워 스샷으로 확인해라.** 룬 탭 다중셀·refine/decode 패널 렌더는 전부 스샷으로만 검증된다.

### 2-3. 소리가 난다 — 버스 라우팅
헤드리스는 오디오 드라이버가 없어 소리가 실제로 나는지 못 잡는다. `playing==true`·버스 라우팅은 에디터 실게임 exec로 확인.

### 2-4. 시간이 흐른다 — 마나/허기
발사 연사 차단은 `fire()`를 거쳐야, 허기 감소는 시간이 흘러야 드러난다. 테스트가 우회하면 검출력 0 → 실게임 좌클릭·경과로 확인(세션 35는 이 확인을 못 해서 미검증으로 남았다).

## 3. `-s` 스크립트의 침묵 통과

🔴 **`-s` SceneTree 테스트는 런타임 에러가 나도 "OK"를 찍을 수 있다.** 세션 22: `test_ring_trace_auto`가 리팩터로 옮겨간 내부 필드(`_slots`)를 더듬다 에러로 함수가 **중단**됐는데 `failures=0`이라 통과로 보였다. 세션 23 재발(`_deploy_now` 옛 인자 수).

- **grep을 `_OK`만 하지 말고 `SCRIPT ERROR`도 같이 봐라.**
- `_check`가 **실패할 때만 출력**하면 침묵이 곧 통과다 — 함수가 죽어도 조용하다.
- **테스트는 공개 API로만 검증해라.** 내부 필드(`_슬롯`)는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.

## 4. 초록불을 근거로 쓰지 마라 — 뮤테이션으로 검출력 증명

🔴🔴 **고친 코드를 일부러 되돌려 정확히 몇 개가 실패하는지 확인한다.** 세션 22·23이 전부 이 방식으로 잡았다. 세션 23의 기존 테스트 하나(`정밀도 < 0.8`)는 **옛 관대한 판정도 통과**해 검출력이 0이었다 — 그린이지만 아무것도 안 지키고 있었다.

- 규칙을 바꿨으면: 규칙을 어긴 입력을 넣어 테스트가 **빨개지는지** 봐라. 안 빨개지면 그 테스트는 그 규칙을 검증하지 않는다.

## 5. balance 수치를 런타임에 흔들어 검증할 수 없다

🔴 GDScript는 static 함수 안의 `const BAL.프로퍼티`를 **컴파일 타임에 굳힌다**. `RP.BAL.ring_stability_min`을 0.8로 바꿔도 `RP.threshold()`는 0.65를 돌려준다(같은 인스턴스인데도, 실측 확인). 게임엔 무해하지만 테스트는 조용히 거짓 통과한다.

- 대신 **두 함수의 경계가 어긋나지 않는지 전 구간을 훑어라**(`test_ring_design_auto`의 「사용 불가⇔펑」 방식). 이것도 뮤테이션으로 검출력을 확인했다.

## 6. 채점·손맛 수치는 헤드리스로 못 검증한다

테스트가 가이드 좌표를 그대로 찍으면 이탈이 0이라 **판정 반경을 뭘로 바꾸든 정밀도 100**이다 — 그린 게 아니라 아무것도 안 잰 것이다(세션 23의 착각). 손맛(원정 손맛·문양 손맛·판정 반경·65점 기준선·드롭률 체감·피격 손맛 수치)은 **사용자가 마우스로 직접 그려/때려 봐야** 정해진다. 리드의 흔들림 시뮬레이션도 시뮬레이션이다.

## 검증 체크리스트 (손댄 것에 해당하는 줄만)

- [ ] 관련 테스트를 Bash로 돌렸다 — `_OK`와 **`SCRIPT ERROR` 둘 다** grep
- [ ] 규칙/버그 수정이면 **뮤테이션으로 검출력** 확인 (되돌려 빨개지나)
- [ ] 화면 덮는 Control을 깔았으면 `mouse_filter=2` + **실게임 `push_input` 클릭 도달** 확인
- [ ] 렌더/레이아웃을 건드렸으면 **MCP 스샷** 확인
- [ ] 소리/오디오면 실게임 `playing==true` 확인
- [ ] 손맛/채점 수치면 **사용자에게 직접 해 보라고** 넘긴다 (헤드리스로 결론 내지 않는다)
- [ ] 새 테스트를 더했으면 `takbon-verify`의 스위트 목록도 갱신
