extends Control
## 플레이어 HUD — 장착한 고리 마법진 슬롯(진 미니 다이어그램) + HP·마나 막대 + 획득 토스트.
##
## 🔴 **마을(base)과 보스방이 같은 HUD를 쓴다** (세션 26에 공용화 — 세션 25까지 `src/base/base_hud.gd`였다).
## 세64부터 씬별 차이가 **하나도 없다**(HP도 늘 그린다). ⚠ 옛 숲 씬은 세58-B에 은퇴했다 —
## 이 HUD를 인스턴스하는 씬은 `base.tscn`·`boss_room.tscn` **둘뿐**이다.
##
## 🔴 **세션64 정리** (사용자: "HP 바랑 스킬 등을 좀 더 깔끔하게, 화면에 글자가 너무 많음"):
##   ① 좌상단 조작 안내문(hint_text) **통째로 제거** — 온보딩 대사가 조작을 가르치니 HUD에선 뺀다.
##   ② HP·마나 **숫자를 막대 안쪽으로** 넣고 옆에 붙던 "HP 68 / 80" 별도 텍스트를 없앴다.
##   ③ 슬롯은 칸마다 이름·위력을 적지 않고 **진 미니 다이어그램**(원+열린 칸 점)만 그린다.
##      **선택된 슬롯의 이름·위력 한 줄만** 슬롯 위에 뜬다 — 화면 글자를 크게 줄였다.
##   ④ 톤을 세62 책 UI(양피지·먹·가죽)와 맞췄다 — 색만. HUD는 게임 위 오버레이라 반투명 유지.
##
## 🔴 위력을 **직접 계산하지 않는다** — `RingPower.power_display()`를 부른다. 조립 리포트·발사·HUD가
## 같은 함수를 봐야 한다 (src/core/ring_power.gd 주석): 복사해 두면 한쪽만 고쳐도 아무도 못 알아채고
## 갈라진다 — HUD는 "위력 140"이라 적어 놓고 130으로 때리는 식으로.
##
## 🔴 슬롯 미니 다이어그램의 칸 각도는 `RingBoard.jin_slot_dots`(static·순수 기하)를 쓴다 —
## "칸 0=위·시계방향" 규약(`slot_angle`)의 단일 소스다(세션60). 식을 베끼면 **같은 함수를 쓰는
## 다른 소비자와 조용히 어긋난다** — 실측 소비자는 이 파일(`_draw_jin_diagram`)과
## `tab_panel._draw_magic_diagram` **둘뿐**이다(+ `test_ring_assembly_auto`의 그물).
## ⚠ **책의 진 셀은 이제 이 함수를 안 쓴다** — 세83에 셀이 「진 모양 + 룬 자리」만 답하게 좁혀져
## `ring_book.jin_icon_paths`(→ `jin_guide_pts`·`rune_slot_positions`)로 갈라졌다. 세84 감사 #28에
## 옛 주석("책의 진 셀과 어긋난다")이 낡은 것으로 잡혔다.
## 🔴 대신 **룬 자리 좌표는 책 셀과 같은 함수**(`RingBoard.rune_slot_positions`)를 부른다 —
## 그쪽이 판·책 셀·HUD 셋이 공유하는 자리다(세84 #12).
##
## 🔴 CanvasLayer 위에 산다 — 플레이어를 카메라가 따라다녀서 월드에 그리면 HUD가 같이 흘러간다.
##
## 슬롯 내용을 캐시하지 않고 `_draw`가 매번 `GameState.ring_equipped`를 읽는다. 그래서 갱신은
## `queue_redraw()` 하나로 끝나고, 같은 시그널을 받는 GameState와의 **연결 순서를 따질 필요가 없다**.

const RingPower := preload("res://src/core/ring_power.gd")
## 🔴 진 미니 다이어그램 기하만 쓴다 (`jin_slot_dots`·`rune_slot_positions` = static 순수 함수,
## 세션60·세81 단일 소스 — `SLOTS`는 여기서 안 쓴다). 코드를 베끼면 규약이 바뀔 때 판·Tab
## 다이어그램과 어긋나므로 preload로 그 함수를 그대로 부른다.
## ⚠ `class_name`이 없어 이 preload가 유일한 진입로다.
const RingBoard := preload("res://src/drawing/ring_board.gd")

## 🔴 HP 막대는 **늘 그린다** (세64, 사용자: "hp바가 안 보이고"). 예전엔 show_hp 익스포트로 숲만
## 그렸는데(베이스는 다칠 일이 없어 장식이라), 사용자가 베이스에서도 HP를 보고 싶어 해 항상 표시로
## 바꿨다. HP는 씬을 갈아타도 남는 GameState 원장이라 베이스에서도 값이 유효하다.

