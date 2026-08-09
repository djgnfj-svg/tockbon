extends RefCounted
## Does the monster body sprite **match the box.** Same idiom as `net_sprite.gd` (the character) —
##  "does it read as a monster" cannot be measured in principle. What this file measures is only the
##  **size contract** and the **alignment contract**.
##
## **A monster now has a sheet per state as well as a body sprite** (`Fx.MONSTER_ANIM`), so this file has two
##  halves: the body sprite's box/alignment contract (as before), and the animation table's own contracts.
##
## **What is measurable about an animation is much less than it looks.**
##  - **The frame count in the table against the png width** — a wrong count plays the neighbouring frame's
##    left half forever, and nothing barks. This is the check that earns this file's keep
##  - **Not** "the feet touch the bottom row" per frame, the way the body sprite is measured. **Measured and
##    rejected**: a charging bull leaves the ground on 4 of 9 frames, a leaping rooster on 3 of 9, a dying hen
##    on 6 of 8. **That is the animation working**, and a net demanding it would be a net demanding the beasts
##    never leave the floor. Only frame 0 (the rest pose) is held to it
##  - **Not** `minx + maxx == w - 1` per frame either, for the same reason: a bull leaning into a gore is
##    asymmetric **on purpose** (6 of 17 frames, up to 8px off). The flip contract is the body sprite's
##  - **Never** "the sheet in that slot is the right animation". Point every row at one png and every check
##    here stays green — that is the eye's, in principle (`character_view.pick_state`'s own note)
##
## **The texture (`load`) cannot measure the sprite's content — the original png is opened separately.**
##  `Image.load_from_file` skips the import and reads the png on disk directly (same reason as `net_sprite`).
##
## **Without `.import`, the first line (reading the texture) goes red** — it does not vanish quietly.
##  `assets/monster/*.png` are files that first arrived in this work, so on a new machine a headless
##  `--import` has to be run once (the builder ran it and confirmed).

const Fx := preload("res://src/view/fx_tuning.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const NetSprite := preload("res://tests/nets/net_sprite.gd")
## Only for the `Pattern` values `resolve_state` dispatches on — the same allowance `monster_view.gd` itself
## takes for the same enum.
const BossAi := preload("res://src/actor/boss_ai.gd")

## The states every kind must be able to play, whatever else it has. **Standing, moving and dying** — a mob
##  missing any one of the three is on screen with nothing to show for a moment that always happens.
##  **Attacking is deliberately not in this list**: a rooster's every attack is a pattern, and demanding a
##  `MON_ATTACK` row would force a sheet that nothing would ever draw.
const MUST_HAVE: Array[int] = [Fx.MON_IDLE, Fx.MON_WALK, Fx.MON_DEATH]


func run(t) -> void:
	_sheets_load_from_the_table(t)
	for kind: int in Defs.ALL:
		_sheet_fits_the_box(t, kind)
	_anim_sheets_load_from_the_table(t)
	for kind: int in Defs.ALL:
		_anim_rows_match_their_pngs(t, kind)
	_every_kind_can_stand_walk_and_die(t)
	_state_priority_holds(t)
	_the_clock_loops_or_clamps(t)
	_the_walk_clock_is_x_and_nothing_else(t)
	_a_missing_state_falls_back_to_idle(t)
	_the_corpse_outlives_its_own_death_animation(t)


## **`_sheets` comes from `MONSTER_SHEETS` — not from two hardcoded paths.**
##  Every kind has a value (positive) and swapping in a non-existent path makes only that entry `null`
##  (confirmed by inversion — the box below).
func _sheets_load_from_the_table(t) -> void:
	var sheets: Dictionary = MonsterView._load_sheets()
	t.eq(sheets.size(), Defs.ALL.size(), "종류 수만큼 그림이 실린다 (%d개)" % Defs.ALL.size())
	for kind: int in Defs.ALL:
		t.ok(sheets.has(kind), "%s 칸이 있다" % Defs.name_of(kind))
		var tex: Variant = sheets.get(kind)
		t.ok(tex != null, "%s 그림을 읽었다 (%s)" % [Defs.name_of(kind), Fx.MONSTER_SHEETS[kind]])


## **The sprite size equals the table size.** If they diverge, `monster_view` still draws at box size
##  (`_draw_monster_body` uses `r.size`, not the texture pixels, as the destination), so the game does not
##  break but **the sprite visibly stretches or shrinks** — that mismatch is caught here by value first.
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

	# The declaration is narrowed down to the file path — same reason as `net_sprite` (an amnesty covers the whole run).
	t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % path)
	var img := Image.load_from_file(path)
	t.ok(img != null, "%s 원본 png를 연다 (임포트를 안 거친다)" % Defs.name_of(kind))
	if img == null:
		t.ok(false, "%s 원본 png를 못 읽어서 내용 검사를 하나도 못 쟀다" % Defs.name_of(kind))
		return

	# Fix the png without running the import and the game draws the stale `.ctex` while the code below measures the new png.
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

	# **The condition for a horizontal flip to land in the same place inside the box** (same formula as `net_sprite`) —
	#  `minx + maxx == W-1` must hold or the monster jumps when it changes direction.
	var minx: int = box.position.x
	var maxx: int = box.position.x + box.size.x - 1
	t.eq(minx + maxx, w - 1,
		"%s의 minx+maxx가 %d다 (좌우 반전이 제자리에 앉는다 · %d+%d)" % [
			Defs.name_of(kind), w - 1, minx, maxx])

	# The feet touch the bottom row — the same contract as the character's grounded cells
	# (`net_sprite._cells_hold_their_contract` (3)). This is the **standing** sprite, so there is no airborne
	# exception here; the animation sheets below have one, and the header says why.
	var maxy: int = box.position.y + box.size.y - 1
	t.eq(maxy, h - 1, "%s의 발이 맨 아랫줄에 닿는다 (maxy %d)" % [Defs.name_of(kind), maxy])


