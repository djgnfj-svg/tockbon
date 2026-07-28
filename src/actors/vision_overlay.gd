extends ColorRect
## 🔴🔴 **시야 부채꼴을 화면에 보이게 한다** (세104 · 사용자 요청 *"20%정도만 어둡게"*).
## 정본 = `docs/takbon-design/vision_design.md` · 연출 규격 = `docs/VFX_SPEC.md`.
##
## **왜 있나**: 세104에 시야가 들어와 부채꼴·주변시 밖의 적이 사라지는데 **부채꼴이 어디인지
## 화면에 아무 표시가 없었다** — 플레이어는 적이 사라졌다 나타나는 걸로 역추론할 뿐이었다.
## 이 노드는 그 밖을 **조금만** 눌러 「내가 지금 어디를 보고 있나」를 보이게 한다.
##
## 🔴🔴 **세게 넣지 마라 — 두 번 각하된 자리다.**
##  세73 사용자 *"밝게할꺼고 조명만"*(어두운 던전 각하) · 세99 *"그냥 낮으로 바꾸자"*(횃불 8개 삭제).
##  `vision_design` §9도 「화면 조명·어둠」을 **범위 밖**으로 못 박았다. 사용자가 세104에 그걸
##  **「20% 정도만」이라는 단서와 함께** 뒤집었다 ⇒ 🔴 **지형·프롭·드롭·흙길이 여전히 또렷해야 한다.**
##  어두워지는 게 아니라 **주목이 부채꼴로 모이는** 정도다. 짙게 올리면 세73으로 되돌아간다.
##
## 🔴🔴 **판정을 두 벌로 만들지 마라.** 모양의 단일 소스는 `src/core/vision.gd` + balance의
##  `vision_*` 셋이고, 이 파일은 그 값을 **셰이더에 그대로 주입만** 한다. 셰이더 안에 각도·거리를
##  박으면 「어두운 데 서 있는데 보이는 적」이 생기고 **에러가 0이다**(감사 T5).
##  ⚠ `fan_deg`는 **전체 각도**다(반각을 넘기면 부채꼴이 절반이 되는데 아무도 못 알아챈다).
##
## 🔴 **어디에 붙나 = 방(`boss_room`)의 자식 · 월드 좌표계**다. 화면 좌표를 안 쓰는 이유:
##  카메라가 따라 움직이고 줌·흔들림도 있어서, 화면 좌표로 그리면 **부채꼴이 월드에서 미끄러진다.**
##  사각형을 방의 `Ground`에 맞춰 두면 그 변환이 애초에 없다(카메라가 방 안에 묶여 있어 늘 화면을 덮는다).
## 🔴 **마을엔 안 붙인다** — 마을엔 시야가 없다(`forest_enemy` 인스턴스가 없어 허수아비는 늘 보인다).
##  그물이 「던전엔 있고 마을엔 없다」를 잰다.
##
## ⚠ **HUD를 덮지 않는다** — HUD(`CanvasLayer` layer 1)·시트(layer 5)는 **다른 캔버스**라
##  이 노드의 z가 아무리 높아도 그 아래다. z는 월드 안에서만 겨룬다(VFX_SPEC §3의 50~56 위).
## 🔴 **`mouse_filter = IGNORE`** — 화면을 덮는 Control의 기본값(STOP)은 좌클릭을 통째로 먹어
##  **발사가 조용히 죽는다**(세25·26에 실제로 밟았고 **헤드리스는 절대 못 잡는다** — 그래서
##  그물이 이 속성값을 직접 잰다). 씬에 박혀 있지만 여기서도 확인한다.

## 🔴 수치의 출처 — **balance는 「무엇이 보이나」(난이도)만 든다.** 아래 연출값 셋은
##  `balance_data.gd` 머리말의 *"여기 있는 건 DPS를 바꾸는 것뿐"* 규약에 따라 여기 const다.
const BAL := preload("res://data/balance.tres")
## 🔴 판정의 단일 소스. `class_name` 없는 core 순수 규칙 파일이라 preload로 문다
##  (`status_rules`·`ring_power` 형제 · `forest_enemy`도 같은 줄을 든다).
const Vision := preload("res://src/core/vision.gd")

