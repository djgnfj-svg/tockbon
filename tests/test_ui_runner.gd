extends Node
## 모듈 E 자가 검증 러너 — 목 데이터 주입 후 EventBus 시그널을 프레임 시퀀스로 발화,
## 각 화면의 핵심 노드 존재·값 바인딩을 PASS/FAIL 로그로 남긴다.
## 실행: Godot --headless --path . res://tests/test_ui.tscn --quit-after 60

const InkStyle := preload("res://src/ui/ink_style.gd")
const DesignThumb := preload("res://src/core/design_thumb.gd")

const THUMB_BOX := Vector2(64, 64)

@onready var ui: Control = $UiRoot
@onready var hud: Control = $UiRoot/Hud
@onready var fx: Control = $UiRoot/FxOverlay
@onready var bulletin: Control = $UiRoot/Screens/Bulletin
@onready var loadout: Control = $UiRoot/Screens/Loadout
@onready var codex: Control = $UiRoot/Screens/Codex

var _frame := 0
var _passed := 0
var _failed := 0
var _designs: Array[SpellDesign] = []
## 🔴 #17 2단계 — HUD 하단 슬롯은 이제 고리 도안(ring_equipped)을 보여 준다. 옛 SpellDesign 표시는 은퇴.
var _ring_design: RingDesign = null
## 획이 있는 도안(플레이어가 그린 것)과 획이 없는 샘플 도안 — 썸네일 두 경로를 각각 검증한다
var _drawn_thumb: Control = null
var _empty_thumb: Control = null

func _ready() -> void:
	_inject_mocks()
	_make_probe_thumbs()
	print("TEST_UI: 목 주입 완료 — 도안 %d장, 적 %d종" % [GameState.designs.size(), Db.enemies.size()])

func _inject_mocks() -> void:
	# 아침 게시판·장착 화면은 튜토리얼을 마친 필경사의 하루 흐름이다 (ui_root.TUTORIAL_UNLOCK).
	# 첫날(튜토 전)에는 억제되므로, UI 검증은 수업을 마친 상태를 전제한다.
	GameState.codex[&"tutorial_done"] = true
	# 도안: 손그림 1장(strokes 있음 — 먹선 썸네일) + 샘플 3장(strokes 없음 — 글리프 폴백) + 손상본 1장
	_designs = [_hand_drawn_design()]
	_designs.append_array(SampleDesigns.all())
	var broken := SampleDesigns.aimed_lance_water()
	broken.id = &"sample_broken"
	broken.display_name = "샘플: 찢어진 도안"
	broken.durability = 0
	_designs.append(broken)
	GameState.designs = _designs
	# 🔴 #17 2단계 — 고리 도안: 칸 2=발산·칸 6=응집 → HUD 슬롯 1에 장착 (하단 슬롯 고리 표시 검증용)
	_ring_design = RingDesign.from_assembly(
		{"rune": 0, "rings": [[-1, -1, 1, -1, -1, -1, 0, -1]], "open": [2, 6]}, "불의 고리")
	GameState.ring_equipped[0] = _ring_design
	# 적 5종 목 데이터 (GDD §7)
	for def in _mock_enemies():
		Db.enemies[def.id] = def
	# 도감 일부 해금 — 불 룬만(물·바람은 미해금=실루엣 2), 적 3종(약점 없음 슬라임 포함), 제법 1종 (v2.2: 충격 룬 폐지)
	GameState.codex[InkStyle.rune_unlock_id(Enums.RuneType.FIRE)] = true
	GameState.codex[InkStyle.enemy_unlock_id(&"vine_regrower")] = true
	GameState.codex[InkStyle.enemy_unlock_id(&"forest_hound")] = true
	GameState.codex[InkStyle.enemy_unlock_id(&"sap_slime_elite")] = true
	GameState.codex[&"recipe_paper_2"] = true

