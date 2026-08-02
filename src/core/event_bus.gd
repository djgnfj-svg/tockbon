extends Node
## 모듈 간 시그널 허브 — 유일한 교차 모듈 통신 경로.
## 시그널 추가·변경은 리드만.
##
## ⚠ **죽은 시그널을 남겨 두지 마라** — 시그니처의 타입이 그 스키마를 붙들어 못 지우게 만든다.

@warning_ignore_start("unused_signal")

# ── 고리 조립 캐스팅 — 지금의 유일한 발사 경로
# 🔴 assembly 사전을 싣는다. **생산자는 `RingDesign.to_assembly()` 하나**다 — 직접 Dictionary를
# 만들어 emit하면 `score`가 빠져 **조용히 기준 위력**으로 나간다.
# 키: ring_count · rune(primary) · runes(목록) · jin · rings(층 배열)
#   · open · score · ink · special_ink · special_ratio · size.
signal ring_cast_requested(assembly: Dictionary, origin: Vector2, aim_dir: Vector2)

## 시전이 **시작됐다**. `ring_cast_requested`가 "탄이 나간다"라면 이건 "발밑이 열린다"다 —
## 사이에 `duration`초가 흐른다: 좌클릭 → 가드 → 마나 차감 → 이 신호 → 대기 → ring_cast_requested.
## 🔴 왜 갈랐나: `ring_cast_requested` 수신자가 넷(발사·머즐VFX·반동·발사음)이라 시전 시작에 그걸
## 쏘면 즉시 탄이 나가 시전 시간이 무의미해지고, 완료 후에만 쏘면 바닥 마법진을 열 주체가 없다.
## 🔴 `origin`은 `player_caster._muzzle()`과 **같은 값이어야 한다**(총구 단일 소스).
## ⚠ `assembly`는 시작 시점의 **스냅샷**이다 — 시전 중 슬롯을 바꿔도 이 사전과 나가는 탄이 같아야 한다.
## ⚠ **취소되면 `ring_cast_requested`가 안 온다**(구르기·모달·씬 전환) — 수신자는 "열었으면 반드시
## 닫힌다"를 가정하지 마라. 마나는 취소돼도 태운다.
signal ring_cast_started(assembly: Dictionary, origin: Vector2, duration: float)

## 시전이 **끊겼다** — 위 신호로 연 것을 되돌린다(바닥 마법진 제거·차징음 정지).
## ⚠ 이게 없으면 시전은 끊겼는데 발밑 원만 남아 "쐈는데 안 나갔다"가 된다.
signal ring_cast_canceled()
# 고리 도안이 맺혔다 (조립 책 → GameState).
# GameState가 수신 → ring_designs에 넣고 빈 ring_equipped 슬롯에 즉시 장착.
signal ring_design_committed(design: RingDesign)

# ── 전투
signal enemy_hit(enemy: Node2D, damage: float, rune_type: int)
## 적이 죽었다 — `forest_enemy._die`가 발신, GameState가 KILL 퀘스트를 센다.
## enemy_hit(매 타격)과 다르다 — 이건 **처치 순간 1회**다.
signal enemy_died(enemy_id: StringName)
## hp가 변했다 — 발신은 `game_state`의 new_game·_after_equipment_changed·damage_player·
## heal_player·reset_player_hp와 `save_manager.load_game`, 수신은 HUD와 `boss_room`(사망 판정)이다.
signal player_hp_changed(hp: float, hp_max: float)
## 플레이어가 **피해를 입었다** — `player_hp_changed`("hp가 변했다")와 다르다.
## `damage_player` 한 곳만 쏘는 1급 사건이라 회복·출격 만HP·장비 클램프에는 안 울린다
## (그래서 수신자에 오발 가드가 필요 없다).
## source_pos = 가해자 월드 좌표. ⚠ 방향을 모르는 피해는 `Vector2(INF, INF)` 센티널이라
## 수신자는 `is_finite()`로 가드해야 한다.
signal player_hurt(amount: float, source_pos: Vector2)

# ── 귀환·사망
## 발신은 `boss_room._extract`(귀환)·`boss_room._die`(사망) 둘, 수신은 각 3곳이다:
##   `game_state`(가방 정산·소실) · `save_manager`(자동 저장 — 세이브스컴 방지) · `audio`(소리).
## ⚠ 새 무대를 붙이는 쪽이 이 둘을 emit해야 한다 — 안 쏘면 **조용히** 정산도 저장도 안 된다.
signal extraction_success
signal bag_lost

# ── 시간 (Clock → 전체)
## `day_started` 수신 = `save_manager`의 **자동 저장 틱**(clock.gd 머리말).
signal phase_changed(phase: int)
signal day_started(day: int)

# ── 도감 해금 (누구든 범용 해금)
signal codex_unlocked(unlock_id: StringName)

# ── 퀘스트
## GameState가 목표를 완료했을 때 발신 → 퀘스트 패널 갱신·HUD 알림·사운드.
signal quest_completed(quest_id: StringName)
## 진행 카운트가 늘었을 때 (완료 아님) — 패널이 열려 있으면 진행 막대를 다시 그린다.
signal quest_advanced(quest_id: StringName)
## 목표를 방금 채웠다 — 아직 완료는 아니다. 문으로 돌아가 정산하라는 신호.
## HUD가 넛지를 띄우고 문 위 물음표가 켜진다. 완료는 `claim_ready_quests()`에서만 난다.
signal quest_ready(quest_id: StringName)
## 새 목표를 "읽었다" — 시트(Tab 퀘스트 탭)를 열어 접수하면 발신. [!] 표시를 끄러 base가 받는다.
signal quests_seen

