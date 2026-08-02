extends Label
## 계측 표시. 텍스트는 `liquid_sandbox.gd`가 채운다 — **여기가 하는 일은 마우스를 안 먹는 것이다.**
##
## 🔴🔴 이 프로토타입이 죽는 1번 방식이 `mouse_filter`다. 샌드박스는 **전부 마우스로 도는데**
##  HUD가 `Control`이다. `Panel`·`ColorRect`·컨테이너를 뒷판으로 씌우는 순간 기본값 STOP이
##  좌클릭을 통째로 먹고, **에러는 안 나고 전 스위트는 그린이다**(SKILL.md 최상위 함정).
##  ⇒ `Label` 기본값이 IGNORE라도 **명시**한다.
##
## 🔴🔴 **이 훑기가 덮는 범위를 과장해서 읽지 마라 — 아래 둘은 안 덮는다:**
##  ① **런타임에 `add_child`로 붙는 Control** — `_ready` 한 번만 도는데, 뒷판을 씌우는 사고는
##   정확히 그 방식으로 난다. ② **`HUD` 서브트리 밖의 Control**(루트나 다른 `CanvasLayer`에 붙인 것).
##  ⚠ **범위를 넓히지도 마라** — 씬 전체에 IGNORE를 강제하면 진짜 방어선인 그물이 「강제된 결과」를
##   재게 되어 죽고(T2), 나중에 모달이 STOP으로 뒤를 막아야 할 때 그걸 조용히 뒤엎는다.
##
## 🔴 **진짜 방어선은 `tests/test_sandbox_wiring_auto.gd`다** — 좌클릭을 실제로 주입해
##  「발사 커맨드가 나오나」와 「씬의 모든 Control이 IGNORE인가」를 잰다. **어디에 붙은 Control이든
##  결과로 잡힌다.** (SKILL.md의 *"헤드리스가 절대 못 잡는다"*는 절반만 맞다 —
##  「Control이 먹는 절반」은 `Viewport.push_input`으로 잡히고, 남는 건 창·OS 쪽이다.)
## ⚠ 이 HUD에는 뒤를 막아야 하는 모달이 없다. 모달이 생기면 그건 STOP이 맞으니 여기서 빼라.


func _ready() -> void:
	_force_ignore(get_parent())


func _force_ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Node in n.get_children():
		_force_ignore(c)
