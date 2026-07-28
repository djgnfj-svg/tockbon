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
##  ⓑ ✅ **해결(세105) — 「밝은데 적이 안 보인다」를 그림자로 없앴다.**
##    올린 직후엔 차폐가 **판정만 하고 화면엔 안 그려서**(`vision_occlusion_design` ⓓ)
##    **또렷이 밝은 부채꼴 안에 안 보이는 적**이 생겼고, 사용자가 바로 짚었다 —
##    *"몬스터만 안보여짐 **빛이 안가야하거든**"*. ⇒ ⓓ를 뒤집어 셰이더에 그늘을 넣었다
##    (`occluders` uniform + `lit_at`이 **같이** 열렸다 — 그 문서 §2-5가 미리 적어 둔 조건이다).
##    ⚠ **되돌리려면 셋을 같이 되돌려라**(셰이더 · `lit_at` · 그물) — 하나만 빼면 그 사고가 돌아온다.
##
## ✅ **세105 후반: 1.00 → 0.85** (사용자 *"잘된다 이제 100%에서 다시 낮춰줘"*).
##  🔴 **1.00은 「되나?」를 확인하려고 끝까지 밀어 본 값이지 착지값이 아니었다.** 그림자가 실제로
##  도는 걸 눈으로 확인한 뒤 **위 대가 ⓐ(시야 밖 드롭·지형이 통째로 안 보인다)를 되사는** 조정이다.
##  0.85면 부채꼴 대비는 거의 그대로인데 **밖의 윤곽이 희미하게 살아난다** — 「저기 뭔가 떨어졌다」가
##  읽히되 「보인다」고는 못 하는 정도. ⚠ 여기서 더 내리면 **그림자 원뿔이 먼저 안 읽힌다**
##  (원뿔은 「밝은 쪽과의 대비」로 보이는 것이라 바탕이 밝아질수록 흐려진다).
##
## ✅ **세105 착지: 0.85 → 0.40** (사용자 *"좀더 연하게 40정도가 좋을듯"*).
##  🔴🔴 **0.40이 세104의 0.30 언저리로 돌아온 값인데, 그때와 뜻이 다르다.**
##  세104엔 어둡기 **하나가** 「내가 어디를 보나」를 통째로 져서 0.30이 *"거의 안 읽힌다"*였다.
##  지금은 **그림자 원뿔이 형태를 준다** — 나무 뒤로 뻗는 쐐기가 눈에 먼저 잡히므로,
##  바탕 대비가 옅어도 「시야가 있다」가 읽힌다. ⇒ **어둡기를 낮출 여유를 그림자가 벌어 준 것**이고,
##  그래서 위 이력의 「30%가 안 읽혔다」를 근거로 이 값을 도로 올리지 마라(전제가 바뀌었다).
##
## 🔴 **이력 = 이 값의 사용법이다**: 0.20(첫 확정) → 0.30(세104 F5) → **1.00**(세105 · 극단으로 밀어
##  「빛이 안 막힌다」를 드러냄 → **그림자 구현을 촉발**) → 0.85 → **0.40**(착지).
##  **막힌 곳을 찾을 땐 극단으로 밀고, 찾고 나면 되돌린다** — 그 왕복이 이 값에서 실제로 통했고,
##  1.00까지 안 밀었으면 「빛이 나무를 통과한다」를 못 봤다.
##
## ⚠ 어둡기를 안 올리고 읽힘만 올리는 손잡이가 따로 있다 → `EDGE_FEATHER_PX`/`ANGLE_FEATHER_PX`
##  (경계를 또렷하게 하면 「선」이 생겨 부채꼴이 읽힌다). **더 내릴 땐 그쪽을 먼저 써라.**
const FOG_DARKNESS := 0.40
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

## 🔴🔴 **한 프레임에 셰이더로 넘길 엄폐물의 최대 수 — 셰이더의 `MAX_OCCLUDERS`와 같아야 한다.**
##  셰이더 배열 길이는 컴파일 타임 상수여야 해서 **두 벌로 둘 수밖에 없다** ⇒ 그물이 셰이더 소스를
##  문자열로 읽어 이 값과 대조한다(T5 방어 · `test_vision_overlay_auto`).
##
## 🔴 **왜 상한이 필요한가**: 픽셀(960×540) × N이라 N이 크면 GPU가 죽는다. 방에 엄폐물이 44~48개
##  있지만 **부채꼴 사거리 안 · 쐐기 안**으로 걸러내면 보통 서넛이다(밀도 계산 = 설계 §1 ⓐ).
##  16은 그 기대값의 다섯 배쯤이라 실무대에선 안 넘친다 — 넘치면 `occluder_overflow()`가 짖는다.
## ⚠ **키우기 전에 `_refresh_live`의 필터부터 의심해라** — 상한에 닿는다는 건 대개 필터가
##  안 듣고 있다는 뜻이다(사거리 밖·등 뒤가 목록에 남으면 그늘엔 아무 영향이 없는데 자리만 먹는다).
const MAX_OCCLUDERS := 16