## 모듈 A가 만들어 낼 도안의 목 — 정규화 캔버스 좌표, 중심에서 벗어난 비대칭 배치.
## bbox 피팅이 실제로 동작하는지 보려면 도안이 캔버스 중앙에 얌전히 있으면 안 된다.
func _hand_drawn_design() -> SpellDesign:
	var d := SpellDesign.new()
	d.id = &"mock_hand_drawn"
	d.display_name = "손그림: 불의 진"
	d.circle_type = Enums.CircleType.AIMED
	d.circle_radius = 0.5
	d.rune_type = Enums.RuneType.FIRE
	d.rune_accuracy = 0.8
	d.mana_cost = 18.0
	# 진 — 중심 (0.4, 0.45), 반지름 0.25
	var circle := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		circle.append(Vector2(0.4, 0.45) + Vector2(cos(a), sin(a)) * 0.25)
	circle.append(circle[0])
	d.strokes.append(_stroke(circle, Enums.StrokeRole.CIRCLE))
	# 룬 — 삼각형(불)
	d.strokes.append(_stroke(PackedVector2Array([
		Vector2(0.34, 0.52), Vector2(0.40, 0.38), Vector2(0.46, 0.52), Vector2(0.34, 0.52),
	]), Enums.StrokeRole.RUNE))
	# 화살표 — 진 밖으로 뻗는다 (썸네일은 이것까지 보여야 한다)
	d.strokes.append(_stroke(PackedVector2Array([
		Vector2(0.40, 0.45), Vector2(0.65, 0.38), Vector2(0.92, 0.30),
	]), Enums.StrokeRole.ARROW))
	var arrow := ArrowData.new()
	arrow.direction = 0.0
	arrow.magnitude = 0.6
	d.arrows.append(arrow)
	return d

func _stroke(points: PackedVector2Array, role: int) -> StrokeData:
	var s := StrokeData.new()
	s.points = points
	s.role = role as Enums.StrokeRole
	var pressures := PackedFloat32Array()
	for i in points.size():
		pressures.append(0.55 + 0.45 * sin(PI * float(i) / maxf(float(points.size() - 1), 1.0)))
	s.pressures = pressures
	return s

## 위젯 단독 검증용 — UI 트리 밖의 조건(칸 크기·도안 종류)을 직접 통제한다
func _make_probe_thumbs() -> void:
	_drawn_thumb = _probe_thumb(_designs[0])
	_empty_thumb = _probe_thumb(_designs[1])  # 샘플 = strokes 없음

func _probe_thumb(d: SpellDesign) -> Control:
	var thumb := DesignThumb.new()
	thumb.fallback_builder = InkStyle.make_design_fallback  # 모듈 E가 주입하는 룬 표기 폴백
	thumb.call("set_design", d)
	ui.add_child(thumb)
	thumb.size = THUMB_BOX  # 컨테이너 밖 — 크기를 직접 준다 (resized → 재렌더)
	return thumb

func _mock_enemies() -> Array[EnemyDef]:
	var defs: Array[EnemyDef] = []
	defs.append(_enemy(&"vine_regrower", "재생 덩굴", Enums.RuneType.FIRE, false))
	defs.append(_enemy(&"forest_hound", "숲 사냥개", Enums.RuneType.WIND, false))
	var slime := _enemy(&"sap_slime_elite", "수액 슬라임", Enums.RuneType.WATER, true)
	slime.has_counter = false  # 약점 룬 없음 — 다발 도안이 답 (GDD §7)
	defs.append(slime)
	defs.append(_enemy(&"mist_wraith", "안개 정령", Enums.RuneType.WIND, false))
	defs.append(_enemy(&"armored_beetle", "갑주 갑충", Enums.RuneType.WATER, false))
	return defs