# ══════════════════════════════════════════════════════════════════
#  The animation table (`Fx.MONSTER_ANIM`) — `docs/design/monsters.md`, "animation is entirely a code gap"
# ══════════════════════════════════════════════════════════════════

## **Every path in the table loads.** The same shape as `_sheets_load_from_the_table` above and for the same
##  reason — a path typo leaves that one entry `null`, `monster_view` falls back to the body sprite, and the
##  only symptom is "that beast doesn't animate", which nothing else here would notice.
func _anim_sheets_load_from_the_table(t) -> void:
	var sheets: Dictionary = MonsterView._load_anim_sheets()
	t.eq(sheets.size(), Defs.ALL.size(), "종류 수만큼 애니메이션 칸이 있다 (%d개)" % Defs.ALL.size())
	var loaded := 0
	for kind: int in Defs.ALL:
		var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
		var per_state: Dictionary = sheets.get(kind, {})
		t.eq(per_state.size(), rows.size(),
			"%s의 표에 적힌 수만큼 시트를 읽었다 (%d장)" % [Defs.name_of(kind), rows.size()])
		for state: int in rows:
			t.ok(per_state.get(state) != null,
				"%s %d번 상태 시트를 읽었다 (%s)" % [Defs.name_of(kind), state, rows[state]["path"]])
			loaded += 1
	t.ok(loaded >= 24, "시트를 스물넷 이상 읽었다 (%d장 — 표가 통째로 비면 위 검사가 전부 공회전한다)" % loaded)