# ── 레이아웃 (연출값 — 밸런스 아님. 선례: 시험대의 PLAYER_SPEED·색 상수) ──
const MARGIN := 16.0
const SLOT_SIZE := Vector2(58.0, 58.0)   ## 정사각에 가깝게 (세64에 124×48에서 줄임)
const SLOT_GAP := 8.0
const DIAG_RADIUS := 16.0                ## 슬롯 안 미니 다이어그램 원 반지름
const HP_SIZE := Vector2(210.0, 16.0)
const MANA_SIZE := Vector2(210.0, 14.0)
const BAR_GAP := 6.0
const DETAIL_GAP := 8.0                  ## 슬롯 윗변 ↔ 선택 슬롯 상세 한 줄

# ── 톤 = 세62 책 UI(양피지·먹·가죽). HUD는 게임 위 오버레이라 어두운 가죽 바탕 + 따뜻한 크림 글자 ──
const SLOT_BG := Color(0.16, 0.13, 0.10, 0.72)
const SLOT_BG_ON := Color(0.28, 0.20, 0.11, 0.90)
const SLOT_EDGE := Color(0.50, 0.42, 0.32, 0.70)
const SLOT_EDGE_ON := Color(0.85, 0.55, 0.18)      # 책 UI SEL_EDGE 계열 (가죽 주황)
const INDEX_COLOR := Color(0.60, 0.53, 0.43)
const INDEX_COLOR_ON := Color(0.92, 0.78, 0.45)
const POWER_COLOR := Color(0.90, 0.60, 0.25)
const EMPTY_COLOR := Color(0.52, 0.47, 0.40)
const SAY_COLOR := Color(0.86, 0.80, 0.70)
const WARN_COLOR := Color(0.92, 0.48, 0.35)
const BAR_BG := Color(0.12, 0.10, 0.08, 0.78)
const BAR_EDGE := Color(0.50, 0.42, 0.32, 0.60)
const BAR_TEXT := Color(0.94, 0.90, 0.80)          # 막대 안 숫자 (채운 색·빈 색 위 모두 읽히게 밝게)
const HP_FILL := Color(0.78, 0.30, 0.26)
const HP_LOW := Color(0.94, 0.55, 0.20)
const MANA_FILL := Color(0.36, 0.54, 0.82)
const MANA_LOW := Color(0.90, 0.48, 0.35)
# 미니 다이어그램 — 책 진 셀과 같은 톤 (OPEN_DOT·SHUT_DOT·CELL_LINE)
const DIAG_RING := Color(0.55, 0.48, 0.38, 0.60)
const OPEN_DOT := Color(0.85, 0.50, 0.18)          # 열린 문양 칸
const FILLED_DOT := Color(0.95, 0.68, 0.30)        # 열렸고 문양이 놓인 칸 (더 밝게)
const SHUT_DOT := Color(0.34, 0.30, 0.24, 0.55)    # 닫힌 칸

# ── 돈 카운터 (세66 도파민 경제 1층) ──
## 🔴 좌상단 HP·마나 막대 **아래** 한 줄. 표시값 = 창고 coin + 가방 coin 합 (HUD가 직접 합산한다 —
## 돈은 「아이템 한 종(coin)」이라 전용 필드가 아니라 inventory/bag dict의 키다. core에 coin_total()
## 헬퍼를 안 만드는 게 이번 계약, 합산은 HUD가 진다). resources_changed 하나가 창고·가방 변화를 다 실어 온다.
## 🔴 톡톡 = 돈이 **늘 때만** _coin_punch를 1.0으로 찍고 _process가 감쇠한다(폰트·색 부풀림). 감소(구매)엔
## 안 튄다. 연출 수치라 전부 스크립트 const(밸런스 아님 — 토스트 수명 상수 선례).
## ⚠ HUD _draw는 헤드리스에서 안 돈다(세64) — 카운터 렌더·톡톡 겉보기는 리드가 실게임 MCP로 확인한다.
const COIN_ID := &"coin"
const COIN_FONT_SIZE := 13
const COIN_PUNCH_BUMP := 5.0       ## 풀 톡톡에서 폰트가 이만큼(px) 커진다
const COIN_PUNCH_DECAY := 4.0      ## 초당 감쇠 — 약 0.25초에 가라앉는다
const COIN_ICON_R := 5.5           ## 엽전 도트 반지름 (UI 아이콘 — 게임 프롭 아님이라 도형 허용, 상태창 아이콘 선례)
const COIN_GAP := 8.0              ## 마나 막대 아래 ↔ 코인 줄
const COIN_ROW_H := 20.0
const COIN_FILL := Color(0.86, 0.68, 0.26)         # 엽전 금빛
const COIN_EDGE := Color(0.55, 0.40, 0.14)         # 테두리 (어두운 금)
const COIN_HOLE := Color(0.16, 0.13, 0.10, 0.85)   # 엽전 네모 구멍
const COIN_TEXT := Color(0.90, 0.78, 0.42)
const COIN_TEXT_PUNCH := Color(1.0, 0.94, 0.62)    # 톡톡 순간 밝게

