extends Label
## 계측 표시. 텍스트는 `liquid_sandbox.gd`가 채운다 — **여기가 하는 일은 마우스를 안 먹는 것이다.**
##
## 🔴🔴 이 프로토타입이 죽는 1번 방식이 `mouse_filter`다. 샌드박스는 **전부 마우스로 도는데**
##  HUD가 `Control`이다. `Panel`·`ColorRect`·컨테이너를 뒷판으로 씌우는 순간 기본값 STOP이
##  좌클릭을 통째로 먹고, **에러는 안 나고 전 스위트는 그린이다**(SKILL.md 최상위 함정).
##  ⇒ `Label` 기본값이 IGNORE라도 **명시**하고, 나중에 누가 붙일 자식까지 훑어 강제한다.
## ⚠ 헤드리스는 절대 못 잡는다 — **실게임 클릭 주입**으로만 확정된다(SKILL.md §3 ①).
## ⚠ 이 HUD에는 뒤를 막아야 하는 모달이 없다. 모달이 생기면 그건 STOP이 맞으니 여기서 빼라.


func _ready() -> void:
	_force_ignore(get_parent())


func _force_ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Node in n.get_children():
		_force_ignore(c)