func _enemy(id: StringName, display: String, counter: int, elite: bool) -> EnemyDef:
	var def := EnemyDef.new()
	def.id = id
	def.display_name = display
	def.counter_rune = counter as Enums.RuneType
	def.is_elite = elite
	return def

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		2:
			_step_thumb_widget()
		3:
			_step_bulletin()
		4:
			(bulletin.find_child("CloseButton", true, false) as Button).pressed.emit()
		5:
			_step_loadout_shown()
		6:
			_step_loadout_assign()
		7:
			_step_loadout_confirm()
		9:
			_step_hud_slots()
		10:
			_step_cast_executed()
		12:
			_step_cast_failed()
		14:
			_step_phase()
		16:
			_step_damage()
		18:
			_step_resources_toast()
		20:
			EventBus.rubbing_started.emit(&"frag_water")
			GameState.add_to_bag(&"frag_water", 1)
		21:
			_check((fx.find_child("RubbingBox", true, false) as Control).visible, "rubbing_started → 진행 바 표시")
			EventBus.rubbing_completed.emit(&"frag_water")
		22:
			_check(not (fx.find_child("RubbingBox", true, false) as Control).visible, "rubbing_completed → 진행 바 숨김")
			_check((hud.find_child("BagLabel", true, false) as Label).text == "가방 1", "가방 수 갱신 (가방 1)")
		24:
			_step_codex()
		25:
			_step_live_unlock()
		26:
			ui.call("close_top")
			_check(not codex.visible, "close_top → 도감 닫힘")
			_check(not GameState.ui_modal_open, "스택 비면 ui_modal_open 해제")
		27:
			# 필드 자정 quirk 수정 검증 — 거점 밖 day_started는 게시판 억제·보류 (NEXT_CYCLE §5)
			EventBus.scene_changed.emit(&"field")
			EventBus.day_started.emit(Clock.day)
		28:
			_check(not bulletin.visible, "필드에서 day_started → 게시판 억제")
			EventBus.scene_changed.emit(&"base")
		29:
			_check(bulletin.visible, "거점 복귀 → 보류된 게시판 표시")
			_check(GameState.ui_modal_open, "게시판 열림 → ui_modal_open 설정")
			ui.call("close_top")
		31:
			GameState.ring_equipped[0] = null  # 고리 슬롯 해제 → HUD 썸네일도 사라져야 한다
		32:
			_check(_hud_thumb(0).get("design") == null, "슬롯 해제 → HUD 고리 썸네일 제거")
		33:
			_finish()

# ── 단계별 검증

## 썸네일 위젯 단독 — 먹선 렌더 / bbox 피팅 / strokes 없는 도안 폴백
func _step_thumb_widget() -> void:
	_check(_drawn_thumb.call("has_ink"), "획 있는 도안 → 먹선 썸네일 생성")
	var lines := 0
	for child in _drawn_thumb.get_children():
		lines += child.get_child_count()  # InkRender가 만든 Node2D 아래 Line2D들
	_check(lines >= 3, "획 3개(진·룬·화살표) 전부 Line2D로 — 화살표 포함 (%d개)" % lines)

	var rect: Rect2 = _drawn_thumb.call("ink_rect")
	var box := Rect2(Vector2.ZERO, THUMB_BOX)
	_check(box.grow(0.5).encloses(rect),
		"먹선이 칸 안에 들어옴 — bbox %s ⊂ %s" % [str(rect.abs()), str(box)])
	# 여백만 남기고 칸을 채워야 한다 — 한쪽 축은 여백을 뺀 만큼 꽉 찬다 (피팅이 실제로 스케일을 맞춘 증거)
	_check(maxf(rect.size.x, rect.size.y) >= THUMB_BOX.x * 0.7,
		"먹선이 칸을 채움 (긴 축 %.1f ≥ %.1f)" % [maxf(rect.size.x, rect.size.y), THUMB_BOX.x * 0.7])

	_check(not _empty_thumb.call("has_ink"), "strokes 빈 샘플 도안 → 먹선 없음 (크래시 없이 폴백)")
	_check(_empty_thumb.get_child_count() == 1, "폴백 표기 노드 1개 (룬 글리프·아이콘)")

func _step_bulletin() -> void:
	_check(bulletin.visible, "day_started → 아침 게시판 자동 표시")
	var list := bulletin.find_child("EnemyList", true, false) as VBoxContainer
	_check(list != null and list.get_child_count() == Db.enemies.size(),
		"게시판 적 목록 %d행 (Db 전체)" % Db.enemies.size())
	var weak_texts: Array[String] = []
	for row in list.get_children():
		var hbox := row.get_child(0)
		# 이름 라벨(0번) 이후의 라벨 텍스트를 전부 합침 — 룬 아이콘(TextureRect)이 끼어도 견딤
		var parts := PackedStringArray()
		for i in range(1, hbox.get_child_count()):
			var l := hbox.get_child(i) as Label
			if l != null:
				parts.append(l.text)
		weak_texts.append(" ".join(parts))
	_check(weak_texts.any(func(t: String) -> bool: return t.contains("불")), "해금 적 → 약점 룬 표기 (불)")
	_check(weak_texts.any(func(t: String) -> bool: return t.contains("???")), "미해금 적 → 약점 ???")
	_check(weak_texts.any(func(t: String) -> bool: return t == "약점 없음"), "해금 + has_counter=false → 약점 없음")
	var sub := bulletin.find_child("SubTitle", true, false) as Label
	_check(sub.text.begins_with("%d일차" % Clock.day), "게시판 일차 바인딩")