# ── 우하단 상태창(C) 아이콘 (세64 — 사용자: "상태창만 C로 아이콘 만들어 우하단에") ──
## 조작 레전드는 뺐다(사용자: "상호작용 구르기 이런 거 다 필요없어"). 캐릭터/상태창 진입만 남긴다.
## 아이콘 위에 "C" 키를 얹어 "C 누르면 상태창"을 알린다. 시각 표시다 — 클릭은 안 받는다
## (HUD가 mouse_filter=IGNORE라 조준·발사 클릭을 안 먹는다. 클릭 진입까지 주면 그 계약이 깨진다).
const STATUS_ICON_SIZE := 40.0
const STATUS_ICON_BG := Color(0.16, 0.13, 0.10, 0.80)
const STATUS_ICON_EDGE := Color(0.55, 0.45, 0.30, 0.85)
const STATUS_ICON_FIG := Color(0.82, 0.74, 0.58)     # 캐릭터(사람) 실루엣
const STATUS_ICON_KEY := Color(0.98, 0.88, 0.60)     # "C" 키 글자

# ── 획득 토스트 (세션51) ──
## 🔴 **별도 씬·자식 Control을 만들지 않고 여기 `_draw`에 얹는다.** `hud.tscn`이 없다 —
## `hud.gd`가 `base.tscn`·`boss_room.tscn`에 **각각 Control 노드로** 붙어 있어서, 토스트를 노드로
## 만들면 .tscn 두 곳을 고쳐야 하고 **한 곳만 고치면 원정에서만 토스트가 뜨는 조용한 갈라짐**이 된다.
## 여기 두면 두 씬이 공짜로 같이 받는다. 덤으로 새 Control을 안 까니 세션25의 `mouse_filter` 함정
## (화면 덮는 Control이 좌클릭을 다 먹어 발사가 에러 없이 죽는다)에 아예 안 걸린다.
const TOAST_LIFE := 1.6
const TOAST_MAX := 3
const TOAST_FADE := 0.4
const TOAST_ROW_H := 19.0
const TOAST_W := 240.0
const TOAST_GAP := 10.0
const TOAST_FONT_SIZE := 12

# ── 한 줄 안내문(say) 수명 (세84 감사 #36) ──
## 🔴 **안내문도 만료된다** — 옛 `say()`는 대입만 하고 타이머·비우기 호출자가 **하나도 없어**
## "마나가 부족하다" 경고 한 번이 보스방 목표 줄을 덮고 **씬이 끝날 때까지 상주했다**.
## 같은 파일 토스트가 이미 `TOAST_LIFE` + 감쇠를 갖고 있었으니 **두 채널 규약이 갈라져 있던 것**이다.
## 🔴 계속 떠 있어야 하는 문구(보스방 목표·클리어 안내)는 호출부가 `sticky := true`로 **명시**한다 —
## 기본이 만료인 이유: 순간 피드백(발사 거부·목표 완료 토스트성 안내)이 압도적으로 많고,
## 그것이 상주하면 **거짓 경고**(이미 마나가 찼는데 "부족하다")가 화면에 남는다.
const SAY_LIFE := 4.5
const SAY_FADE := 0.6   ## 마지막 이만큼 동안 흐려진다 (토스트 TOAST_FADE와 같은 결)

## 등급 색 — 🔴 단일 소스는 `src/core/grade_colors.gd`다 (세션51에 사본 셋을 여기로 합쳤다).
const GradeColors := preload("res://src/core/grade_colors.gd")
const CodexText := preload("res://src/core/codex_text.gd")

var _selected: int = 0
var _say: String = ""
var _warn: bool = false
## 안내문 남은 수명(초). sticky면 안 줄어든다.
var _say_t: float = 0.0
var _say_sticky: bool = false
## 마나는 매 프레임 변해 시그널이 없다 — 값이 바뀐 프레임만 다시 그린다 (매 프레임 redraw 회피).
var _last_mana: float = -1.0
## 획득 토스트 줄들. 각 항목 = {id, name, grade, count, t}. 앞이 오래된 줄, 뒤가 최근 줄.
var _toasts: Array[Dictionary] = []
## 🔴 돈 카운터 (세66). _coin = 마지막으로 계산한 총액(창고+가방). resources_changed마다 재계산해
## 늘었으면 _coin_punch를 1.0으로 찍고 _process가 감쇠한다. _draw가 _coin·_coin_punch를 읽는다
## (토스트 수명 t가 draw를 모는 것과 같은 결 — draw는 tween을 못 쓰니 상태값을 draw가 읽는다).
var _coin: int = 0
var _coin_punch: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 조준 클릭이 HUD에 먹히면 안 된다
	EventBus.ring_design_committed.connect(_on_design_committed)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.audio_muted_changed.connect(_on_muted_changed)
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.resources_changed.connect(_on_resources_changed)
	# 🔴🔴 **슬롯 내용이 바뀌면 다시 그린다** (세86 ① 슬롯 교체 UI가 만든 새 필요).
	# 세85까지 `ring_equipped`는 **맺을 때만** 바뀌었고 그건 `ring_design_committed`가 이미 잡았다.
	# 이제 Tab「마법진」탭에서 언제든 슬롯을 갈아 끼우는데, `_process`의 redraw 조건은
	# 마나 변화·토스트·안내문·돈 톡톡뿐이라 **마나가 만땅이면 아무도 redraw를 안 건다** —
	# 슬롯 미니 다이어그램이 **바꾸기 전 진을 계속 보여 준다**(= 감사 T8 「쏘는 것 ≠ 보이는 것」).
	# 장비 착·탈용도 파생 스탯을 바꾸므로 같은 신호로 덮인다.
	EventBus.equipment_changed.connect(_on_equipment_changed)
	EventBus.codex_unlocked.connect(_on_codex_unlocked)
	_coin = _coin_total()   # 첫 표시값 — 시그널을 기다리지 않고 부팅 세이브의 잔액을 곧장 보여 준다


