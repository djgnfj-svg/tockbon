extends Node2D
## 뱀 보스의 **세그먼트 몸통** — 순수 추종 컴포넌트 (세션 A, 설계 A-1 ③ 하이브리드).
##
## 🔴 **디커플이 존재 이유다**: 이 노드는 부모(뱀 머리 = forest_enemy)를 **모른다**. 매 프레임
## `get_parent().global_position`을 히스토리 버퍼에 넣고, 마디 i를 `i·SEGMENT_SPACING`만큼 **경로
## 거리로 지연된 과거 위치**에 놓는다("스네이크 게임 몸통"의 정석). 그래서 forest_enemy에 뱀 전용
## 참조·훅이 하나도 안 생긴다 — 부모가 뭘 하든 그 자취를 따라올 뿐이다.
##
## 🔴 물결(S자)은 여기서 만들지 않는다 — **머리 이동 자체가 위브(측면 사인파)로 흔들리면**
## (forest_enemy `boss_snake` AI), 버퍼가 그 S를 기록하고 몸통이 그대로 물려받는다.
##
## 🔴 class_name 금지(서브에이전트 규칙) → preload도 필요 없다(다른 모듈을 안 문다).
## 🔴 마디 수·간격·색·호흡은 전부 **연출 const**다(밸런스 아님 — drop_pickup·juice const 선례).
## 사용자가 눈으로 보며 조인다.

## 마디 개수. 머리+토막이 아니라 **전신이 다 있는** 긴 뱀으로 (사용자 세54 — 몸통을 꽉 채운다).
const SEGMENT_COUNT: int = 18
## 마디 사이 **경로 거리**(px). 스프라이트 마디가 서로 겹쳐 "연속된 몸"으로 읽히도록
## 마디 지름(≈58px)보다 작게 둔다 (연출 — 사용자 튜닝).
const SEGMENT_SPACING: float = 22.0
## 🔴 마디 스프라이트 (세54: 팔각형 도형 → 실제 도트로 교체). class_name 없는 const preload
## (다른 모듈을 안 문다). 아트 = takbon-art(48px, +x 방향, Apollo).
const BODY_TEX := preload("res://assets/sprites/enemies/snake_body.png")
const TAIL_TEX := preload("res://assets/sprites/enemies/snake_tail.png")
## 몸통 스프라이트 기본 배율(48px 기준) — 보스답게 큰 몸. 사용자 튜닝(손맛).
const SEGMENT_SCALE: float = 1.2
## 꼬리 쪽 축소 비율 — 마지막 마디는 SEGMENT_SCALE × 이 값. 완만하게 둬 몸통이 급히
## 가늘어지지 않고 **끝까지 꽉 찬** 몸으로 읽히게 (사용자 세54).
const SEGMENT_TAPER: float = 0.65
## 끝 몇 마디를 꼬리 텍스처로 그릴지 (몸통이 기니 2마디로 자연스럽게 맺는다).
const TAIL_SEGMENTS: int = 2

## 🔴 히스토리는 **경로 거리**로 샘플하므로, 머리가 이 거리 이상 움직였을 때만 점을 찍는다.
## (매 프레임 찍으면 저속에서 점이 뭉쳐 버퍼가 거리를 못 덮는다 — 세50 "좌표 실측" 결.)
const SAMPLE_MIN_DIST: float = 2.5
## 버퍼 상한 — 무한 증가 방지. 필요 경로 = COUNT·SPACING = 396px, 점 간격 ≥2.5px라 ~158점이면 덮는다.
const MAX_SAMPLES: int = 256

## 호흡 펄스(스케일) — 마디가 살아 숨쉬는 느낌 (연출).
const BREATH_FREQ: float = 3.0
const BREATH_PHASE: float = 0.6   ## 마디마다 위상차 → 물결이 몸을 타고 흐른다
const BREATH_AMP: float = 0.08

## 🔴 마디 z (세54 실게임 함정): **양수여야 한다.** 음수로 두면 숲 `Ground`(ColorRect, z0)
## **뒤로 숨어 몸통이 통째로 안 보인다**("대가리밖에 없다"). 헤드리스엔 바닥이 없어 위치 테스트는
## 통과하고 실게임에서만 드러난다(렌더는 헤드리스가 못 잡는다 — takbon-verify). 앞 마디(seg0)가
## 가장 위(=`SEGMENT_COUNT - i`)로 겹침이 자연스럽게. 머리는 이 위(snake_boss.tscn Visual z_index=30).
##
## 🔴 머리 크기 = **루트 scale**(snake_boss.tscn), Visual.scale이 아니다. 공용 `_pop()`이 피격 때
## `_visual.scale`을 1.0으로 되돌려서 Visual을 키우면 "맞으면 작아진다"(세54). 루트를 키우면
## _pop은 Visual만 1.0으로 두고 루트 배율이 남는다. 마디는 top_level이라 루트 scale 무영향.
var _segments: Array[Sprite2D] = []
## 머리 위치 히스토리(월드 좌표) — index 0 = 가장 최근(현재 머리).
var _history: Array[Vector2] = []
var _t: float = 0.0