func _step_loadout_shown() -> void:
	_check(not bulletin.visible, "게시판 닫기 → 게시판 숨김")
	_check(loadout.visible, "게시판 닫기 → 장착 선택 표시")
	var list := loadout.find_child("DesignList", true, false) as VBoxContainer
	_check(list != null and list.get_child_count() == 5, "보유 도안 5행 (손그림 1 + 샘플 3 + 손상 1)")
	var has_broken_mark := false
	for child in list.get_children():
		if _row_text(child).contains("[손상]"):
			has_broken_mark = true
	_check(has_broken_mark, "손상 도안 경고 표기 [손상]")
	# 장착 화면 — 그린 도안은 먹선으로, 획 없는 샘플은 폴백으로
	var drawn_row := list.get_child(0)
	var sample_row := list.get_child(1)
	_check(_row_thumb(drawn_row).call("has_ink"), "장착 화면 — 손그림 도안 행에 먹선 썸네일")
	_check(not _row_thumb(sample_row).call("has_ink"), "장착 화면 — 샘플 도안 행은 글리프 폴백")
	var rect: Rect2 = _row_thumb(drawn_row).call("ink_rect")
	var box := Rect2(Vector2.ZERO, (_row_thumb(drawn_row) as Control).size)
	_check(rect.size.x > 0.0 and box.grow(0.5).encloses(rect), "장착 화면 썸네일이 칸 안에 피팅")
	# 슬롯 칸 썸네일 — 아직 배치 전이므로 비어 있다
	var slots := loadout.find_child("SlotList", true, false) as VBoxContainer
	_check(not _row_thumb(slots.get_child(0)).call("has_ink"), "빈 슬롯 칸 → 썸네일 없음")

## 버튼 행(Button > HBox > [Thumb, 라벨들])에서 표시 텍스트를 모은다
func _row_text(row: Node) -> String:
	var parts := PackedStringArray()
	for label: Label in row.find_children("*", "Label", true, false):
		parts.append(label.text)
	return " ".join(parts)

func _row_thumb(row: Node) -> Control:
	return row.find_child("Thumb", true, false) as Control

func _hud_thumb(slot: int) -> Control:
	var panels: Array = hud.get("_slot_panels")
	return (panels[slot] as Control).find_child("Thumb", true, false) as Control

func _step_loadout_assign() -> void:
	loadout.call("select_design", _designs[0])
	loadout.call("assign_slot", 0)
	loadout.call("select_design", _designs[1])
	loadout.call("assign_slot", 1)
	var pending: Array = loadout.call("pending")
	_check(pending[0] == _designs[0] and pending[1] == _designs[1], "도안 선택 → 슬롯 배치 (2장)")

func _step_loadout_confirm() -> void:
	loadout.call("confirm")
	_check(GameState.equipped[0] == _designs[0], "확정 → GameState.equip 슬롯 1 반영")
	_check(GameState.equipped[1] == _designs[1], "확정 → GameState.equip 슬롯 2 반영")
	_check(GameState.equipped[2] == null, "빈 슬롯은 null 유지")
	_check(not loadout.visible, "확정 → 장착 화면 닫힘")

# 🔴 #17 2단계 — HUD 하단 슬롯은 고리 도안(ring_equipped)을 보여 준다 (옛 SpellDesign 표시 은퇴).
func _step_hud_slots() -> void:
	var names: Array = hud.get("_slot_name_labels")
	_check(names.size() == 4, "HUD 장착 슬롯 4개 생성")
	_check((names[0] as Label).text.contains(_ring_design.display_name), "HUD 슬롯 1 이름 바인딩 (고리)")
	var duras: Array = hud.get("_slot_dura_labels")
	_check((duras[0] as Label).text.contains("문양"), "HUD 슬롯 1 룬·문양 수 바인딩")
	var manas: Array = hud.get("_slot_mana_labels")
	var comp := (manas[0] as Label).text
	_check(comp.contains("발산") and comp.contains("응집"), "HUD 슬롯 1 문양 구성 바인딩 (응집·발산)")
	var hp_text := hud.find_child("HpText", true, false) as Label
	_check(hp_text.text == "100/100", "HUD HP 초기값 100/100")
	# 장착한 고리 도안이 슬롯에 그림으로 — 빈 슬롯과 구분된다
	_check(_hud_thumb(0).get("design") != null, "HUD 슬롯 1 — 장착한 고리 도안 썸네일")
	_check(_hud_thumb(2).get("design") == null, "HUD 슬롯 3 — 빈 슬롯은 썸네일 없음")

