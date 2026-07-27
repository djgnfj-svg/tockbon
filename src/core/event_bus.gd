extends Node
## 모듈 간 시그널 허브 — 유일한 교차 모듈 통신 경로.
## 시그널 추가·변경은 리드만.
##
## ⚠ **죽은 시그널을 남겨 두지 마라** — 시그니처의 타입이 그 스키마를 붙들어 못 지우게 만든다
## (세22에 옛 SpellDesign 시그널 17종을 매장한 이유. 경위 = docs/STATUS.md 「세션 22」·git 이력).

@warning_ignore_start("unused_signal")

# ── 고리 조립 캐스팅 (세션 12~) — 지금의 유일한 발사 경로
# 🔴 assembly 사전을 싣는다. **생산자는 `RingDesign.to_assembly()` 하나**이고, 쏘는 자리도
# `player_caster.fire()` 한 곳이다(세86 실측) — 직접 Dictionary를 만들어 emit하면 `score`가
# 빠져 **조용히 기준 위력**으로 나간다(세26 계약).
# 키(세81 M2·세79 M1 기준): ring_count · rune(primary) · runes(목록) · jin · rings(**층 배열**)
#   · open · score · ink · special_ink · special_ratio · size.
# ring_spell_system(모듈 B)이 수신 → 진(캐리어)을 조준 방향으로 쏜다.
signal ring_cast_requested(assembly: Dictionary, origin: Vector2, aim_dir: Vector2)

## 🔴 시전이 **시작됐다** (세98 — 정본 = docs/takbon-design/spell_cast_visual_design.md).
## `ring_cast_requested`가 "탄이 나간다"라면 이건 "발밑이 열린다"다 — 사이에 `duration`초가 흐른다.
##   좌클릭 → 가드(빈 슬롯·마나) → 마나 차감 → **이 신호** → duration 대기 → ring_cast_requested
## 🔴 **왜 갈랐나**: `ring_cast_requested` 수신자가 넷(발사·머즐VFX·반동·발사음)이라, 시전 시작에
## 그걸 쏘면 `ring_spell_system`이 **즉시 탄을 쏴** 시전 시간이 무의미해진다. 그렇다고 완료 후에만
## 쏘면 그 전엔 아무도 몰라 **바닥 마법진을 열 주체가 없다**.
## 🔴 `origin`은 `player_caster._muzzle()`과 **같은 값이어야 한다** — 총구 단일 소스(세65)가
## 시전 시작에서만 갈라지면 그게 세65가 막으려던 병이다.
## ⚠ `assembly`는 **시작 시점의 스냅샷**이다 — 시전 중 슬롯을 바꿔도 이 사전과 나가는 탄이 같아야
## 한다(그린 것 ≠ 나가는 것 방지). 생산자는 여기서도 `to_assembly()` 하나다.
## ⚠ **취소되면 `ring_cast_requested`가 안 온다**(구르기·모달·씬 전환) — 수신자는 "열었으면 반드시
## 닫힌다"를 가정하지 마라. 마나는 취소돼도 태운다.
signal ring_cast_started(assembly: Dictionary, origin: Vector2, duration: float)

## 🔴 시전이 **끊겼다** — 위 신호로 연 것을 되돌린다(바닥 마법진 제거·차징음 정지).
## 발신은 `player_caster` 한 곳. ⚠ 이게 없으면 시전은 끊겼는데 발밑 원만 남아 "쐈는데 안 나갔다"가 된다.
signal ring_cast_canceled()
# 🔴 #17 1단계 — 고리 도안이 맺혔다 (베이스캠프 조립 책 → GameState).
# GameState가 수신 → ring_designs에 넣고 빈 ring_equipped 슬롯에 즉시 장착.
signal ring_design_committed(design: RingDesign)