## 🔴 그늘 경계의 반그림자 폭(px · 연출값 — `EDGE_FEATHER_PX`와 같은 갈래다).
##  딱 끊으면 **검은 부채꼴을 오려 붙인 것**으로 보인다.
##
## 🔴🔴 **폭이 고정이 아니다 — 엄폐물 뒤로 갈수록 넓어진다**(셰이더가 `(1 - t)`로 판다).
##  이력이 곧 이유다: 처음엔 고정 폭이었는데 **원 둘레에 일정한 검은 후광**이 생겨 나무 옆·앞까지
##  어두워졌고, 원뿔이 아니라 **얼룩**으로 읽혔다(`scratch_shots/occl_after1.png`).
##  깊이에 비례시키면 밑동에선 경계가 또렷하고(= 「저 나무가 가린다」가 읽힌다) 멀리서 부드러워진다 —
##  실제 반그림자와 같은 방향이다.
##
## 🔴 이 값 **하나가** 두 경계를 판다(셰이더 주석 참조): 원뿔 **옆선** + 밑동 원 **테두리**.
##  둘을 따로 두면 한쪽만 조여져 밑동에 **테두리 링**이 남는다(실측 — 「비눗방울」처럼 보였다).
##
## 🔴🔴 **번지는 방향이 계약이다 — 화면은 판정보다 「넓게」 어두울 수만 있다.**
##  어둠이 100%가 되는 선은 **양쪽 다 엄폐물 반경 `r`**, 즉 `Vision._blocked`가 「막힘」이라
##  답하기 시작하는 그 선이다. 옆선은 `r` **바깥으로**, 밑동 테두리는 `r` **안쪽으로** 번진다 —
##  둘 다 「판정상 보이는 자리가 조금 어둡다」쪽이다.
##  ⚠ **뒤집지 마라**: 반대로 깔면 「판정상 막혔는데 화면은 밝다」가 되어 사용자가 지적한
##   그 증상(*"몬스터만 안보여짐"*)이 그대로 돌아온다. 빗장 = `test_vision_overlay_auto [3]`.
##
## 🔴 이력: **18.0**(첫 판) → 32.0(사용자 *"그림자도 자연스럽게 서서히 어두워 지도록"*) → **20.0**(착지).
##  ⚠ **32에서 도로 내린 이유는 어둡기와 한 축이기 때문이다** — 같은 F5에서 `FOG_DARKNESS`가
##   0.85 → **0.40**으로 내려갔는데, 바탕이 옅어지면 **번짐이 넓을수록 원뿔이 먼저 사라진다**
##   (원뿔은 「밝은 쪽과의 대비」로 보인다). 즉 **어둡기를 내리면 이 값도 같이 내려야 모양이 산다.**
##   🔴 **둘 중 하나만 만지고 「흐려졌다」고 판단하지 마라 — 두 값이 같은 것을 판다.**
##  ⚠ 올릴 때 같이 확인할 것 = **원뿔이 아직 「가려졌다」로 읽히나.** 넘치게 올리면 판정은 그대로인데
##   화면만 애매해져 ⓓ를 뒤집은 이유와 정반대의 실패가 된다
##   (`scratch_shots/occl_g24·occl_soft·occl_g40`에 24·32·40을 뽑아 뒀다).
##
## ⏳ **0.40에서 20·26·32를 나란히 뽑아 뒀다** — `scratch_shots/occl_d40_f20·f26·f32.png`.
##  20은 옆선이 가장 또렷하고 26은 「서서히」가 조금 더 살아 있다. **한 숫자만 바꾸면 되니**
##  F5에서 사용자가 고르면 된다(vfx 의견 = 26이 사용자 요구어에 더 가깝다).
const SHADOW_FEATHER_PX := 20.0

## 🔴🔴 **방이 새기는 그 키다** — 정본은 `boss_room.OCCLUDER_GROUP`·`OCCLUDE_R_META`이고
##  여기 둘은 그 **소비자**다(`forest_enemy`가 든 것과 같은 두 줄 — 셋이 갈리면 조용히 안 가린다).
##  ⚠ field를 preload로 물면 takbon-rules §0 위반이라 **그룹 이름으로만** 만난다.
const OCCLUDER_GROUP := &"occluders"
const OCCLUDE_R_META := &"occlude_r"

var _mat: ShaderMaterial = null
var _player: Node2D = null
var _warned: bool = false

