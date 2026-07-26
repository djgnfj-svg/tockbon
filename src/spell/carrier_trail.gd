extends Line2D
## 캐리어·발산탄 공용 트레일 (세션59, 설계 §2-C) — 위치 히스토리를 Line2D로 남긴다.
## class_name 없음 — `const Trail := preload("res://src/spell/carrier_trail.gd")`로 참조.
##
## 🔴 부착 위치 = **스폰 노드(ring_spell_system)의 자식** — 캐리어/탄의 형제다. 탄의 자식으로 달면
## 착탄 queue_free에 트레일이 같은 프레임에 뚝 끊긴다. 형제면 잔상이 수명대로 페이드한다.
## 🔴 자기완결: target이 죽고 포인트가 다 빠지면 스스로 queue_free — 스폰한 쪽은 잊어도 된다
## (옛 chest.gd 자기완결 선례 — 그 파일은 세66 상자 은퇴 때 삭제됐다. 살아 있는 같은 결 =
## `damage_number`·`vfx`의 트윈 자기소멸). 나선·부메랑도 위치 샘플링이라 경로 종류와 무관하게 곡선이 남는다.
## 🔴 그룹 `player_projectiles` 가입 금지 — 테스트 4곳이 이 그룹으로 탄 수를 센다(설계 §6).
##   콜리전도 없다(Line2D) — 순수 시각 오버레이.
##
## 계약: setup(target, color, width, life_sec) — add_child **뒤에** 부른다.

## 머리(최신 포인트) 쪽 최대 알파 — 연출값(손맛), balance 아님.
const TRAIL_ALPHA := 0.65

## 포인트 수명(s) — 이 나이를 넘은 꼬리부터 지운다. setup이 덮는다.
var _life: float = 0.25
var _target: Node2D = null
## 포인트별 나이 — points와 평행 배열 (index 0 = 가장 오래된 꼬리)
var _ages: PackedFloat32Array = PackedFloat32Array()


func setup(p_target: Node2D, p_color: Color, p_width: float, p_life_sec: float) -> void:
	_target = p_target
	_life = maxf(p_life_sec, 0.05)
	width = maxf(p_width, 1.0)
	# 꼬리(포인트 0)=0 → 머리=제 굵기
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.0))
	wc.add_point(Vector2(1.0, 1.0))
	width_curve = wc
	# 꼬리=투명 → 머리=룬색
	var grad := Gradient.new()
	grad.set_color(0, Color(p_color.r, p_color.g, p_color.b, 0.0))
	grad.set_color(1, Color(p_color.r, p_color.g, p_color.b, TRAIL_ALPHA))
	gradient = grad


func _process(delta: float) -> void:
	# 시각 전용이라 _process (탁본 규약: _physics_process=이동, _process=시각)
	for i in _ages.size():
		_ages[i] += delta
	while _ages.size() > 0 and _ages[0] > _life:
		_ages.remove_at(0)
		remove_point(0)
	# 🔴 null 가드 — setup 전 프레임·target free 직후에도 죽지 않는다 (세51 "SCRIPT ERROR 내며 OK" 함정)
	if is_instance_valid(_target) and _target.is_inside_tree() \
			and not _target.is_queued_for_deletion():
		add_point(to_local(_target.global_position))
		_ages.append(0.0)
	elif get_point_count() == 0:
		queue_free()   # target 죽고 잔상까지 다 빠졌다 — 자기완결
