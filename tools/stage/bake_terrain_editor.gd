@tool
extends EditorScript
## 지형 굽기 — 에디터 안에서 돌리는 판. 로직은 `terrain_baker.gd`에 있다(헤드리스판과 공유).
##
## 쓰는 법: 이 파일을 스크립트 에디터에서 열고 우측 상단 "실행"(▶, Ctrl+Shift+X)을 누른다.
## Terrain을 그리고 **씬을 저장(Ctrl+S)한 다음** 눌러야 한다 — 저장 전 상태는 안 읽는다.

const Baker := preload("res://tools/stage/terrain_baker.gd")


func _run() -> void:
	Baker.bake()