## 지금 고른 슬롯 (caster의 slot_changed가 알려 준다).
func select(slot: int) -> void:
	_selected = slot
	queue_redraw()


## 한 줄 안내문. warn=true면 붉게 (빈 슬롯에 쏘려 한 경우 등).
## 🔴 `sticky = false`(기본)면 `SAY_LIFE` 뒤에 스스로 사라진다 — 순간 피드백이 화면에 굳지 않게.
## 🔴 **씬이 끝날 때까지 떠 있어야 하는 문구는 `sticky := true`로 명시해라**(보스방 목표·클리어 안내).
## 빈 문자열을 넣으면 즉시 지운다(수명 계산 없이).
func say(text: String, warn: bool = false, sticky: bool = false) -> void:
	_say = text
	_warn = warn
	_say_sticky = sticky
	_say_t = 0.0 if (sticky or text == "") else SAY_LIFE
	queue_redraw()


## 새 마법진이 맺혔다 — GameState가 같은 시그널로 빈 슬롯에 장착한다.
func _on_design_committed(_design: RingDesign) -> void:
	say("새 마법진이 맺혔다 — 책을 덮고(ESC) 좌클릭으로 쏴 보세요")


## 🔴 새 조립 부품(룬·진·문양-고리)을 얻었다 — 이름과 **어디에 쓰는지**를 한 줄로 알린다 (세88).
##
## 왜 HUD가 받나: 발신처가 셋이다(보스 클리어 · 공방 제작 · 두루마리 픽업). 특히 **픽업은
## 지금까지 화면에 아무것도 안 띄웠다** — `item_collected`는 문자열을 못 싣고 HUD가
## `Db.get_item`으로 이름을 스스로 찾으므로, 해금물에 그 시그널을 쏘면 토스트에 **원시 id가 뜬다**
## (그래서 픽업은 안 쏜다 = 옳은 선택). 해금음·codex·퀘스트는 도는데 *"뭘 배웠는지"*만 안 보이던
## 구멍을 여기서 막는다. 셋을 한 곳에서 받으니 문구도 갈라지지 않는다.
##
## ⚠ `chapter_clear_*`처럼 **획득물이 아닌 codex 키도 이 시그널로 온다** — 리졸버가 빈 문자열을
##   주면 조용히 넘긴다(안 그러면 "chapter_clear_ch1 획득!"이 뜬다).
## ⚠ 보스방에선 `boss_room`이 이 발신 **뒤에** 자기 클리어 안내를 `sticky`로 덮는다(보상 이름이
##   그 안에 들어 있다) — 그래서 두 줄이 다투지 않는다. 발신 순서를 바꾸면 그 균형이 깨진다.
func _on_codex_unlocked(unlock_id: StringName) -> void:
	var line := CodexText.acquired_line(unlock_id)
	if line == "":
		return
	say(line)


## 장착이 바뀌었다(슬롯 교체·장비 착탈) — 슬롯 다이어그램·선택 슬롯 상세를 다시 그린다.
func _on_equipment_changed() -> void:
	queue_redraw()


func _on_hp_changed(_hp: float, _hp_max: float) -> void:
	queue_redraw()


func _on_muted_changed(_muted: bool) -> void:
	queue_redraw()


## 🔴 자원(창고·가방)이 변했다 — 돈 총액을 다시 세고, **늘었으면** 톡톡을 찍는다 (세66).
## resources_changed는 add_item·remove_item·add_to_bag이 다 쏘므로 coin 픽업·상점 구매·귀환 정산을
## 전부 잡는다(coin 픽업은 add_to_bag→resources_changed라 item_collected와 동시 발신 — 여기 하나로 충분).
func _on_resources_changed() -> void:
	var was := _coin
	_coin = _coin_total()
	if _coin > was:
		_coin_punch = 1.0
	queue_redraw()