## **The frame count written in the table equals the png's.** This is the check this section exists for.
##  Write 8 where the sheet holds 9 and the last frame is simply never drawn; write 10 and `frame_src` cuts
##  a cell that is off the right edge of the texture, which draws **transparent** — the beast blinks out for
##  one frame of every loop and **nothing barks.**
##
## Also measured here: the sheet's height is the box height (so no frame is squashed vertically), the png on
##  disk agrees with the imported texture (a stale `.ctex` would make the game draw the old art while every
##  check here measures the new png), **frame 0 stands on the ground**, and no frame is blank.
func _anim_rows_match_their_pngs(t, kind: int) -> void:
	var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
	t.ok(not rows.is_empty(), "%s에 애니메이션 표가 있다" % Defs.name_of(kind))
	var w := Defs.w_px(kind)
	var h := Defs.h_px(kind)
	for state: int in rows:
		var row: Dictionary = rows[state]
		var path: String = row["path"]
		var frames := int(row["frames"])
		var tex: Texture2D = load(path)
		t.ok(tex != null, "%s를 읽는다" % path)
		if tex == null:
			continue
		t.eq(tex.get_width(), frames * w,
			"%s 폭이 칸수 x 상자폭이다 (%d == %d x %d)" % [path, tex.get_width(), frames, w])
		t.eq(tex.get_height(), h, "%s 높이가 상자 높이다 (%d == %d)" % [path, tex.get_height(), h])
		t.ok(int(row["hold"]) > 0, "%s의 hold가 0보다 크다 (0이면 나눗셈이 터진다)" % path)

		# The declaration is narrowed to this path — same reason as `_sheet_fits_the_box` above.
		t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % path)
		var img := Image.load_from_file(path)
		t.ok(img != null, "%s 원본 png를 연다" % path)
		if img == null:
			continue
		t.eq(Vector2i(img.get_width(), img.get_height()),
			Vector2i(tex.get_width(), tex.get_height()),
			"%s 원본 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)" % path)
		if img.get_width() != tex.get_width():
			continue
		# **Every frame has something in it.** A count that is one too high shows up here as a blank cell,
		#  so this and the width check catch the same mistake from two sides.
		for i in frames:
			var b := NetSprite.opaque_bbox(img, i * w, 0, w, h)
			t.ok(b.size.x > 0 and b.size.y > 0, "%s %d번 칸이 비어 있지 않다" % [path, i])
		# **Frame 0 only** — the header records why the other frames are exempt (a charging bull is airborne
		#  on 4 of its 9 frames, and that is the animation working).
		var first := NetSprite.opaque_bbox(img, 0, 0, w, h)
		if first.size.y > 0:
			t.eq(int(first.position.y + first.size.y - 1), h - 1,
				"%s 0번 칸(기본 자세)의 발이 맨 아랫줄에 닿는다" % path)


## Standing, moving and dying exist for every kind (`MUST_HAVE`'s own comment).
func _every_kind_can_stand_walk_and_die(t) -> void:
	for kind: int in Defs.ALL:
		var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
		for state: int in MUST_HAVE:
			t.ok(rows.has(state), "%s에 %d번 상태(서기·걷기·죽기 중 하나)가 있다" % [Defs.name_of(kind), state])


