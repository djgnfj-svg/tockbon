extends RefCounted
## 몬스터 몸 그림이 **상자와 맞나.** 🔴 `net_sprite.gd`(캐릭터)와 같은 어법이다 —
##  「몬스터로 읽히나」는 원리적으로 못 잰다. 여기가 재는 것은 **크기 계약**과 **정렬 계약**뿐이다.
##
## 🔴🔴 **캐릭터와 다른 자리 하나 — 몬스터는 종류당 그림 한 장이다.** 상태별 칸(`CHAR_FRAMES`)이
##  없다(미정 16번 — 걷기 애니메이션이 아직 없다, `character-sprite`가 선례). ⇒ 여기는
##  `_cells_hold_their_contract`·`_table_stays_inside_the_sheet`에 대응하는 「칸」 검사가 없다 —
##  대신 **그림 전체가 상자 하나**다.
##
## 🔴🔴 **텍스처(`load`)로는 그림의 내용을 못 잰다 — 원본 png를 따로 연다.**
##  `Image.load_from_file`이 임포트를 안 거치고 디스크의 png를 그대로 읽는다(`net_sprite`와 같은 이유).
##
## ⚠ **`.import`가 없으면 첫 줄(텍스처 읽기)이 빨개진다** — 조용히 없어지지 않는다.
##  `assets/monster/*.png`는 이 작업에서 처음 들어온 파일이라, 새 기계에서는 헤드리스
##  `--import`를 한 번 돌려야 한다(2026-08-07, 빌더가 직접 돌려 확인했다).

const Fx := preload("res://src/view/fx_tuning.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const NetSprite := preload("res://tests/nets/net_sprite.gd")


func run(t) -> void:
	_sheets_load_from_the_table(t)
	for kind: int in Defs.ALL:
		_sheet_fits_the_box(t, kind)


## 🔴🔴 **`_sheets`가 `MONSTER_SHEETS`에서 나온다 — 하드코딩된 두 경로가 아니다.**
##  종류마다 값이 있고(양성) 없는 경로로 바꾸면 그 칸만 `null`이 된다(뒤집기로 확인 — 아래 상자).
func _sheets_load_from_the_table(t) -> void:
	var sheets: Dictionary = MonsterView._load_sheets()
	t.eq(sheets.size(), Defs.ALL.size(), "종류 수만큼 그림이 실린다 (%d개)" % Defs.ALL.size())
	for kind: int in Defs.ALL:
		t.ok(sheets.has(kind), "%s 칸이 있다" % Defs.name_of(kind))
		var tex: Variant = sheets.get(kind)
		t.ok(tex != null, "%s 그림을 읽었다 (%s)" % [Defs.name_of(kind), Fx.MONSTER_SHEETS[kind]])


## 🔴🔴 **그림 크기가 표 크기와 같다.** 갈리면 `monster_view`는 여전히 상자 크기로 그리므로
##  (`_draw_monster_body`가 텍스처 픽셀이 아니라 `r.size`를 목적지로 쓴다) 게임은 안 깨지지만
##  **그림이 눈에 띄게 늘어나거나 줄어 보인다** — 그 어긋남을 여기서 값으로 먼저 잡는다.
func _sheet_fits_the_box(t, kind: int) -> void:
	var path: String = Fx.MONSTER_SHEETS[kind]
	var tex: Texture2D = load(path)
	t.ok(tex != null, "%s 시트를 읽는다 (%s)" % [Defs.name_of(kind), path])
	if tex == null:
		t.ok(false, "%s 시트를 못 읽어서 크기 계약을 하나도 못 쟀다" % Defs.name_of(kind))
		return

	t.eq(tex.get_width(), Defs.w_px(kind),
		"%s 시트 폭이 상자 폭과 같다 (%d == %d)" % [Defs.name_of(kind), tex.get_width(), Defs.w_px(kind)])
	t.eq(tex.get_height(), Defs.h_px(kind),
		"%s 시트 높이가 상자 높이와 같다 (%d == %d)" % [Defs.name_of(kind), tex.get_height(), Defs.h_px(kind)])

	# ⚠ 선언을 파일 경로까지 넣어 좁힌다 — `net_sprite`와 같은 이유(사면이 그물 전체에 걸린다).
	t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % path)
	var img := Image.load_from_file(path)
	t.ok(img != null, "%s 원본 png를 연다 (임포트를 안 거친다)" % Defs.name_of(kind))
	if img == null:
		t.ok(false, "%s 원본 png를 못 읽어서 내용 검사를 하나도 못 쟀다" % Defs.name_of(kind))
		return

	# 🔴 png를 고치고 임포트를 안 돌리면 게임은 낡은 `.ctex`를 그리는데 아래는 새 png를 잰다.
	t.eq(Vector2i(img.get_width(), img.get_height()), Vector2i(tex.get_width(), tex.get_height()),
		"%s 원본 png 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)" % Defs.name_of(kind))
	if img.get_width() != tex.get_width() or img.get_height() != tex.get_height():
		t.ok(false, "%s 원본과 텍스처 크기가 갈려서 내용 검사를 하나도 못 쟀다" % Defs.name_of(kind))
		return

	var w := img.get_width()
	var h := img.get_height()
	var box := NetSprite.opaque_bbox(img, 0, 0, w, h)
	t.ok(box.size.x > 0 and box.size.y > 0,
		"%s 그림에 불투명 픽셀이 있다 (bbox %s)" % [Defs.name_of(kind), box])
	if box.size.x <= 0 or box.size.y <= 0:
		return

	# 🔴🔴 **좌우 반전이 상자 안 같은 자리에 앉는 조건**(`net_sprite`와 같은 식) —
	#  `minx + maxx == W-1`이어야 방향을 바꿀 때 몬스터가 안 튄다.
	var minx: int = box.position.x
	var maxx: int = box.position.x + box.size.x - 1
	t.eq(minx + maxx, w - 1,
		"%s의 minx+maxx가 %d다 (좌우 반전이 제자리에 앉는다 · %d+%d)" % [
			Defs.name_of(kind), w - 1, minx, maxx])

	# 🔴 발이 맨 아랫줄에 닿는다 — 캐릭터 접지 칸과 같은 계약(`net_sprite._cells_hold_their_contract`
	#  ③). 몬스터는 공중 포즈가 없으므로(걷기 애니메이션이 아직 없다) 예외가 없다.
	var maxy: int = box.position.y + box.size.y - 1
	t.eq(maxy, h - 1, "%s의 발이 맨 아랫줄에 닿는다 (maxy %d)" % [Defs.name_of(kind), maxy])
