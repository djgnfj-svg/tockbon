# **Prints the nine seats instead of photographing them.** A probe, not a picture.
#
#   Godot_v4.7.1-stable_win64.exe --path . --headless -s .prototypes/nine/seat_probe.gd
#
# ⚠⚠ **THIS EXISTS BECAUSE A PIXEL COMPARISON ANSWERED THE WRONG QUESTION** (2026-08-31). 「Does the
# formation turn?」 was measured by differencing two screenshots, and screenshots also carry **each
# body's own idle-sway phase**: move body 4 to a different seat and the picture changes even though the
# NINE SEATS are the same nine points. The pixel number said `06-ranks-wide` turns; the geometry says
# its seat set is identical at south and at east.
#
# ⚠ **`--headless` is fine HERE and nowhere else in this folder** — nothing is rendered, so there is no
# swapchain to read back and nothing to come out black.
extends SceneTree

const DIR := "res://.prototypes/nine"
## Two facings a quarter turn apart. **The whole question is whether a version's seats move between
## them**, so they are the argument rather than a setting.
const FACES := [Vector2(0, 1), Vector2(1, 0)]
const FACE_NAMES := ["south", "east"]
## Anything under this is the same point. Seats are computed in 조각, so this is a hundredth of a
## metre — far below anything the eye could be shown.
const EPS := 0.01


func _initialize() -> void:
	var names := _versions()
	var centre := Vector2.ZERO
	print("[probe] 아홉 자리, 조각 단위. 원점은 블록 한가운데")
	var base := _seats_of(names[1] if names.size() > 1 else names[0], centre, FACES[0])
	for n in names:
		var south := _seats_of(n, centre, FACES[0])
		var east := _seats_of(n, centre, FACES[1])
		print("  %-14s 남→동 자리가 옮겨졌나: %-5s   02-grid 와 같은 자리인가: %s" % [
			n, str(not _same(south, east)), str(_same(south, base))])
	print("[probe] 02-grid 의 아홉 자리: %s" % str(_rows(base)))
	print("[probe] 03-ranks 남쪽:      %s" % str(_rows(_seats_of("03-ranks", centre, FACES[0]))))
	print("[probe] 03-ranks 동쪽:      %s" % str(_rows(_seats_of("03-ranks", centre, FACES[1]))))
	quit()


func _versions() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		if ResourceLoader.exists("%s/%s/scene.gd" % [DIR, name]):
			out.append(name)
	out.sort()
	return out


func _seats_of(name: String, c: Vector2, face: Vector2) -> Array:
	var scr: GDScript = load("%s/%s/scene.gd" % [DIR, name])
	var raw: PackedVector2Array = scr.seats(c, face)
	# **Sorted, because a seat plan is a SET of places and not a list of them.** Two plans that put the
	# same nine men on the same nine spots in a different order are the same plan.
	var out: Array = []
	for p in raw:
		out.append(p)
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if absf(a.x - b.x) > EPS:
			return a.x < b.x
		return a.y < b.y)
	return out


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if (a[i] as Vector2).distance_to(b[i] as Vector2) > EPS:
			return false
	return true


func _rows(a: Array) -> Array:
	var out: Array = []
	for p in a:
		out.append("(%.2f, %.2f)" % [(p as Vector2).x, (p as Vector2).y])
	return out