## **The priority in `resolve_state` is a contract, so it is measured as one** (that function's own header).
##
## **Each line here is written so that flipping one branch bites.** Hurt-over-attack and attack-over-walk are
##  each measured with the *other* flag also true — measure them one flag at a time and swapping the two `if`s
##  changes nothing that any check can see.
func _state_priority_holds(t) -> void:
	var pig := Defs.KIND_PIG
	var bull := Defs.KIND_BULL

	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, true, false, false, false), Fx.MON_IDLE,
		"가만히 있으면 서기다")
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, true, false, false, true), Fx.MON_WALK,
		"움직이면 걷기다")
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, true, false, true, true), Fx.MON_ATTACK,
		"때리는 중이면 걷는 중이어도 때리기다 (걷기보다 위)")
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, true, true, true, true), Fx.MON_HURT,
		"맞았으면 때리는 중이어도 맞기다 (때리기보다 위)")

	# **A boss's pattern outranks even being hit** — the screen must not contradict the sim.
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.CHARGE, true, true, true, true), Fx.MON_CHARGE,
		"돌진 중인 황소는 맞아도 돌진이다 (패턴이 맨 위)")
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.WINDUP, true, false, false, false), Fx.MON_WINDUP,
		"준비 동작은 포효다")
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.GORE, true, false, false, false), Fx.MON_ATTACK,
		"들이받기는 때리기다")
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.FIRE, true, false, false, false), Fx.MON_FIRE,
		"불 뿜기는 불이다")
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.LEAP, true, false, false, false), Fx.MON_LEAP,
		"뛰기는 뛰기다 (황소의 내리찍기와 수탉의 도약이 같은 패턴이다)")
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.STUN, true, false, false, false), Fx.MON_STUN,
		"경직은 경직이다")
	# **`Pattern.IDLE` is not `MON_IDLE`** — a boss walks toward the player during IDLE.
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.IDLE, true, false, false, true), Fx.MON_WALK,
		"패턴이 IDLE인 보스는 움직이면 걷는다 (패턴 IDLE = 상태 IDLE이 아니다)")
	# A trash mob never has patterns, so a pattern value it could never hold must not steer it.
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.CHARGE, true, false, false, false), Fx.MON_IDLE,
		"돼지는 패턴 값이 들어와도 무시한다 (has_pattern이 거짓이다)")

	# **Airborne (`monster-ai-jump-and-separation.md`, Stage B) — resolved after hurt, before attack/walk.**
	# Each line measured against the *other* flag also true, the same "flipping one branch bites" discipline
	# this function's own header names for hurt-over-attack above.
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, false, false, false, false), Fx.MON_AIRBORNE,
		"땅에서 떨어지면 뜨기다")
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, false, false, true, true), Fx.MON_AIRBORNE,
		"공중에서 때리는 중이든 걷는 중이든 뜨기가 이긴다 (때리기·걷기보다 위)")
	t.eq(MonsterView.resolve_state(pig, BossAi.Pattern.IDLE, false, true, false, false), Fx.MON_HURT,
		"그런데 맞은 것은 뜬 것보다 위다 (맞기 > 뜨기)")
	# A boss's own pattern still outranks airborne — `Pattern.LEAP` (a real airborne move) must not be
	# overridden by the generic `on_ground` check below it in the priority order.
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.LEAP, false, false, false, false), Fx.MON_LEAP,
		"패턴이 있는 보스는 공중에 떠도 자기 패턴(LEAP)이 이긴다 (범용 AIRBORNE가 아니다)")

	# **Two checks, because "the bosses fall through" is a claim, not a fact** (Stage B's own risk table).
	t.eq(MonsterView.resolve_state(bull, BossAi.Pattern.IDLE, false, false, false, true), Fx.MON_AIRBORNE,
		"IDLE 패턴에 on_ground가 거짓이면, 걷는 중이어도 상태는 AIRBORNE이다")
	t.ok(not (Fx.MONSTER_ANIM[bull] as Dictionary).has(Fx.MON_AIRBORNE),
		"황소에겐 공중 그림이 없다 (전제 — 없어야 아래 대체가 뜻이 있다)")
	t.eq(MonsterView.anim_row(bull, Fx.MON_AIRBORNE), Fx.MONSTER_ANIM[bull][Fx.MON_IDLE],
		"그래서 실제로 그려지는 건 서기 그림이다 (걷던 IDLE 황소가 떨어지면, 걷기가 아니라 서기로 보인다)")


## **Looping wraps, one-shot clamps.** The distinction that makes a death animation stay dead.
func _the_clock_loops_or_clamps(t) -> void:
	var looping := {"path": "", "frames": 4, "hold": 3, "loop": true}
	var once := {"path": "", "frames": 4, "hold": 3, "loop": false}
	t.eq(MonsterView.frame_index(Fx.MON_IDLE, looping, 0, 0), 0, "0프레임째는 0번 칸이다")
	t.eq(MonsterView.frame_index(Fx.MON_IDLE, looping, 2, 0), 0, "hold(3) 안쪽은 아직 0번 칸이다")
	t.eq(MonsterView.frame_index(Fx.MON_IDLE, looping, 3, 0), 1, "hold를 넘기면 다음 칸이다")
	t.eq(MonsterView.frame_index(Fx.MON_IDLE, looping, 12, 0), 0, "반복이면 마지막을 지나 처음으로 돌아온다")
	t.eq(MonsterView.frame_index(Fx.MON_DEATH, once, 12, 0), 3, "한 번짜리는 마지막 칸에 멈춘다")
	t.eq(MonsterView.frame_index(Fx.MON_DEATH, once, 9999, 0), 3, "한참 뒤에도 마지막 칸이다 (시체가 되살아나지 않는다)")
	t.eq(MonsterView.frame_index(Fx.MON_IDLE, {}, 12, 0), 0, "표가 없으면 0번 칸이다 (터지지 않는다)")

	# **The rows above are synthetic, so the real table's own `loop` flags go unmeasured by them.**
	#  Found by inversion: flipping `pig_death` to `loop: true` left all 498 checks green. A looping death
	#  makes the corpse **twitch back to life** halfway through its fade, and a non-looping walk **freezes the
	#  legs** on the last frame while the beast keeps sliding — both are screen-only symptoms.
	for kind: int in Defs.ALL:
		var rows: Dictionary = Fx.MONSTER_ANIM.get(kind, {})
		t.ok(not bool((rows[Fx.MON_DEATH] as Dictionary)["loop"]),
			"%s의 죽기는 반복하지 않는다 (시체가 되살아나지 않는다)" % Defs.name_of(kind))
		for state: int in [Fx.MON_IDLE, Fx.MON_WALK]:
			t.ok(bool((rows[state] as Dictionary)["loop"]),
				"%s의 %d번 상태는 반복한다 (마지막 칸에서 다리가 얼지 않는다)" % [Defs.name_of(kind), state])