## 🔴🔴 **밖을 얼마나 누르나 — 사용자가 정한 값이다.** 정의는 여기 한 곳뿐이고 셰이더는 기본값조차 안 든다.
##  **올리기 전에 이 파일 머리말의 세73·세99를 다시 읽어라.**
##
## 이력: 0.20(첫 확정 *"20%정도만 어둡게"*) → **0.30**(세104 F5).
##  🔴 **왜 올렸나 — 20%가 실제 플레이 줌에서 거의 안 읽혔다.** 부채꼴 사거리(560)가 화면
##  반대각선(≈551)보다 커서 **앞을 보면 화면 대부분이 이미 밝은 쪽**이고, 어두운 띠는 등 뒤 구석에만
##  남는다. 방 전체를 뽑은 스샷에선 부채꼴이 뚜렷했는데 **게임 줌에서는 안 보였다** —
##  ⚠ **줌아웃 스샷으로 이 값을 판단하지 마라. 반드시 실제 줌으로 봐라.**
##
## 🔴 **여기가 상한에 가깝다.** 세73(*"밝게할꺼고 조명만"* — 어두운 던전 각하)·세99(*"그냥 낮으로"* —
##  횃불 8개 삭제)가 두 번 각하한 방향이라, 더 올리려면 **지형·드롭이 어두운 쪽에서도 또렷한지**를
##  스샷으로 먼저 보여라. 「어두워졌다」가 보이는 순간 그 결정을 배신한 것이다.
##  ⚠ 어둡기를 안 올리고 읽힘만 올리는 손잡이가 따로 있다 → `EDGE_FEATHER_PX`/`ANGLE_FEATHER_PX`
##   (경계를 또렷하게 하면 「선」이 생겨 부채꼴이 읽힌다). 다음엔 그쪽을 먼저 써라.
const FOG_DARKNESS := 0.30
## 반경 경계(주변시 원 둘레 · 부채꼴 앞끝)의 그라디언트 폭(px).
## 🔴 딱 끊으면 「종이를 오려 붙인 것」으로 보이고, 넓으면 부채꼴 자체가 안 읽힌다 —
##  주변시 반경(220)의 5분의 1쯤이 그 사이다.
const EDGE_FEATHER_PX := 48.0
## 부채꼴 **옆선**의 그라디언트 폭(px). 각이 아니라 px로 잡는다 — 고정 각으로 두면
## 멀수록 번짐이 넓어져 끝이 뭉갠다(셰이더가 거리로 나눠 라디안으로 바꾼다).
const ANGLE_FEATHER_PX := 40.0

## 🔴 월드 안에서의 자리 — VFX_SPEC §3의 z층(50 처치 퍼프 ~ 56 감전 스파크) **위**다.
##  이건 연출이 아니라 **화면 덮개**라 그 표에 끼우는 물건이 아니다. HUD와는 캔버스가 달라 안 겨룬다.
const OVERLAY_Z := 90

var _mat: ShaderMaterial = null
var _player: Node2D = null
var _warned: bool = false


func _ready() -> void:
	# ⚠ 씬에도 박혀 있지만 여기서 다시 못 박는다 — 화면을 덮는 Control이 클릭을 먹으면
	#  발사가 통째로 죽는데 화면엔 아무 표시도 없다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = OVERLAY_Z
	_mat = material as ShaderMaterial
	if _mat == null:
		push_error("vision_overlay: ShaderMaterial이 없다 — 안개가 통째로 안 그려진다")
		visible = false
		return
	_apply_shape()


## 🔴🔴 **모양을 balance에서 그대로 넘긴다 — 여기가 「판정 두 벌」을 막는 유일한 자리다.**
##  `forest_enemy._judge_seen`이 `Vision.is_seen`에 넘기는 것과 **같은 세 값**이다.
##  ⚠ 값을 계산해서 넘기지 마라(특히 `fan_deg * 0.5`) — 반각 변환은 **셰이더 안에서** 한다.
##   여기서 반으로 갈라 넘기면 화면의 부채꼴만 절반이 되고 적은 옛 각도로 사라진다(에러 0).
func _apply_shape() -> void:
	_mat.set_shader_parameter(&"fan_deg", BAL.vision_fan_deg)
	_mat.set_shader_parameter(&"fan_range", BAL.vision_fan_range)
	_mat.set_shader_parameter(&"near_radius", BAL.vision_near_radius)
	_mat.set_shader_parameter(&"darkness", FOG_DARKNESS)
	_mat.set_shader_parameter(&"edge_feather", EDGE_FEATHER_PX)
	_mat.set_shader_parameter(&"angle_feather", ANGLE_FEATHER_PX)


