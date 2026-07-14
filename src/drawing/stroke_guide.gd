extends RefCounted
## 본보기 자석 — 종이에 놓인 본보기(trace) 위를 손으로 그으면 획이 그 선으로 **끌린다**.
## 순수 정적 함수 — 씬·오토로드 의존 없음(헤드리스 테스트 가능).
## 사용: const StrokeGuide := preload("res://src/drawing/stroke_guide.gd")
##
## 조작은 **스탬프와 같은 문법**이다 (사용자 확정): 책자에서 누르면 마우스에 붙고, 종이를
## 누르면 그 자리에 놓인다. 배치·크기(휠)·회전(Shift+휠)은 캔버스가 맡고, 이 파일은
## **끌어당김 계산만** 한다.
##
## 🔴 **본보기는 획이 아니다.** 잉크를 안 먹고 인식되지도 않는다 — 손으로 그어야 획이 된다.
## 그래서 크기를 벗어나 그려도 된다: 자석은 SNAP_RADIUS 안에서만 걸리고, 그 밖이면 **손이 이긴다.**
## 이게 게임 축을 살린다 — 룬 크기 = 농도(v1.7), 문양 길이 = 세기(v1.9)라서, 본보기가 크기를
## 강제하면 다들 같은 크기로 그리게 되어 그 두 축이 통째로 죽는다. 본보기는 **제안**일 뿐이다.

## 자석이 미치는 거리. 이 밖이면 아예 안 끌린다 — 본보기가 손을 납치하면 안 된다.
## 캔버스 정규 단위(0..1) 기준값 — 호출자가 자기 좌표계로 환산해 pull에 넘긴다.
## 종이의 8% — 이보다 좁으면 선 바로 위를 지날 때만 붙어서 **붙는 느낌이 안 난다**
const SNAP_RADIUS := 0.08


## 그리는 중인 점 하나를 본보기 쪽으로 끌어당긴다. 본보기가 없거나 멀면 **원점 그대로**.
## strength: 0..1 (GameState.stroke_correction — **아이템이 올린다**: 좋은 붓이 형을 잡아 준다).
## snap_radius: 자석이 미치는 거리. **p·guide_pts와 같은 좌표계로** 넘길 것 (캔버스는 종이 픽셀,
## 테스트는 정규 — 그래서 상수를 박지 않고 인자로 받는다).
## 선에 가까울수록 강하게 붙고 자석 반경 끝에서 0이 된다 — 경계에서 획이 툭 끊기지 않는다.
static func pull(p: Vector2, guide_pts: PackedVector2Array, strength: float,
		snap_radius: float) -> Vector2:
	if guide_pts.size() < 2 or strength <= 0.001 or snap_radius <= 1e-9:
		return p
	var q := nearest_on_polyline(p, guide_pts)
	var d := p.distance_to(q)
	if d >= snap_radius:
		return p
	return p.lerp(q, strength * (1.0 - d / snap_radius))


## 폴리라인 위에서 p에 가장 가까운 점.
## **꼭짓점만 보면 안 된다** — 점 사이가 성기면 획이 계단처럼 툭툭 붙는다. 선분에 투영한다.
static func nearest_on_polyline(p: Vector2, pts: PackedVector2Array) -> Vector2:
	var best := pts[0]
	var best_d := INF
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var ab := pts[i] - a
		var len_sq := ab.length_squared()
		var q := a if len_sq <= 1e-12 \
			else a + ab * clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best
