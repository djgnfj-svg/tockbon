extends Area2D
## 중간보스(gale) 등장 컷 — 보스 존 입구 트리거 + 짧은 연출 (~2.4초, 모듈 C. GDD §9).
## 1회 판정은 codex `cut_gale_intro` (TECH_SPEC §5.1 — 재생 시작 시 발신, SaveManager 자동 커버).
## class_name 없음 — field.gd에서 const BossIntro := preload(...) 로 사용, boss·modulate_node 주입.

const Util := preload("res://src/field/field_util.gd")
const InkStyle := preload("res://src/ui/ink_style.gd")

const UNLOCK_ID := &"cut_gale_intro"
const INTRO_TEXT := "바람이 글자를 삼켰다"

## 트리거 영역 — 보스 존 입구(BOSS_GATE_X 폭)를 덮는다
const TRIGGER_SIZE := Vector2(128, 40)

# ── 연출 타이밍·색 (밸런스 수치 아님 — 연출 전용)
const DARKEN_SEC := 0.4          # 화면 어두워짐 + 보스 실루엣화
const FOCUS_SEC := 0.6           # 카메라 시선 도착 + 실루엣 → 원색 리빌
const HOLD_SEC := 0.9            # 텍스트 유지
const RESTORE_SEC := 0.5         # 원상 복구
const DIM_COLOR := Color(0.10, 0.10, 0.16)          # 컷 중 CanvasModulate
const SILHOUETTE_COLOR := Color(0.04, 0.05, 0.09)   # 보스 실루엣

## field가 배선 시 주입
var boss: Node2D
var modulate_node: CanvasModulate

var _playing: bool = false
var _label: Label

func _ready() -> void:
	# 이미 시청했으면 트리거 자체를 두지 않는다 (재진입 스킵)
	if GameState.is_unlocked(UNLOCK_ID):
		queue_free()
		return
	collision_layer = 0
	collision_mask = 1 << 1        # 2 = player
	monitoring = true
	Util.add_rect_collider(self, TRIGGER_SIZE)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _playing or not body.is_in_group("player"):
		return
	if GameState.is_unlocked(UNLOCK_ID):
		return
	if boss == null or not is_instance_valid(boss):
		return
	_playing = true
	_play(body)

## 연출 본체 — 시퀀싱은 타이머로 (트윈 대상이 도중 사라져도 잠금 해제는 보장)
func _play(player: Node2D) -> void:
	EventBus.codex_unlocked.emit(UNLOCK_ID)
	if player.has_method("set_busy"):
		player.call("set_busy", true)
	var boss_ai_was: bool = bool(boss.get("ai_enabled"))
	boss.set("ai_enabled", false)
	var boss_color: Color = boss.modulate
	var start_color: Color = modulate_node.color if modulate_node != null else Color.WHITE
	var cam := _find_camera(player)
	var focus_offset := boss.global_position - player.global_position
	var overlay := _build_overlay()
	add_child(overlay)

	# 1) 어둡게 + 실루엣 (카메라·텍스트는 리빌까지 이어서)
	if modulate_node != null:
		create_tween().tween_property(modulate_node, "color", DIM_COLOR, DARKEN_SEC)
	create_tween().tween_property(boss, "modulate", SILHOUETTE_COLOR, DARKEN_SEC)
	if cam != null:
		create_tween().tween_property(cam, "offset", focus_offset, DARKEN_SEC + FOCUS_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	create_tween().tween_property(_label, "modulate:a", 1.0, DARKEN_SEC + FOCUS_SEC)
	await get_tree().create_timer(DARKEN_SEC).timeout

	# 2) 실루엣 → 원색 리빌 후 텍스트 유지
	if is_instance_valid(boss):
		create_tween().tween_property(boss, "modulate", boss_color, FOCUS_SEC)
	await get_tree().create_timer(FOCUS_SEC + HOLD_SEC).timeout

	# 3) 원상 복구
	if modulate_node != null and is_instance_valid(modulate_node):
		create_tween().tween_property(modulate_node, "color", start_color, RESTORE_SEC)
	if cam != null and is_instance_valid(cam):
		create_tween().tween_property(cam, "offset", Vector2.ZERO, RESTORE_SEC)
	if is_instance_valid(_label):
		create_tween().tween_property(_label, "modulate:a", 0.0, RESTORE_SEC)
	await get_tree().create_timer(RESTORE_SEC).timeout

	# 최종 상태 확정 (트윈이 도중 죽었어도 여기서 정리) → 전투 개시
	if modulate_node != null and is_instance_valid(modulate_node):
		modulate_node.color = start_color
	if cam != null and is_instance_valid(cam):
		cam.offset = Vector2.ZERO
	if is_instance_valid(boss):
		boss.modulate = boss_color
		boss.set("ai_enabled", boss_ai_was)
	if is_instance_valid(player) and player.has_method("set_busy"):
		player.call("set_busy", false)
	if is_instance_valid(overlay):
		overlay.queue_free()
	queue_free()

func _find_camera(player: Node2D) -> Camera2D:
	for child in player.get_children():
		if child is Camera2D:
			return child as Camera2D
	return null

## 텍스트 오버레이 — 화면 중앙 하단 한 줄 (ink_style 라벨)
func _build_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 40
	_label = InkStyle.make_label(INTRO_TEXT, 14, InkStyle.PAPER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -80.0
	_label.offset_bottom = -52.0
	_label.modulate.a = 0.0
	layer.add_child(_label)
	return layer