# ── 전투 (B ↔ C)
signal enemy_hit(enemy: Node2D, damage: float, rune_type: int)
## 🔴 적이 죽었다 (세션 36). forest_enemy._die가 발신 → GameState가 KILL 퀘스트를 센다.
## enemy_hit(매 타격)과 다르다 — 이건 **처치 순간 1회**다. 세션 26 forest_enemy의 `died`
## 로컬 시그널("킬카운트가 붙는 날의 자리표")이 마침내 수신자를 얻은 것이다.
signal enemy_died(enemy_id: StringName)
## 🔴 hp가 변했다 — **양쪽이 다 붙어 있다**(세84 감사 #28에 실측 갱신. 옛 주석은 *"발신자 없음"*이라
## 적어 두고 다음 문장과 자기모순이었다 — 세21에 HUD가 삭제됐던 시절의 유물이다).
## ⚠ 아래 목록은 **함수 이름**으로 적는다 — 줄 번호는 코드와 함께 늙어 다시 거짓이 된다(감사 T4).
##   발신 6곳: `game_state`의 `new_game`·`_after_equipment_changed`·`damage_player`·`heal_player`·
##             `reset_player_hp` · `save_manager.load_game`(복원된 로브 상한 기준 만HP)
##   수신 2곳: `hud._on_hp_changed`(HP 막대) · `boss_room._on_hp_changed`(사망 판정)
signal player_hp_changed(hp: float, hp_max: float)
## 🔴 플레이어가 **피해를 입었다** (세션63 손맛). `player_hp_changed`("hp가 변했다")와 다르다 —
## 이건 damage_player 한 곳만 발신하는 1급 사건이라, 수신자(juice 방향성 킥·player 피격 애니·
## audio 아픔음)가 "직전값 비교로 감소를 추측"하던 사본들을 대체한다. 회복·출격 만HP·장비 클램프는
## 이 신호를 **안 쏜다**(그래서 오발 가드가 필요 없다). source_pos = 가해자 월드 좌표 —
## 방향성 카메라 킥이 쓴다. 방향을 모르는 피해는 Vector2(INF, INF) 센티널(수신자는 is_finite() 가드).
signal player_hurt(amount: float, source_pos: Vector2)

# ── 익스트랙션 (C → D·E)
## 🔴 **세58-B에 발신자가 붙었다 — 이제 양쪽이 다 산다**(세84 감사 #28에 실측 갱신. 옛 주석은
## *"발신자 없음 = 필드가 아직 없어서"*라 적혀 있었는데, 그 서술을 믿고 귀환·사망 경로를 옮기면
## **가방 정산과 자동 저장이 두 번 돈다**).
##   발신: `boss_room._extract`(포탈 귀환) · `boss_room._die`(사망) — 챕터 보스방이 유일한 무대다.
##   수신 각 3곳: `game_state._ready`(가방 정산·가방 소실) · `save_manager._ready`
##                (자동 저장 — 세이브스컴 방지) · `audio._ready`(귀환·사망 소리).
## ⚠ 새 무대(필드·던전)를 붙이는 쪽이 이 둘을 emit해야 한다 — 안 쏘면 **조용히** 정산도 저장도 안 된다.
signal extraction_success
signal bag_lost

# ── 시간 (Clock → 전체)
## ⚠ 목록은 **함수 이름**으로 (줄 번호는 코드와 함께 늙는다, 감사 T4). 세86 실측:
##   `phase_changed` 수신 1곳 = `audio._on_phase`(아침·밤 전환음만).
##   `day_started` 수신 1곳 = `save_manager._ready`의 람다 = **자동 저장 틱**(clock.gd 머리 주석).
signal phase_changed(phase: int)
signal day_started(day: int)

# ── 도감 해금 (누구든 범용 해금)
signal codex_unlocked(unlock_id: StringName)

