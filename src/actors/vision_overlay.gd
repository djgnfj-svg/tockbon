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
## 🔴🔴 **세105: 0.30 → 1.00. 「상한에 가깝다」던 위 문단을 사용자가 뒤집었다** —
##  *"**빛이 아예없어야하는데** 어렵나? 아예 안되고 있거든?"*(2026-07-28 · 스샷 첨부).
##
##  **세73·세99의 각하와 충돌하지 않는다 — 축이 다르다.** 그 둘이 각하한 건 **「방이 어둡다」**
##  (어두운 던전·횃불 조명)이고, 이건 **「시야 밖이 없다」**다. 방은 여전히 낮이고 **부채꼴 안은
##  100% 원래 밝기 그대로**다. 어두워지는 건 **내가 안 보는 쪽**뿐이라, *"밝게할꺼고 조명만"*의
##  정신은 오히려 이쪽이 더 잘 지킨다(조명이 아니라 **시야**가 밝기를 정한다).
##
## 🔴 **딸려오는 대가 둘 — 올리는 순간 둘 다 눈에 띈다:**
##  ⓐ **시야 밖 드롭·지형이 안 보인다.** 30%일 땐 흐릿하게라도 보였다. 「떨어진 걸 못 줍는다」가
##    나오면 이 값이 원인이다(드롭 자석 반경 72px는 주변시 110 안이라 **줍기 자체는 산다**).
##  ⓑ ✅ **세107에 원인째 사라졌다** — 세105엔 차폐가 「밝은데 적이 안 보인다」를 만들어
##    (*"몬스터만 안보여짐 **빛이 안가야하거든**"*) 셰이더 그늘로 풀었는데, **차폐 자체가 은퇴해**
##    (사용자 *"구지 나무나 돌맹이에 시야가 가려지지 않도록"*) 그 사고의 발생원이 없다.
##    ⇒ 지금은 **부채꼴 ∪ 주변시 안이면 그 안의 적이 전부 보인다** — 예외가 하나도 없다.
##
## ✅ **세105 후반: 1.00 → 0.85** (사용자 *"잘된다 이제 100%에서 다시 낮춰줘"*).
##  🔴 **1.00은 「되나?」를 확인하려고 끝까지 밀어 본 값이지 착지값이 아니었다.** 그림자가 실제로
##  도는 걸 눈으로 확인한 뒤 **위 대가 ⓐ(시야 밖 드롭·지형이 통째로 안 보인다)를 되사는** 조정이다.
##  0.85면 부채꼴 대비는 거의 그대로인데 **밖의 윤곽이 희미하게 살아난다** — 「저기 뭔가 떨어졌다」가
##  읽히되 「보인다」고는 못 하는 정도. ⚠ 여기서 더 내리면 **그림자 원뿔이 먼저 안 읽힌다**
##  (원뿔은 「밝은 쪽과의 대비」로 보이는 것이라 바탕이 밝아질수록 흐려진다).
##
## ✅ **세105 착지: 0.85 → 0.40** (사용자 *"좀더 연하게 40정도가 좋을듯"*).
##  0.40을 고를 때의 근거는 *"**그림자 원뿔이 형태를 준다** — 나무 뒤로 뻗는 쐐기가 눈에 먼저 잡히므로
##  바탕 대비가 옅어도 「시야가 있다」가 읽힌다"*였다.
##
## ✅🔴🔴 **세107 착지: 0.40 → 0.26** (사용자 F5 *"어둠 40인가 이렌데 26으로 낮춰줘"*).
##  🔴 **이 세션의 예측이 정확히 반대로 틀렸고, 그게 이 문단의 값어치다.** 차폐가 은퇴해 그림자 쐐기가
##  사라졌으니 *"이제 「내가 어디를 보나」를 지는 건 이 값 하나뿐이라 **올려야 할지도 모른다**"*고 적어 뒀는데
##  (세104에 0.30이 *"거의 안 읽혔다"*는 이력이 그 근거였다), 사용자가 걸어 보고 **더 내렸다.**
##  ⇒ **「그림자가 대비를 벌어 줬다」는 세105의 설명이 과대평가였다.** 0.40은 그림자 없이도 과했고,
##   세104의 「0.30이 안 읽힌다」는 **그때 조건**(주변시 220 · 부채꼴 120°)에 딸린 값이었다 —
##   시야가 좁아지면(110 · 100°) 같은 어둡기가 **훨씬 세게 읽힌다**(어두운 면적이 넓어지니까).
##  🔴 **그러니 이 값을 옛 이력의 숫자만 보고 판단하지 마라 — 시야 셋과 한 묶음이다.**
##
## 🔴 **이력 = 이 값의 사용법이다**: 0.20(첫 확정) → 0.30(세104 F5) → **1.00**(세105 · 극단으로 밀어
##  「빛이 안 막힌다」를 드러냄 → **그림자 구현을 촉발**) → 0.85 → 0.40 → **0.26**(세107 · 차폐 은퇴 후).
##  **막힌 곳을 찾을 땐 극단으로 밀고, 찾고 나면 되돌린다** — 그 왕복이 이 값에서 실제로 통했고,
##  1.00까지 안 밀었으면 「빛이 나무를 통과한다」를 못 봤다.
##
## ⚠ 어둡기를 안 올리고 읽힘만 올리는 손잡이가 따로 있다 → `EDGE_FEATHER_PX`/`ANGLE_FEATHER_PX`
##  (경계를 또렷하게 하면 「선」이 생겨 부채꼴이 읽힌다). **더 내릴 땐 그쪽을 먼저 써라.**
const FOG_DARKNESS := 0.26
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

## ⚠ **세107: 차폐가 은퇴했다** — 여기 있던 `MAX_OCCLUDERS`·`SHADOW_FEATHER_PX`·`OCCLUDER_GROUP`·
##  `OCCLUDE_R_META`와 그 캐시·필터·공개 관측점(`_bake_occluders`·`_refresh_live`·`occluder_overflow`
##  ·`live_occluders`·`baked_occluder_count`)이 통째로 빠졌다. 셰이더의 그늘 루프·`uniform occluders`도
##  같이 걷었다 — 🔴 **되살리려면 판정(`src/core/vision.gd`)·화면(이 파일 + `.gdshader`)·그물을
##  셋 같이 열어라**(하나만 열면 「밝은데 적이 안 보인다」가 돌아온다). 경위 = `vision.gd` 머리말.

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
	var origin := p.global_position
	var dir := aim.normalized()
	_mat.set_shader_parameter(&"origin", origin)
	_mat.set_shader_parameter(&"aim", dir)


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
##
## ⚠ **세107: 여기 있던 엄폐물 인자가 은퇴했다** — 세105엔 셰이더가 그늘을 그렸으므로 이 관측점도
##  **같은 목록**을 지나야 화면과 답이 안 갈렸다. 차폐가 통째로 빠져 지금은 부채꼴 ∪ 주변시뿐이다.
##  🔴 되살릴 땐 **셰이더와 이 함수를 같이** 열어라(하나만 열면 화면과 관측점이 갈린다).
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