func _ready() -> void:
	var parent := get_parent() as Node2D
	var start := parent.global_position if parent != null else global_position
	# 🔴 초기 자취를 머리 뒤(-x, 머리 기본 방향 +x의 반대)로 미리 깐다 — 안 그러면 정지 상태에서
	# 마디가 머리에 겹쳐 쌓여 "대가리밖에 없다"로 보인다(트레일 추종은 머리가 움직여야 펴진다, 세54).
	# 몸통 길이 + 여유만큼 SAMPLE_MIN_DIST 간격으로 채워 첫 프레임부터 전신이 펴져 보이게 한다.
	var trail_len := float(SEGMENT_COUNT) * SEGMENT_SPACING + SEGMENT_SPACING
	var seed_count := int(trail_len / SAMPLE_MIN_DIST)
	for k in seed_count + 1:
		_history.append(start + Vector2(-SAMPLE_MIN_DIST * float(k), 0.0))
	for i in SEGMENT_COUNT:
		var seg := Sprite2D.new()
		# 끝 TAIL_SEGMENTS 마디만 꼬리 텍스처, 나머지는 몸통.
		seg.texture = TAIL_TEX if i >= SEGMENT_COUNT - TAIL_SEGMENTS else BODY_TEX
		# 앞 마디(seg0)가 z 최대 → 위로 온다. 전부 양수라 Ground(z0) 위에 그려진다.
		seg.z_index = SEGMENT_COUNT - i
		seg.z_as_relative = false
		# 🔴 마디는 SnakeBody 자식이지만 **월드 좌표로 배치**한다 — top_level로 부모 트랜스폼과
		# 안 싸우게 한다(머리가 회전/스케일해도 마디 좌표가 안 꼬인다, 설계 A-6).
		seg.top_level = true
		seg.global_position = _sample_at_distance(float(i + 1) * SEGMENT_SPACING)
		seg.scale = Vector2.ONE * _base_scale(i)
		add_child(seg)
		_segments.append(seg)


## 🔴 이동은 물리 틱에서 — 부모(머리)의 자취를 기록하고 마디를 과거 위치에 놓는다.
func _physics_process(delta: float) -> void:
	_t += delta
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var head := parent.global_position

	# 머리가 충분히 움직였을 때만 점을 찍는다 (경로 거리 균일 샘플).
	if _history.is_empty() or head.distance_to(_history[0]) >= SAMPLE_MIN_DIST:
		_history.push_front(head)
		if _history.size() > MAX_SAMPLES:
			_history.resize(MAX_SAMPLES)

	for i in _segments.size():
		var seg := _segments[i]
		var d := float(i + 1) * SEGMENT_SPACING
		var pos := _sample_at_distance(d)
		seg.global_position = pos
		# 진행 방향 = 이 마디에서 한 칸 앞(머리 쪽) 샘플을 향한다.
		var ahead := _sample_at_distance(maxf(0.0, d - SEGMENT_SPACING))
		var dir := ahead - pos
		if dir.length_squared() > 0.0001:
			seg.rotation = dir.angle()
		# 🔴 기본 배율(taper) 위에 호흡 펄스를 곱한다 — taper를 덮어쓰지 않게(둘 다 scale을 쓴다).
		var pulse := 1.0 + sin(_t * BREATH_FREQ + float(i) * BREATH_PHASE) * BREATH_AMP
		seg.scale = Vector2.ONE * _base_scale(i) * pulse


## 🔴 히스토리 폴리라인에서 머리로부터 **경로 거리 d** 떨어진 지점을 샘플한다.
## 빈/짧은 버퍼 가드: 첫 몇 프레임엔 버퍼가 짧아 머리(또는 꼬리)로 클램프한다 — 죽지 않는다.
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


## 마디 i의 기본 배율 — 머리 쪽 full → 꼬리 쪽 SEGMENT_TAPER로 준다. 호흡 펄스가 이 위에 곱해진다.
func _base_scale(i: int) -> float:
	var frac := float(i) / float(maxi(1, SEGMENT_COUNT - 1))
	return SEGMENT_SCALE * lerpf(1.0, SEGMENT_TAPER, frac)


# ── 공개 관측점 (헤드리스 테스트가 공개 API로만 확인 — takbon-verify §3) ──

## 실제로 스폰된 마디 수. 테스트가 SEGMENT_COUNT const와 대조한다.
func segment_count() -> int:
	return _segments.size()


## 마디 i의 월드 좌표. 테스트가 "머리를 옮기면 마디가 따라온다"를 확인한다.
func segment_global_position(i: int) -> Vector2:
	if i < 0 or i >= _segments.size():
		return global_position
	return _segments[i].global_position