## 창고 coin + 가방 coin 합. GameState.bag은 [{id, count}] 배열이라 직접 훑는다 — coin 전용 합산
## 헬퍼(coin_total)를 core에 안 만드는 게 이번 계약이라, 합산 책임은 HUD가 진다.
func _coin_total() -> int:
	var total := GameState.get_count(COIN_ID)
	for entry: Dictionary in GameState.bag:
		if StringName(entry.get("id", &"")) == COIN_ID:
			total += int(entry.get("count", 0))
	return total


## 🔴 바닥 픽업이 흡수돼 가방에 도착했다 (drop_pickup이 도착 순간 1회 발신).
## **같은 아이템은 새 줄을 만들지 않고 수량을 더하고 수명을 리셋한다** — 안 그러면 드롭 셋이
## 동시에 도착할 때 세 줄 떠서 화면이 도배된다.
## 🔴 합칠 때 **그 줄을 배열 맨 뒤로 옮긴다** (세51 리뷰): 안 옮기면 ① 위치가 낡은 자리에 남고
## ② FIFO가 방금 갱신된 줄을 "가장 오래됐다"며 밀어낸다. 3줄짜리라 remove+append 비용은 0이다.
func _on_item_collected(item_id: StringName, count: int) -> void:
	for i in _toasts.size():
		var t: Dictionary = _toasts[i]
		if t["id"] == item_id:
			t["count"] = int(t["count"]) + count
			t["t"] = TOAST_LIFE
			_toasts.remove_at(i)
			_toasts.append(t)
			queue_redraw()
			return

	var item: ItemDef = Db.get_item(item_id)
	_toasts.append({
		"id": item_id,
		"name": item.display_name if item != null and item.display_name != "" else str(item_id),
		"grade": item.grade if item != null else 1,
		"count": count,
		"t": TOAST_LIFE,
	})
	while _toasts.size() > TOAST_MAX:
		_toasts.remove_at(0)
	queue_redraw()


## 지금 뜬 한 줄 안내문 (테스트·디버그용 관측점 — 만료됐으면 빈 문자열).
## 🔴 `_say`를 밖에서 더듬으면 리팩터 때 조용히 죽는다(`toast_lines()`와 같은 규약, takbon-verify §3).
func say_line() -> String:
	return _say


## 토스트 스택 열람 (테스트·디버그용). 사본을 준다 — 밖에서 고쳐도 HUD가 안 흔들리게.
func toast_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in _toasts:
		out.append(t.duplicate())
	return out


func _process(delta: float) -> void:
	if not is_equal_approx(GameState.mana, _last_mana):
		_last_mana = GameState.mana
		queue_redraw()
	# 토스트가 살아 있는 동안만 매 프레임 다시 그린다 (평소엔 redraw 비용 0).
	if not _toasts.is_empty():
		for i in range(_toasts.size() - 1, -1, -1):
			_toasts[i]["t"] = float(_toasts[i]["t"]) - delta
			if float(_toasts[i]["t"]) <= 0.0:
				_toasts.remove_at(i)
		queue_redraw()
	# 안내문 수명 — 살아 있는 동안만 매 프레임 다시 그린다(흐려지는 구간이 있어서). sticky는 안 준다.
	if _say != "" and not _say_sticky:
		_say_t = maxf(0.0, _say_t - delta)
		if _say_t <= 0.0:
			_say = ""
		queue_redraw()
	# 돈 톡톡 감쇠 — 튄 동안만 매 프레임 다시 그린다 (평소엔 redraw 비용 0).
	if _coin_punch > 0.0:
		_coin_punch = maxf(0.0, _coin_punch - COIN_PUNCH_DECAY * delta)
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# ── 좌상단: HP(위)·마나(아래) 막대 — 숫자는 막대 안 (세64). 둘 다 늘 그린다. ──
	var bar_y := MARGIN
	_draw_hp(font, Vector2(MARGIN, bar_y))
	bar_y += HP_SIZE.y + BAR_GAP
	_draw_mana(font, Vector2(MARGIN, bar_y))
	bar_y += MANA_SIZE.y

	# ── 돈 카운터 — 막대 바로 아래 (세66 도파민 경제 1층). ──
	bar_y += COIN_GAP
	_draw_coin(font, Vector2(MARGIN, bar_y))
	bar_y += COIN_ROW_H

	# 상황 메시지 — 막대 바로 아래 좌상단 (마나 부족·새 마법진 맺힘 등). 상단 hint를 걷어낸 자리.
	# 만료 직전 SAY_FADE 동안 흐려진다(토스트와 같은 결). sticky 문구는 안 흐려진다.
	if _say != "":
		var say_col := WARN_COLOR if _warn else SAY_COLOR
		if not _say_sticky and SAY_FADE > 0.0:
			say_col.a *= clampf(_say_t / SAY_FADE, 0.0, 1.0)
		draw_string(font, Vector2(MARGIN, bar_y + 16.0), _say,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, say_col)

	# 음소거 표시 — 우상단. 소리가 꺼진 걸 눈으로 알게 (안 그러면 "왜 소리가 안 나지"가 버그로
	# 오해된다). 이모지는 fallback_font에서 두부가 되니 텍스트로.
	if Audio.is_muted():
		draw_string(font, Vector2(size.x - 150.0, MARGIN + 12.0), "[음소거] O로 켜기",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WARN_COLOR)

	# ── 좌하단 클러스터: 슬롯(맨 아래) → 선택 상세 → 단축키 레전드, 위로 쌓는다 ──
	var slots_top := size.y - MARGIN - SLOT_SIZE.y
	_draw_toasts(font, slots_top)
	for i in GameState.EQUIP_SLOTS:
		_draw_slot(font, Vector2(MARGIN + float(i) * (SLOT_SIZE.x + SLOT_GAP), slots_top), i)

	# 선택 슬롯 상세 한 줄 (이름·위력) — 칸마다 적던 글자를 여기 한 줄로 모았다.
	var detail_y := slots_top - DETAIL_GAP
	_draw_selected_detail(font, Vector2(MARGIN, detail_y))

	# 우하단: 상태창(C) 아이콘.
	_draw_status_icon(font)