# ── 퀘스트 (진행 목표 = 깊이 스파인, 세션 36)
## GameState가 목표를 완료했을 때 발신 → 퀘스트 패널 갱신·HUD 알림·사운드. quest_id로 무엇이 끝났는지.
signal quest_completed(quest_id: StringName)
## 진행 카운트가 늘었을 때 (완료 아님) — 패널이 열려 있으면 진행 막대를 다시 그린다.
signal quest_advanced(quest_id: StringName)
## 🔴 목표를 방금 채웠다 (세40 턴인) — 아직 완료는 아니다. 문으로 돌아가 정산하라는 신호.
## HUD가 "달성! 돌아가라" 넛지를 띄우고, 문 위 물음표가 켜진다. 완료는 claim_ready_quests()에서만.
## ⚠ 세95에 화자가 길잡이NPC → 문으로 옮겨졌다(마을에 사람이 없다 — 정본 = world_and_visual_design.md §2).
signal quest_ready(quest_id: StringName)
## 🔴 새 목표를 "읽었다" (세션43) — 시트(Tab 퀘스트 탭)를 열어 접수하면 발신. NPC 머리 위 [!]를 끄러
## base가 _refresh_npc_mark로 받는다. [!] = 아직 안 읽은 active 목표(has_new_quest) → 시트 열람이 끈다.
signal quests_seen

# ── 자원·장비 (GameState → 전체)
## 🔴🔴 **둘 다 수신자가 많다 — 걷으면 UI가 한 번에 죽는다**(세84 감사 #28에 실측 갱신).
## 옛 주석은 *"둘 다 발신만 있고 수신자 0"*이라 적어 놨는데(세21 HUD 삭제 시절의 유물),
## 그걸 믿고 지우면 **잉크 팔레트·정제대·공방·상점·HUD·Tab 갱신이 통째로 멎는다.**
## ⚠ 목록은 **함수 이름**으로 적는다 — 줄 번호는 코드와 함께 늙어 다시 거짓이 된다(감사 T4).
##   `resources_changed` 발신 5곳: `game_state`의 `new_game`·`add_item`·`remove_item`·**`add_to_bag`**
##                                 · `save_manager.load_game`
##     수신 6곳: `hud` · `tab_panel` · `ring_forge_panel`(잉크 팔레트) · `refine_panel`
##               · `workshop_panel` · `shop_panel`
##   `equipment_changed` 발신 3곳: `game_state.new_game`·`game_state._after_equipment_changed`
##                                 · `save_manager.load_game`
##     수신 5곳: `hud` · `tab_panel` · `workshop_panel` · `audio` · 🔴 `save_manager._queue_save`(자동 저장)
## 🔴 세84 #1: **`equipment_changed`는 이제 자동 저장 트리거다** — 장비 변경에서 이 신호를 빼먹으면
##   화면만 안 갱신되는 게 아니라 **진행이 저장되지 않는다.**
## 🔴🔴 `resources_changed`는 **저장 트리거로 쓰지 마라** — `add_to_bag`(원정 중 드롭)도 같이 쏘는데
##   가방은 애초에 저장 대상이 아니다(사망 시 소실이 설계). 세86 ⑫에 신호를 갈랐다:
##   저장 트리거는 아래 `inventory_changed`이고, 이 신호는 **UI 갱신 전용**이다(가방 구역도
##   같이 다시 그려야 하므로 수신 6곳 무변경).
signal resources_changed
## 🔴🔴 **창고(영구)가 증감했다** (세86 ⑫ 신설) — `add_item`·`remove_item` **두 곳만** 발신한다.
## 즉 제작·상점·퀘스트 보상·귀환 정산이 여기 실리고, **`add_to_bag`(가방)은 안 실린다.**
##   수신: `save_manager._ready`(자동 저장 트리거) — UI는 여전히 `resources_changed`를 본다.
## 🔴 **UI 갱신에 이 신호를 쓰지 마라**: 가방만 바뀌는 순간(원정 중 드롭)엔 안 울려 화면이 멎는다.
##   반대로 저장에 `resources_changed`를 쓰면 드롭마다 세이브 + 도안 .tres 전량을 다시 쓴다.
##   **두 신호의 차이는 「무엇을 다시 그리나」가 아니라 「무엇이 영구인가」다.**
## ⚠ `save_manager.load_game`·`new_game`은 이 신호를 **일부러 안 쏜다** — 복원은 변경이 아니다.
signal inventory_changed
signal equipment_changed
## 🔴 바닥 픽업이 플레이어에게 흡수돼 가방에 들어갔다 (세션51). drop_pickup이 **도착 순간 1회** 발신.
## HUD가 획득 토스트를 띄운다. `resources_changed`(가방/창고 내용이 변했다)와 **다르다** — 이건
## "방금 이게 도착했다"는 연출용 이벤트다. 무엇이 얼마나 들어왔는지가 실린다.
## ⚠ 창고 입고·제작 소비·정산은 이 신호를 쓰지 않는다 — 쓰면 공방에서 제작할 때마다 토스트가 뜬다.
signal item_collected(item_id: StringName, count: int)

