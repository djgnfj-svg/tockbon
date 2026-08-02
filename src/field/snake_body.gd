extends Node2D
## 뱀 보스의 세그먼트 몸통 — 부모(뱀 머리 = forest_enemy)를 **모르는** 순수 추종 컴포넌트다.
## 매 프레임 부모 위치를 버퍼에 넣고 마디를 경로 거리로 지연된 과거 위치에 놓을 뿐이라 뱀 전용 훅이
## 안 생기고, 물결(S자)도 머리 위브를 버퍼가 기록해 저절로 물려받는다. 마디 수·간격·호흡은 연출 const다.

## 머리+토막이 아니라 전신이 다 있는 긴 뱀으로.
const SEGMENT_COUNT: int = 18
## 마디 사이 경로 거리(px) — 마디가 서로 겹쳐 "연속된 몸"으로 읽히게 지름(≈58px)보다 작게 둔다.
const SEGMENT_SPACING: float = 22.0
## 마디 스프라이트 — 48px · +x 방향.
const BODY_TEX := preload("res://assets/sprites/enemies/snake_body.png")
const TAIL_TEX := preload("res://assets/sprites/enemies/snake_tail.png")
## 몸통 스프라이트 기본 배율(48px 기준) — 사용자 튜닝.
const SEGMENT_SCALE: float = 1.2
## 꼬리 쪽 축소 비율 — 마지막 마디 = SEGMENT_SCALE × 이 값. 완만해야 끝까지 꽉 찬 몸으로 읽힌다.
const SEGMENT_TAPER: float = 0.65
## 끝 몇 마디를 꼬리 텍스처로 그릴지.
const TAIL_SEGMENTS: int = 2

## 머리가 이 거리 이상 움직였을 때만 점을 찍는다 — 매 프레임 찍으면 저속에서 점이 뭉쳐
## 버퍼가 거리를 못 덮는다.
const SAMPLE_MIN_DIST: float = 2.5
## 버퍼 상한 — 무한 증가 방지. 필요 경로 = COUNT·SPACING = 396px, 점 간격 ≥2.5px라 ~158점이면 덮는다.
const MAX_SAMPLES: int = 256

## 호흡 펄스(스케일) — 마디가 살아 숨쉬는 느낌 (연출).
const BREATH_FREQ: float = 3.0
const BREATH_PHASE: float = 0.6   ## 마디마다 위상차 → 물결이 몸을 타고 흐른다
const BREATH_AMP: float = 0.08

## 마디 그림자 — 마디가 top_level이라 그림자도 top_level + 절대 z 0으로 깐다. Ground(z0)와 동률이라
## 트리 순서에 기대 위에 그려진다 ⚠ 이 동률 의존은 헤드리스가 못 잡는다 — 실게임 스샷으로만 보인다.
const ShadowScript := preload("res://src/actors/shadow.gd")
const SHADOW_RADIUS_FRAC: float = 0.30  ## 그림자 반경 = 마디 겉보기 크기 × 이 값 (연출)
const SHADOW_OFFSET_Y: float = 10.0     ## 마디 중심에서 발밑까지 (연출 — 사용자 튜닝)

## 🔴 마디 z는 **양수여야 한다** — 음수면 Ground(z0) 뒤로 숨어 몸통이 통째로 안 보인다(헤드리스는 못 잡는다).
## 🔴 머리 크기는 **루트 scale**로 준다 — Visual.scale을 키우면 피격 `_pop()`이 1.0으로 되돌려 "맞으면 작아진다".
var _segments: Array[Sprite2D] = []
## 마디 발밑 그림자 — _segments와 1:1.
var _shadows: Array[Sprite2D] = []
## 머리 위치 히스토리(월드 좌표) — index 0 = 가장 최근(현재 머리).
var _history: Array[Vector2] = []
var _t: float = 0.0