## 획득 토스트 — **우측 하단, 슬롯 윗쪽**. 슬롯·막대가 전부 좌측이라 오른쪽 끝은 안 겹친다.
## 최근 줄이 맨 아래고 오래된 줄이 위로 밀린다. `slots_top` = 슬롯 윗변 y (여기서부터 위로 쌓는다).
func _draw_toasts(font: Font, slots_top: float) -> void:
	var right := size.x - MARGIN
	var n := _toasts.size()
	for i in n:
		var t: Dictionary = _toasts[i]
		var left := float(t["t"])
		var alpha := clampf(left / TOAST_FADE, 0.0, 1.0) if TOAST_FADE > 0.0 else 1.0
		var col := GradeColors.of(int(t["grade"]))
		col.a = alpha
		var row_y := slots_top - TOAST_GAP - float(n - 1 - i) * TOAST_ROW_H
		draw_string(font, Vector2(right - TOAST_W, row_y),
			"%s ×%d" % [t["name"], int(t["count"])],
			HORIZONTAL_ALIGNMENT_RIGHT, TOAST_W, TOAST_FONT_SIZE, col)


## 우하단 상태창(C) 아이콘 — 사람 실루엣 위에 "C" 키. C를 누르면 개인 시트의 캐릭터 탭이 열린다.
## 시각 표시일 뿐 클릭은 안 받는다(HUD mouse_filter=IGNORE 계약 — 조준·발사 클릭 보호).
func _draw_status_icon(font: Font) -> void:
	var s := STATUS_ICON_SIZE
	var pos := Vector2(size.x - MARGIN - s, size.y - MARGIN - s)
	var rect := Rect2(pos, Vector2(s, s))
	draw_rect(rect, STATUS_ICON_BG, true)
	draw_rect(rect, STATUS_ICON_EDGE, false, 1.5)
	# 사람 실루엣 — 머리(원) + 어깨(반원 호). UI 아이콘이라 도형 드로잉 허용(게임 프롭 아님).
	var cx := pos.x + s * 0.5
	var head_c := Vector2(cx, pos.y + s * 0.34)
	draw_circle(head_c, s * 0.13, STATUS_ICON_FIG)
	# 어깨: 아래로 볼록한 호 (몸통 실루엣)
	var body_c := Vector2(cx, pos.y + s * 0.82)
	draw_arc(body_c, s * 0.26, PI, TAU, 16, STATUS_ICON_FIG, 3.0)
	# "C" 키 — 아이콘 우상단 모서리에 얹는다.
	draw_string(font, Vector2(pos.x + s - 13.0, pos.y + 13.0), "C",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, STATUS_ICON_KEY)


## 선택된 슬롯의 이름·위력·점수 한 줄. 빈 슬롯이면 흐리게 안내. 칸마다 적던 텍스트를 여기로 모아
## 화면 글자를 줄였다 — 잘 그린 진과 막 그린 진의 차이(위력·점수)는 이 한 줄에서 여전히 보인다.
func _draw_selected_detail(font: Font, at: Vector2) -> void:
	var design: RingDesign = GameState.ring_equipped[_selected]
	if design == null:
		# ⚠ 세99: "그려 장착"은 **세83에 폐지된 그리기**를 가리키던 폐지어였다(세95 청산에서 빠진 자리 —
		#  MCP 스샷이 잡았다. 헤드리스는 문구가 화면에 뜨는 걸 못 본다).
		draw_string(font, at, "슬롯 %d — 비어 있음 (책상 E에서 조립해 장착)" % (_selected + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EMPTY_COLOR)
		return
	# 🔴 점수 반올림도 core가 판다 — 「퍼펙트」가 그 반올림으로 정의돼 있다 (score_display 주석).
	# 🔴 세79 M1: ① `size`(진 크기)를 실어야 **Tab 마법진 탭·조립 리포트와 같은 숫자**가 나온다 —
	# 안 실으면 잉크·크기가 붙은 도안에서 HUD만 낮게 나와 어느 쪽이 맞는지 아무도 모른다.
	# ② 변형형(확산·폭발)이 끼면 그 숫자는 **갈래 하나**의 위력이다(`ring_power.gd` 머리의 경계).
	var unit := "갈래당 위력" if design.has_modifier_glyph(Db.modifier_codes()) else "위력"
	var text := "슬롯 %d · %s   %s %d · %d점" % [_selected + 1, design.display_name, unit,
		RingPower.power_display(design.total_score, Db.ink_mult(design.ink), design.size),
		RingPower.score_display(design.total_score)]
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, POWER_COLOR)


