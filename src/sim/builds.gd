class_name Builds
## **The buildings that can stand on the island — READ FROM A FILE, not written here.**
##
## ⚠⚠ **`blend/buildings.blend` is the source of the SHAPE, and this file's table has no source any
## more.** `assets/buildings/buildings.glb` (what the game DRAWS) and `assets/buildings/buildings.json`
## (what the game KNOWS: the kind, its footprint in tiles, and its name) were written by one run of a
## script that was deleted 2026-08-31 with `tools/blender/`.
## ⚠⚠ **THEY CAN NOW DISAGREE, WHICH THEY COULD NOT BEFORE.** Resize a building in the `.blend` and
## this table still reports the old footprint. **See the Blender manual** — it carries this trap
## and the commit the deleted script is recoverable from.
##
## ⚠ **This file holds no shape and no picture.** It answers "how many tiles does a keep cover" and
## nothing more, so `sim` stays a thing a net can drive with `.new()` and no tree.
##
## Where a building STANDS is not here: that is the island's business, and `Islands.builds()` reads it
## out of the island file beside the terrain it sits on.

const TABLE_PATH := "res://assets/buildings/buildings.json"

## ⚠ **Loaded once and cached**, exactly as the island's board is. Parsing per call would be work
## nobody asked for, and a `static var` is the only place a static class can keep it.
static var _table: Array = []


## ⚠⚠ **A missing or broken file is a HARD failure, not a silent fallback.** A default table here would
## let the game place a keep whose footprint nobody authored while every check stayed green.
static func _load() -> Array:
	if not _table.is_empty():
		return _table
	var text := FileAccess.get_file_as_string(TABLE_PATH)
	assert(text != "", "buildings.json is missing — see the Blender manual")
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "buildings.json is not an object")
	_table = (parsed as Dictionary)["builds"] as Array
	assert(not _table.is_empty(), "buildings.json lists no buildings")
	return _table


## Every kind, in the order the source file lists them.
static func kinds() -> Array:
	var out := []
	for row in _load():
		out.append(str((row as Dictionary)["kind"]))
	return out


## The row for one kind, or an empty dictionary. **Never a guess**: an unknown kind is a caller's bug
## and a made-up 1x1 footprint would hide it until something walked through a wall.
static func row_of(kind: String) -> Dictionary:
	for row in _load():
		if str((row as Dictionary)["kind"]) == kind:
			return row as Dictionary
	return {}


## How many tiles wide and tall that kind stands. `Vector2i.ZERO` for a kind that is not in the table.
static func footprint_of(kind: String) -> Vector2i:
	var row := row_of(kind)
	if row.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(row["w"]), int(row["h"]))


## What it is called on screen.
static func label_of(kind: String) -> String:
	var row := row_of(kind)
	return "" if row.is_empty() else str(row["label"])


## ⚠ **The keep is the one the run is LOST with** — the user: 「섬 가운데 집이 타면 죽어」. It is named
## here rather than spelled as a string at every call site, so the day it is renamed there is one line
## to change and no silent survivor.
const KEEP := "keep"

## ⚠ **The 창고 is the one the player builds**, and the first one they build (ticket 05-08). Named here
## for the same reason the 성채 is: 짓기 모드 holds a kind, `Hand.build` matches on it and the view asks
## this table for its footprint, and a string spelled at three call sites is three chances to typo a
## mode that silently never places anything.
const STORE := "store"