# ── 자원·장비 (GameState → 전체)
## 🔴 `resources_changed`는 **UI 갱신 전용**이다 — 저장 트리거로 쓰지 마라. `add_to_bag`(원정 중
## 드롭)도 같이 쏘는데 가방은 애초에 저장 대상이 아니라(사망 시 소실이 설계) 드롭마다 세이브 +
## 도안 `.tres` 전량을 다시 쓰게 된다. 저장 트리거는 아래 `inventory_changed`다.
## ⚠ 수신자가 여섯이다(hud·tab_panel·ring_forge_panel·refine_panel·workshop_panel·shop_panel) —
##  걷으면 잉크 팔레트·정제대·공방·상점·HUD·Tab 갱신이 한 번에 멎는다.
signal resources_changed
## 🔴 **창고(영구)가 증감했다** — `add_item`·`remove_item` 두 곳만 발신한다. 즉 제작·상점·퀘스트
## 보상·귀환 정산이 실리고 `add_to_bag`(가방)은 안 실린다. 수신 = `save_manager`(자동 저장).
## 🔴 UI 갱신에 이 신호를 쓰지 마라 — 가방만 바뀌는 순간(원정 중 드롭)엔 안 울려 화면이 멎는다.
##  **두 신호의 차이는 「무엇을 다시 그리나」가 아니라 「무엇이 영구인가」다.**
## ⚠ `load_game`·`new_game`은 이 신호를 일부러 안 쏜다 — 복원은 변경이 아니다.
signal inventory_changed
## 🔴 자동 저장 트리거이기도 하다 — 장비 변경에서 이 신호를 빼먹으면 화면만 안 갱신되는 게
## 아니라 **진행이 저장되지 않는다.** 수신 5곳(hud·tab_panel·workshop_panel·audio·save_manager).
signal equipment_changed
## 바닥 픽업이 플레이어에게 흡수돼 가방에 들어갔다 — `drop_pickup`이 **도착 순간 1회** 발신한다.
## `resources_changed`("내용이 변했다")와 다르다 — 이건 "방금 이게 도착했다"는 연출용 이벤트다.
## ⚠ 창고 입고·제작 소비·정산은 이 신호를 쓰지 마라 — 쓰면 제작할 때마다 획득 토스트가 뜬다.
signal item_collected(item_id: StringName, count: int)

# ── 원소 반응 VFX — 몸(forest_enemy·dummy_target)이 방송, src/actors/vfx.gd가 그린다.
## 🔴 연출용 순수 오버레이다 — 게임 로직은 이 신호를 **안 본다**(반응 판정·피해는 이미 끝났다).
## pos·from·to는 전부 월드 전역 좌표. status = Enums.Status(색은 VFX가 `SR.tint_of`로 되쓴다).
## ⚠ 발신자가 몸 두 곳으로 갈려 있으니, 한쪽만 고치면 연습장↔숲에서 연출이 조용히 갈라진다.
## radius = 실제 게임플레이 반경(감전연쇄/증기 px). status=결과 상태(NONE=증기·SHOCK=감전).
signal reaction_burst(pos: Vector2, radius: float, status: int)
## 상태가 A→B로 튀었다(감전 연쇄 한 가닥 · 바람 확산 한 가닥). 대상마다 1회.
signal reaction_chain(from: Vector2, to: Vector2, status: int)

# ── 착탄 연출 — 탄(ring_carrier·projectile)이 방송, src/actors/vfx.gd가 그린다.
## 🔴 연출용 순수 오버레이다 — 게임 로직은 안 본다(reaction_burst와 같은 규약).
## "탄이 적에 박혔다"는 사건이라 `enemy_hit`("피해가 들었다")과 **다르다** — enemy_hit은 기둥 틱·
## 반응 피해도 쏴서 버스트 도배가 된다. 적 착탄 순간 1회만 쏜다(관통 탄은 뚫는 적마다 1회 = 의도).
## ⚠ 벽·수명 소멸·기둥 틱·DoT 틱에는 쏘지 않는다. pos = 월드 전역 좌표.
## `score`(0.70~1.0)를 싣는 이유 — 없으면 착탄 데칼·플레어가 모든 등급에서 똑같이 난다.
## ⚠ **GDScript 시그널 파라미터엔 기본값이 없다** — 시그니처를 고치면 emit 3곳
## (`ring_carrier`·`projectile`·**`tools/vfx_shot.gd`**)과 수신을 전부 같이 고쳐야 한다.
##  `tools/vfx_shot.gd`를 빠뜨리면 이 축의 검증 도구가 죽는다.
signal spell_impact(pos: Vector2, rune_type: int, score: float)

# ── 설정 (Audio → UI)
## 음소거 상태가 바뀌었다. Audio가 소유·저장하고 발신 → HUD 표시·타이틀 버튼이 갱신.
signal audio_muted_changed(muted: bool)