## 돈 카운터 — 엽전 도트 + "N닢". 톡톡: 늘면 _coin_punch가 폰트를 키우고 색을 밝힌다(→ _process 감쇠).
## at.y = 이 줄의 윗변(다른 좌상단 텍스트가 top+오프셋을 baseline으로 쓰는 관례와 동일). 엽전은 UI
## 아이콘이라 도형(원+구멍) 드로잉 허용 — 바닥 픽업 스프라이트(drop_pickup, coin.png)와는 별개다.
func _draw_coin(font: Font, at: Vector2) -> void:
	var baseline := at.y + float(COIN_FONT_SIZE)
	var punch := _coin_punch
	var r := COIN_ICON_R + punch * 1.5
	var icon_c := Vector2(at.x + r, baseline - float(COIN_FONT_SIZE) * 0.35)
	draw_circle(icon_c, r, COIN_FILL)
	draw_arc(icon_c, r, 0.0, TAU, 20, COIN_EDGE, 1.5)
	var hole := r * 0.36
	draw_rect(Rect2(icon_c - Vector2(hole, hole), Vector2(hole * 2.0, hole * 2.0)), COIN_HOLE, true)
	var col := COIN_TEXT.lerp(COIN_TEXT_PUNCH, punch)
	var fs := COIN_FONT_SIZE + int(round(punch * COIN_PUNCH_BUMP))
	draw_string(font, Vector2(icon_c.x + r + 6.0, baseline), "%d닢" % _coin,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## HP 막대 — GameState가 원장이다 (씬을 갈아타도 남는 값). 숫자를 **막대 안**에 넣는다:
## 막대만 있으면 "한 대 더 맞아도 되나"를 못 읽는다 (세64에 옆 텍스트를 안으로 옮겼다).
func _draw_hp(font: Font, at: Vector2) -> void:
	var hp_max := GameState.hp_max()
	var frac := clampf(GameState.hp / hp_max, 0.0, 1.0) if hp_max > 0.0 else 0.0
	draw_rect(Rect2(at, HP_SIZE), BAR_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(at, Vector2(HP_SIZE.x * frac, HP_SIZE.y)),
			HP_LOW if frac <= 0.3 else HP_FILL, true)
	draw_rect(Rect2(at, HP_SIZE), BAR_EDGE, false, 1.0)
	_draw_bar_label(font, at, HP_SIZE, "HP %d / %d" % [ceili(GameState.hp), roundi(hp_max)])


## 마나 막대 — 발사 예산. 다 쓰면 발사가 거부되고(caster의 spend_mana) HUD가 "마나 부족"을 띄운다.
## 숫자는 막대 안에. ⚠ 무소모 테스트 모드는 겉으로 적는다 — 안 적으면 "에디터에선 마나가 안 닳네"가 버그로 읽힌다.
func _draw_mana(font: Font, at: Vector2) -> void:
	var mana_max := GameState.mana_max()
	var frac := clampf(GameState.mana / mana_max, 0.0, 1.0) if mana_max > 0.0 else 0.0
	draw_rect(Rect2(at, MANA_SIZE), BAR_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(at, Vector2(MANA_SIZE.x * frac, MANA_SIZE.y)),
			# 🔴 세85: 「부족」 경계는 **`GameState.cast_mana_cost()`** — 장착 지팡이의 `wand_mana_mult`가
			# 얹힌 값이다. `RingPower.cast_mana_cost()`를 직접 부르면 값싼 지팡이를 껴도 막대만 빨갛다.
			MANA_LOW if GameState.mana < GameState.cast_mana_cost() else MANA_FILL, true)
	draw_rect(Rect2(at, MANA_SIZE), BAR_EDGE, false, 1.0)
	var mana_text := "마나 ∞ (테스트)" if GameState.debug_free_cast \
		else "마나 %d / %d" % [floori(GameState.mana), roundi(mana_max)]
	_draw_bar_label(font, at, MANA_SIZE, mana_text)


## 막대 안 가운데 정렬 숫자 — 채운 색·빈 색 위 모두 읽히게 밝은 크림.
func _draw_bar_label(font: Font, at: Vector2, bar: Vector2, text: String) -> void:
	var fs := 10
	# 세로 중앙: 베이스라인을 막대 중앙 + 폰트 절반쯤. 작은 막대라 눈대중 보정.
	var baseline := at.y + bar.y - 4.0
	draw_string(font, Vector2(at.x, baseline), text,
		HORIZONTAL_ALIGNMENT_CENTER, bar.x, fs, BAR_TEXT)


## 슬롯 한 칸 — 번호 + **진 미니 다이어그램**(원 + 열린/채운 칸 점 + 중심 룬색). 빈 칸은 비어 보인다.
## 이름·위력은 여기 안 적는다 — 선택 슬롯 상세 한 줄이 대신 보여 준다 (세64 정리).
func _draw_slot(font: Font, at: Vector2, idx: int) -> void:
	var on := idx == _selected
	var rect := Rect2(at, SLOT_SIZE)
	draw_rect(rect, SLOT_BG_ON if on else SLOT_BG, true)
	draw_rect(rect, SLOT_EDGE_ON if on else SLOT_EDGE, false, 2.0 if on else 1.0)
	draw_string(font, at + Vector2(6.0, 14.0), "%d" % (idx + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INDEX_COLOR_ON if on else INDEX_COLOR)

	var design: RingDesign = GameState.ring_equipped[idx]
	var center := at + Vector2(SLOT_SIZE.x * 0.5, SLOT_SIZE.y * 0.5 + 5.0)
	if design == null:
		# 빈 칸 — 흐린 원 하나로 "여기 진이 들어온다"만 암시.
		draw_arc(center, DIAG_RADIUS, 0.0, TAU, 24, SHUT_DOT, 1.0)
		return
	_draw_jin_diagram(center, design)


## 진 미니 다이어그램 — 칸 규약은 `jin_slot_dots`(Tab 마법진 탭과 공유), 룬 자리는
## `rune_slot_positions`(판·책 셀과 공유). 원 둘레 8칸: 열린 칸은 주황, 문양이 놓인 칸은 더 밝게,
## 닫힌 칸은 흐리게. 중심은 룬 색 점(융합진이면 둘). 진의 "형태"가 손끝에서 읽힌다.
func _draw_jin_diagram(center: Vector2, design: RingDesign) -> void:
	draw_arc(center, DIAG_RADIUS, 0.0, TAU, 24, DIAG_RING, 1.0)
	# 🔴 세79 M1: 진이 **여러 층**을 가질 수 있다(2등급 = 2겹). `rings[0]`만 보면 바깥 층에만
	# 놓인 문양이 통째로 안 그려져 **HUD가 조용히 거짓말한다** — `open`은 층들의 합집합이라
	# "열렸는데 비었다"로 보인다. 판정은 core 단일 소스 `design.is_slot_filled(k)`가 쥔다
	# (여기 인라인으로 두면 헤드리스가 못 재서 회귀 검출이 0이 된다 — 세79에 실측).
	var dots: Array = RingBoard.jin_slot_dots(design.open, center, DIAG_RADIUS)
	for k in dots.size():
		var d: Dictionary = dots[k]
		var pos: Vector2 = d["pos"]
		var is_open: bool = d["open"]
		if is_open:
			var filled := design.is_slot_filled(k)   # 어느 층에든 놓였으면 채워진 칸
			draw_circle(pos, 3.0 if filled else 2.4, FILLED_DOT if filled else OPEN_DOT)
		else:
			draw_circle(pos, 1.6, SHUT_DOT)
	# ── 중심 룬 색 — 어느 속성 진인지 색으로. 융합진(룬 2개)이면 점이 둘이다. ──
	# 🔴 세84 #12: 옛 코드는 `design.rune`(첫 룬)만 읽어 **융합진의 두 번째 룬이 HUD에서 사라졌다**
	# — 두 슬롯의 중심 점 색이 똑같아 1·2 키로 뭘 쏘는지 구분이 안 됐다(쏘는 것 ≠ 보이는 것).
	# 목록 정본은 `RingDesign.runes_of`다(`RingDesign.rune` 필드 주석: *"읽을 땐 runes_of()를 거쳐라"*).
	# 🔴 자리 좌표는 `RingBoard.rune_slot_positions`를 **그대로 부른다** — 각도를 베끼면 판·책 셀·
	# HUD 셋이 조용히 어긋난다(`jin_slot_dots`를 부르는 것과 같은 이유, 세60).
	var runes := RingDesign.runes_of(design.runes, design.rune)
	var seeds := RingBoard.rune_slot_positions(runes.size(), center, DIAG_RADIUS)
	# 자리가 여럿이면 점을 줄인다 — 판의 룬 축소(RUNE_MULTI_SIZE_FRAC)와 같은 규약.
	var dot_r := 3.0 if runes.size() <= 1 else 3.0 * RingBoard.RUNE_MULTI_SIZE_FRAC
	for i in seeds.size():
		var rune_def: RuneDef = Db.get_rune(int(runes[i]))
		draw_circle(seeds[i], dot_r,
			rune_def.ui_color if rune_def != null else Color(0.62, 0.22, 0.12))