## 🔴 방이 세운 엄폐물 전량 — **한 번 굽고 캐시한다**(매 프레임 `get_nodes_in_group()` 금지 · 설계 O4).
var _all_occluders: PackedVector3Array = PackedVector3Array()
var _baked: bool = false
## 이번 프레임에 실제로 셰이더에 실은 것 — 🔴 **`lit_at()`도 바로 이 목록으로 판정한다**
##  (화면과 관측점이 **같은 목록**을 지나야 「밝은데 어둡다고 답하는」 갈라짐이 안 생긴다).
var _live: PackedVector3Array = PackedVector3Array()
## 🔴 상한에 걸려 **잘린 개수** — 「조용히 잘림」을 그물이 잡을 수 있게 밖으로 연다.
var _overflow: int = 0
var _overflow_warned: bool = false


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
	_mat.set_shader_parameter(&"shadow_feather", SHADOW_FEATHER_PX)
	_mat.set_shader_parameter(&"occluder_count", 0)


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
	# 🔴 **여기가 「첫 틱」이다** — `_ready`가 아니다(`_bake_occluders` 머리말). 방의 `_ready`가
	#  `_spawn_props()`를 끝낸 **뒤**에 처음 돈다.
	if not _baked:
		_bake_occluders()
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
	# 🔴 목록은 한 번 굽고, **고르는 건 매 프레임**이다(플레이어가 움직인다).
	_refresh_live(origin, dir)


## 🔴🔴 **엄폐물을 한 번 굽는다 — `_ready`가 아니라 첫 `_process` 틱이다** (설계 §3-2 · F5).
##
## 🔴 **`$VisionFog`는 씬 자식이라 `_ready`가 `boss_room._ready`보다 먼저 돈다.** 거기서 구우면
##  **씬에 손으로 박힌 나무만** 잡히고 `_spawn_props()`가 세운 절차 프롭이 통째로 빠진다 —
##  에러 0 · 화면 그대로 · **반쯤 맞는 목록**이라 「안 도는 것」보다 나쁘다.
##  선례가 같은 병이다: `forest_enemy._home`이 *"`_ready`가 아니라 첫 `_physics_process` 틱"*인 이유.
## 🔴 **매 프레임 `get_nodes_in_group()`을 부르지 마라**(설계 O4) — 그래서 캐시다.
## ⚠ **캐시는 낡는다**(O5) — 프롭을 런타임에 추가·삭제하는 기능이 생기면 `rebake_occluders()`를
##  불러야 한다. 지금은 배치가 결정적이라(D5) 그럴 자리가 없다.
func _bake_occluders() -> void:
	_baked = true
	_all_occluders = PackedVector3Array()
	for node: Node in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var n := node as Node2D
		if n == null:
			continue
		if not n.has_meta(OCCLUDE_R_META):
			# 🔴 침묵 금지 — 그룹과 meta가 갈리면 **그 프롭만 조용히 안 가린다**(「열쇠와 문」).
			push_warning("vision_overlay: '%s'가 %s 그룹인데 %s meta가 없다 — 그 프롭은 그늘을 안 만든다"
				% [n.name, String(OCCLUDER_GROUP), String(OCCLUDE_R_META)])
			continue
		var r := float(n.get_meta(OCCLUDE_R_META, 0.0))
		if r <= 0.0:
			continue
		_all_occluders.append(Vector3(n.global_position.x, n.global_position.y, r))


## 🔴 **공개 문 — 목록을 다시 굽는다.** 그물이 안개를 세운 뒤에 엄폐물을 놓기 때문에 필요하고,
##  O5(캐시가 낡는다)의 탈출구이기도 하다. 라이브 게임에서 부르는 곳은 아직 없다.
func rebake_occluders() -> void:
	_bake_occluders()