# ── 원소 반응 VFX (세션52) — 몸(forest_enemy·dummy_target)이 방송, src/actors/vfx.gd가 그린다.
## 🔴 연출용 순수 오버레이다 — 게임 로직은 이 신호를 **안 본다**(퀘스트처럼 관찰만). 반응 판정·피해는
## 이미 status_holder/몸이 다 했고, 이 신호는 "어디서·어디로 뭐가 터졌나"를 VFX에만 알린다.
## pos·from·to는 전부 **월드 전역 좌표**. status = Enums.Status(색은 VFX가 SR.tint_of로 되쓴다 —
## 상태 색 단일 소스 재사용). 발신자는 forest_enemy·dummy_target의 `_burst_damage`·`_spread_statuses`.
## ⚠ 발신자가 몸 두 곳으로 갈려 있으니, 한쪽만 고치면 연습장↔숲에서 연출이 조용히 갈라진다.
## 반응이 한 자리에서 터졌다(면적). radius = 실제 게임플레이 반경(감전연쇄/증기 px). status=결과 상태(NONE=증기·SHOCK=감전).
signal reaction_burst(pos: Vector2, radius: float, status: int)
## 상태가 A→B로 튀었다(감전 연쇄 한 가닥 · 바람 확산 한 가닥). 대상마다 1회. 색은 status로 갈린다.
signal reaction_chain(from: Vector2, to: Vector2, status: int)

# ── 착탄 연출 (세션59) — 탄(ring_carrier·projectile)이 방송, src/actors/vfx.gd가 그린다.
## 🔴 연출용 순수 오버레이다 — 게임 로직은 이 신호를 **안 본다** (reaction_burst 규약과 동일).
## "탄이 적에 박혔다"는 사건 — `enemy_hit`("피해가 들었다")과 **다르다**: enemy_hit은 기둥 틱·반응
## 피해도 쏴서 버스트 도배가 된다(DoT 도배 함정의 사촌). 발신은 적 착탄 순간 1회
## (ring_carrier._hit_enemy · projectile._deal_damage — 관통 탄은 뚫는 적마다 1회 = 의도).
## ⚠ 벽·수명 소멸·기둥 틱·DoT 틱에는 쏘지 않는다. pos = 월드 전역 좌표.
## 🔴 세98: **`score`를 싣는다**(0.70~1.0 = `assembly.score`) — 그 전엔 착탄이 "얼마나 센 마법진이었나"를
## 몰라 데칼·플레어가 **모든 등급에서 똑같이** 났다(조립의 결과가 화면에 0이던 병의 착탄 쪽 절반).
## 나르는 길 = `ring_spell_system`이 `status_mult`를 캐리어에 실어 착탄까지 들고 가는 **그 선례**.
## ⚠ **GDScript 시그널 파라미터엔 기본값이 없다** — emit·수신을 전부 같이 고쳐야 한다.
## 🔴 emit 3곳(`ring_carrier`·`projectile`·**`tools/vfx_shot.gd`**) · 수신 3곳(`vfx._on_spell_impact`·
## `test_spell_vfx_auto`의 람다 둘). **`tools/vfx_shot.gd`를 빠뜨리면 이 작업의 검증 도구가 죽는다.**
signal spell_impact(pos: Vector2, rune_type: int, score: float)

# ── 설정 (Audio → UI)
## 🔴 음소거 상태가 바뀌었다 (설정). Audio가 소유·저장하고 발신 → HUD 표시·타이틀 버튼이 갱신.
signal audio_muted_changed(muted: bool)