## 🔴 방이 자기 바닥 사각형을 넘겨 준다 — **좌표를 여기 베끼지 않는다.**
##  방 크기는 세88에 한 번 커졌고 또 커질 수 있다(`_clamp_camera_to_room`이 같은 이유로 Ground에서 파생한다).
##  ⚠ 안 부르면 크기가 0이라 아무것도 안 그려진다 — 조용히 사라지지 않게 `_process`가 짖는다.
func fit_to(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	if _mat != null:
		_mat.set_shader_parameter(&"rect_pos", rect.position)
		_mat.set_shader_parameter(&"rect_size", rect.size)


## 🔴🔴 **판정할 수 없으면 안개를 걷는다**(fail-open — `Vision.is_seen`과 **같은 방향의 실패**다).
##  플레이어가 없거나·`vision_dir()`이 없거나(테스트 스텁)·조준이 영벡터면 `is_seen`이
##  **「전부 보인다」**를 돌려준다 ⇒ 그때 화면만 어두우면 **밝은 규칙과 어두운 화면이 정반대**가 된다.
##  🔴 *"알 수 없으니 어둡게"*는 그래서 취향이 아니라 **버그**다.
## ⚠ 원점·방향은 **그룹 조회 + `has_method` 가드 + `.call()`**로만 얻는다 —
##  `player.get_node("Caster")`로 타고 들어가면 진짜 노드 경로 결합이고 takbon-rules §0 위반이다.
func _process(_delta: float) -> void:
	if _mat == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		if not _warned:
			_warned = true
			push_warning("vision_overlay: 크기가 0이다 — 방이 `fit_to()`를 안 불렀다(안개가 안 보인다)")
		visible = false
		return
	var p := _source()
	if p == null or not p.has_method(&"vision_dir"):
		visible = false
		return
	var aim: Vector2 = p.call(&"vision_dir")
	if aim.is_zero_approx():
		visible = false
		return
	visible = true
	_mat.set_shader_parameter(&"origin", p.global_position)
	_mat.set_shader_parameter(&"aim", aim.normalized())


## 그룹 `"player"`가 유일한 조회 경로다(`forest_enemy._player`와 같은 계약).
## ⚠ 캐시는 유효성으로 갱신한다 — 죽거나 씬이 갈리면 다음 프레임에 다시 찾는다.
func _source() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	return _player


## 🔴 공개 관측점 — 지금 이 좌표가 「밝은 쪽」인가. **그물과 화면이 같은 문을 지나게** 한다
##  (`forest_enemy.is_seen()` 선례). ⚠ 여기서 부채꼴을 다시 재지 않는다 — `Vision`에게 묻고,
##   인자는 **셰이더에 넘긴 그 uniform**에서 되읽는다. 그래서 주입이 끊기면 이 함수도 같이 틀린다
##   (= 그물이 그 사고를 잡는다).
## ⚠ uniform이 하나라도 안 실려 있으면(주입이 끊긴 상태) `get_shader_parameter`는 **null**을 준다 —
##  그대로 넘기면 여기서 죽는다. 「모르면 밝다」로 흘리고, 그 사고 자체는 그물이 uniform 값으로 잡는다.
func lit_at(world: Vector2) -> bool:
	if _mat == null or not visible:
		return true
	var origin = _mat.get_shader_parameter(&"origin")
	var aim = _mat.get_shader_parameter(&"aim")
	var deg = _mat.get_shader_parameter(&"fan_deg")
	var range_px = _mat.get_shader_parameter(&"fan_range")
	var near_px = _mat.get_shader_parameter(&"near_radius")
	if origin == null or aim == null or deg == null or range_px == null or near_px == null:
		return true
	return Vision.is_seen(origin, aim, world, deg, range_px, near_px)