func _step_cast_executed() -> void:
	EventBus.ring_cast_executed.emit(0, _ring_design)
	var panels: Array = hud.get("_slot_panels")
	_check((panels[0] as Control).modulate != Color.WHITE, "ring_cast_executed → 슬롯 1 플래시")

func _step_cast_failed() -> void:
	# 고리 발사엔 아직 실패(경제)가 없다 (#17 3단계) — fx 토스트는 옛 cast_failed 경로로 확인
	EventBus.cast_failed.emit(_designs[1], Enums.CastFailReason.NO_MANA)
	var toasts := fx.find_child("ToastBox", true, false) as VBoxContainer
	_check(toasts.get_child_count() >= 1, "cast_failed → 사유 토스트")

func _step_phase() -> void:
	EventBus.phase_changed.emit(Enums.Phase.DAY)
	var day_label := hud.find_child("DayLabel", true, false) as Label
	_check(day_label.text.contains("낮"), "phase_changed → 시계 라벨 '낮'")
	_check(day_label.text.begins_with("%d일차" % Clock.day), "시계 일차 바인딩")

func _step_damage() -> void:
	# HP 원장은 GameState (v1.1 이관) — player_damaged는 FX 전용이라 원장 API로 깎는다
	GameState.damage_player(30.0)
	EventBus.player_damaged.emit(30.0)
	var hp_bar := hud.find_child("HpBar", true, false) as ProgressBar
	_check(is_equal_approx(hp_bar.value, 70.0), "damage_player(30) → HP 바 70")

func _step_resources_toast() -> void:
	var toasts := fx.find_child("ToastBox", true, false) as VBoxContainer
	var before := toasts.get_child_count()
	GameState.add_item(&"ink_basic", 3)
	_check(toasts.get_child_count() == before + 1, "resources_changed → 획득 토스트 생성")

func _step_codex() -> void:
	ui.call("toggle_codex")
	_check(codex.visible, "toggle_codex → 도감 표시")
	var runes := codex.find_child("RuneList", true, false) as VBoxContainer
	_check(runes != null and runes.get_child_count() == 3, "도감 룬 탭 3행 (v2.2: 충격 룬 폐지)")
	_check(_count_locked_runes() == 2, "룬 해금 1 / 실루엣 2 (물·바람 미해금)")
	var enemies := codex.find_child("EnemyList", true, false) as VBoxContainer
	_check(enemies.get_child_count() == Db.enemies.size(),
		"도감 적 탭 %d행 (Db 전체)" % Db.enemies.size())
	var recipes := codex.find_child("RecipeList", true, false) as VBoxContainer
	_check(recipes.get_child_count() >= 2, "도감 제법 탭 2행 이상")

## 도감이 열린 채 codex_unlocked 방송 → GameState 등록 + 도감 실시간 리프레시 (TECH_SPEC §5.1)
func _step_live_unlock() -> void:
	EventBus.codex_unlocked.emit(InkStyle.rune_unlock_id(Enums.RuneType.WATER))
	_check(GameState.is_unlocked(&"rune_water"), "codex_unlocked → GameState.codex 등록")
	_check(_count_locked_runes() == 1, "열린 도감 실시간 갱신 (실루엣 2 → 1)")

func _count_locked_runes() -> int:
	var runes := codex.find_child("RuneList", true, false) as VBoxContainer
	var locked := 0
	for row in runes.get_children():
		var col := row.get_child(0).get_child(1)
		if (col.get_child(0) as Label).text == "???":
			locked += 1
	return locked

func _finish() -> void:
	set_process(false)
	print("TEST_UI_DONE: pass=%d fail=%d" % [_passed, _failed])
	if _failed == 0:
		print("TEST_UI_OK")
	else:
		print("TEST_UI_FAILED")

func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		print("FAIL: ", label)