## **The walk clock is `x`, and only for `MON_WALK`.** Two clocks for one gait is the bug this splits to
##  avoid (`frame_index`'s own header) — so both halves are measured: walking ignores `t`, and every other
##  state ignores `x`.
func _the_walk_clock_is_x_and_nothing_else(t) -> void:
	var row := {"path": "", "frames": 4, "hold": 3, "loop": true}
	var step := Fx.MONSTER_WALK_PX_PER_FRAME
	t.eq(MonsterView.frame_index(Fx.MON_WALK, row, 0, step), 1, "걷기는 x가 시계다 (%dpx마다 한 칸)" % step)
	t.eq(MonsterView.frame_index(Fx.MON_WALK, row, 999, 0), 0,
		"걷기는 프레임 수를 안 본다 (벽에 막혀 서 있으면 다리도 멈춘다)")
	t.eq(MonsterView.frame_index(Fx.MON_WALK, row, 0, -step), 1,
		"왼쪽으로 걸어도 같은 칸이다 (absi — 좌우 박자가 갈리지 않는다)")
	t.eq(MonsterView.frame_index(Fx.MON_IDLE, row, 0, step * 3), 0, "서기는 x를 안 본다")


## A state a kind has no sheet for falls back to idle, and `oneshot_frames` reports 0 for it —
##  which is what makes `_scan_hp_changes` decline to latch a hurt pose onto a boss that has none.
func _a_missing_state_falls_back_to_idle(t) -> void:
	var bull := Defs.KIND_BULL
	t.ok(not (Fx.MONSTER_ANIM[bull] as Dictionary).has(Fx.MON_HURT),
		"황소에겐 맞기 시트가 없다 (전제 — 있으면 아래 검사가 공회전한다)")
	var row := MonsterView.anim_row(bull, Fx.MON_HURT)
	t.eq(row, Fx.MONSTER_ANIM[bull][Fx.MON_IDLE], "없는 상태는 서기로 떨어진다")
	t.eq(MonsterView.oneshot_frames(bull, Fx.MON_HURT), 0, "없는 상태의 한 번짜리 길이는 0이다 (안 걸린다)")
	t.ok(MonsterView.oneshot_frames(Defs.KIND_PIG, Fx.MON_HURT) > 0, "돼지의 맞기 길이는 0보다 크다")
	t.eq(MonsterView.anim_row(Defs.KIND_NONE, Fx.MON_IDLE), {},
		"표에 없는 종류는 빈 줄이다 (몸통 그림으로 떨어진다)")


## **The corpse must outlive its own death animation.** Shorter and the beast is still mid-fall when the
##  afterimage has fully faded — the animation is then unseeable in principle, which is exactly the state
##  this was in at 30 frames (`MONSTER_CORPSE_LIFE_FRAMES`'s own comment).
func _the_corpse_outlives_its_own_death_animation(t) -> void:
	for kind: int in Defs.ALL:
		var len_frames := MonsterView.oneshot_frames(kind, Fx.MON_DEATH)
		t.ok(len_frames > 0, "%s에 죽기 애니메이션 길이가 있다 (전제)" % Defs.name_of(kind))
		t.ok(Fx.MONSTER_CORPSE_LIFE_FRAMES > len_frames,
			"%s 시체 수명(%d)이 죽기 애니메이션(%d프레임)보다 길다" % [
				Defs.name_of(kind), Fx.MONSTER_CORPSE_LIFE_FRAMES, len_frames])