func _ready() -> void:
	var parent := get_parent() as Node2D
	var start := parent.global_position if parent != null else global_position
	# 초기 자취를 머리 뒤로 미리 깔아 첫 프레임부터 전신이 펴져 보이게 한다 — 안 깔면 정지 상태에서
	# 마디가 머리에 겹쳐 쌓인다(트레일 추종은 머리가 움직여야 펴진다).
	var trail_len := float(SEGMENT_COUNT) * SEGMENT_SPACING + SEGMENT_SPACING
	var seed_count := int(trail_len / SAMPLE_MIN_DIST)
	for k in seed_count + 1:
		_history.append(start + Vector2(-SAMPLE_MIN_DIST * float(k), 0.0))
	for i in SEGMENT_COUNT:
		var seg := Sprite2D.new()
		seg.texture = TAIL_TEX if i >= SEGMENT_COUNT - TAIL_SEGMENTS else BODY_TEX
		# 앞 마디(seg0)가 z 최대 → 위로 온다. 전부 양수라 Ground(z0) 위에 그려진다.
		seg.z_index = SEGMENT_COUNT - i
		seg.z_as_relative = false
		# 마디는 자식이지만 월드 좌표로 배치한다 — top_level로 부모 트랜스폼과 안 싸우게(머리가
		# 회전/스케일해도 마디 좌표가 안 꼬인다).
		seg.top_level = true
		seg.global_position = _sample_at_distance(float(i + 1) * SEGMENT_SPACING)
		seg.scale = Vector2.ONE * _base_scale(i)
		add_child(seg)
		_segments.append(seg)
		# 그림자는 마디의 자식이 아니라 형제다 — 자식이면 마디 회전을 따라 타원이 같이 기울어
		# 그림자가 아니라 바닥이 도는 그림이 된다.
		var shadow: Sprite2D = ShadowScript.new()
		shadow.top_level = true
		shadow.z_as_relative = false
		shadow.z_index = 0
		shadow.radius_px = float(BODY_TEX.get_height()) * _base_scale(i) * SHADOW_RADIUS_FRAC
		add_child(shadow)
		shadow.global_position = seg.global_position + Vector2(0.0, SHADOW_OFFSET_Y)
		_shadows.append(shadow)


func _physics_process(delta: float) -> void:
	_t += delta
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var head := parent.global_position

	if _history.is_empty() or head.distance_to(_history[0]) >= SAMPLE_MIN_DIST:
		_history.push_front(head)
		if _history.size() > MAX_SAMPLES:
			_history.resize(MAX_SAMPLES)

	for i in _segments.size():
		var seg := _segments[i]
		var d := float(i + 1) * SEGMENT_SPACING
		var pos := _sample_at_distance(d)
		seg.global_position = pos
		var ahead := _sample_at_distance(maxf(0.0, d - SEGMENT_SPACING))
		var dir := ahead - pos
		if dir.length_squared() > 0.0001:
			seg.rotation = dir.angle()
		# taper 위에 곱한다 — 덮어쓰면 안 된다(둘 다 scale을 쓴다).
		var pulse := 1.0 + sin(_t * BREATH_FREQ + float(i) * BREATH_PHASE) * BREATH_AMP
		seg.scale = Vector2.ONE * _base_scale(i) * pulse
		# 그림자는 호흡 펄스를 안 받는다 — 바닥은 숨을 안 쉰다.
		if i < _shadows.size():
			_shadows[i].global_position = pos + Vector2(0.0, SHADOW_OFFSET_Y)


## 히스토리 폴리라인에서 머리로부터 경로 거리 d 떨어진 지점.
## 첫 몇 프레임엔 버퍼가 짧아 머리(또는 꼬리)로 클램프한다.
func _sample_at_distance(d: float) -> Vector2:
	if _history.is_empty():
		var parent := get_parent() as Node2D
		return parent.global_position if parent != null else global_position
	if d <= 0.0 or _history.size() == 1:
		return _history[0]
	var acc := 0.0
	for i in range(1, _history.size()):
		var a := _history[i - 1]
		var b := _history[i]
		var seg_len := a.distance_to(b)
		if seg_len <= 0.0:
			continue
		if acc + seg_len >= d:
			var t := (d - acc) / seg_len
			return a.lerp(b, t)
		acc += seg_len
	# 버퍼가 거리를 못 덮으면 가장 오래된 점(꼬리 끝)으로 클램프.
	return _history[_history.size() - 1]


## 머리 쪽 full → 꼬리 쪽 SEGMENT_TAPER. 호흡 펄스가 이 위에 곱해진다.
func _base_scale(i: int) -> float:
	var frac := float(i) / float(maxi(1, SEGMENT_COUNT - 1))
	return SEGMENT_SCALE * lerpf(1.0, SEGMENT_TAPER, frac)


# ── 공개 관측점 (헤드리스 테스트용) ──

func segment_count() -> int:
	return _segments.size()


func segment_global_position(i: int) -> Vector2:
	if i < 0 or i >= _segments.size():
		return global_position
	return _segments[i].global_position