## 🔴🔴 **이번 프레임에 「그늘을 만들 수 있는」 것만 고른다** — 셰이더 루프가 픽셀마다 도는 값이라
##  여기서 걷어내는 한 개가 화면 전체에서 50만 번씩 절약된다.
##
## 세 필터 전부 **답을 안 바꾼다**(`Vision.is_seen`이 같은 결론을 내는 것들만 뺀다):
##  ⓐ **보는 쪽이 원 안** — `Vision._blocked`의 끝점 규칙이 그 엄폐물을 통째로 건너뛴다.
##     🔴 여기서 빼 두면 셰이더가 픽셀마다 다시 잴 필요가 없다(그래서 셰이더엔 origin 검사가 없다).
##  ⓑ **`fan_range + r`보다 멀다** — 시선은 길어야 `fan_range`라 그보다 먼 원엔 닿지 않는다.
##  ⓒ **쐐기 밖** — 부채꼴이 볼록할 때(<180°)만 쓴다. 원점이 꼭짓점이고 대상이 쐐기 안이면
##     선분 전체가 쐐기 안이므로, 쐐기와 안 겹치는 원은 어떤 시선도 못 끊는다.
##     원의 각 반폭은 `asin(r/d)`다. ⚠ **180° 이상이면 쐐기가 볼록이 아니라** 이 논리가 깨진다 —
##      그래서 조건을 달았다(전방위 폴백 360°가 실제로 그 자리다).
##
## 🔴 그러고도 상한을 넘으면 **가까운 것부터** 남긴다(먼 것은 그늘이 화면 밖으로 나간다) —
##  이건 답을 바꿀 수 있는 **유일한** 자리라 잘린 수를 `occluder_overflow()`로 밖에 내놓는다.
func _refresh_live(origin: Vector2, aim: Vector2) -> void:
	_live = PackedVector3Array()
	_overflow = 0
	if _all_occluders.is_empty():
		_upload_live()
		return
	var rng: float = BAL.vision_fan_range
	var half := deg_to_rad(float(BAL.vision_fan_deg) * 0.5)
	var convex: bool = float(BAL.vision_fan_deg) < 180.0
	var picked: Array[Vector3] = []
	for o: Vector3 in _all_occluders:
		var to_c := Vector2(o.x, o.y) - origin
		var d := to_c.length()
		if d <= o.z:
			continue                                        # ⓐ
		if d > rng + o.z:
			continue                                        # ⓑ
		if convex and absf(aim.angle_to(to_c)) > half + asin(clampf(o.z / d, 0.0, 1.0)):
			continue                                        # ⓒ
		picked.append(o)
	if picked.size() > MAX_OCCLUDERS:
		picked.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return origin.distance_squared_to(Vector2(a.x, a.y)) \
				< origin.distance_squared_to(Vector2(b.x, b.y)))
		_overflow = picked.size() - MAX_OCCLUDERS
		picked.resize(MAX_OCCLUDERS)
		if not _overflow_warned:
			_overflow_warned = true
			push_warning("vision_overlay: 엄폐물이 상한 %d를 넘어 %d개를 잘랐다 — 먼 그늘이 사라진다"
				% [MAX_OCCLUDERS, _overflow])
	for o in picked:
		_live.append(o)
	_upload_live()


func _upload_live() -> void:
	# ⚠ 빈 배열을 넘기면 드라이버가 배열 uniform을 통째로 무시할 수 있다 — 개수가 0이면
	#  셰이더가 루프를 안 도니 **배열은 그대로 두고 개수만** 내린다.
	if not _live.is_empty():
		_mat.set_shader_parameter(&"occluders", _live)
	_mat.set_shader_parameter(&"occluder_count", _live.size())


## 🔴 **상한에 걸려 잘린 개수** — 0이 정상이다. 「조용히 잘림」이 그물에 잡히게 밖으로 연다.
func occluder_overflow() -> int:
	return _overflow


## 🔴 이번 프레임에 화면이 실제로 쓴 엄폐물 — **그물이 `Vision.is_seen`에 넘겨 대조하는 목록**이다.
func live_occluders() -> PackedVector3Array:
	return _live


## 🔴🔴 **구운 전량의 개수** — 「언제 굽나」의 유일한 관측점이다.
##  `_ready`에서 구우면 방이 프롭을 세우기 **전**이라 이 값이 **0**이 되는데, 화면은 그냥
##  「그늘이 없는 숲」으로 보이고 **에러가 0이다**(설계 §3-2 · F5). 그물이 이 값을
##  `occluders` 그룹 크기와 대조해서 그 사고를 잡는다.
func baked_occluder_count() -> int:
	return _all_occluders.size()


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
## 🔴🔴 **세105: 차폐도 여기를 지난다.** `vision_occlusion_design` §2-5는 *"안개에 목록을 넘기지
##  마라"*였는데 **그건 ⓓ(화면에 그림자를 안 그린다)를 전제로 한 문장**이고, 그 문서 자체가
##  *"⚠ 나중에 ⓓ를 뒤집어 셰이더에 그림자를 넣기로 하면 **셰이더와 `lit_at`을 같이** 열어라"*고
##  적어 뒀다. 지금이 그때다 — 셰이더가 그늘을 그리는데 이 함수가 모르면 **관측점이 화면을 안 비추고**,
##  이 리포가 세104에 *"전제가 틀리면 그물이 그걸 굳힌다"*로 적은 자리가 그대로 재현된다.
## 🔴 넘기는 목록은 **셰이더에 실은 바로 그것**(`_live`)이다 — 전량(`_all_occluders`)을 넘기면
##  상한에 걸려 잘린 판에서 화면과 답이 갈린다.
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
	return Vision.is_seen(origin, aim, world, deg, range_px, near_px, _live)
