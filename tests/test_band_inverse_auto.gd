extends SceneTree
## 🔴🔴 `rings`(정수 층 배열) ↔ `band_defs`(GlyphRingDef 배열) **왕복** 검증. 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_band_inverse_auto.gd
## 전 항목 통과 시 "TEST_BAND_INVERSE_OK" 출력 후 종료 코드 0.
##
## 발밑 바닥 마법진은 **매핑표 없이** `RingBoard.compose_guide_paths(...)`로 「조립한 그림 자체」를
## 그린다. 그런데 `RingDesign`은 `.tres`에 **정수 배열만** 저장하므로 `band_defs_of`가 되돌린다.
##
## 🔴🔴 **이 파일이 존재하는 이유 = 사본 위험이다.**
##   정방향 규칙(*"모티프를 칸 0..count−1에 채운다"*)은 `layer_rings` **안에** 있다. 역함수가 그
##   규칙을 베끼면 나중에 한쪽만 고쳐 **에러 없이** 갈라진다(발사는 맞는데 바닥 그림만 틀리는 형태라
##   F5로도 늦게 발견된다). 그래서 규칙을 두 번 적지 않고 **왕복 항등식**으로 잰다:
##       layer_rings(band_defs_of(rings)) == RingDesign.layers_of(rings)
##   즉 `layer_rings`를 고치면 여기가 **자동으로** 같이 감시된다.
##
## 🔴 **모티프만 재면 검출력이 반쪽이다** — count가 틀려도 통과한다. 그래서 두 겹으로 잰다:
##   ⓐ 합성된 `GlyphRingDef`의 `motif`·`count`를 **직접** 확인 · ⓑ 왕복 결과를 **칸 단위로** 비교.
##
## ⚠ 자명 통과 방지: 비교 대상이 둘 다 비면 왕복은 **공짜로** 참이다 — 층 수·채워진 칸이 실제로
##   있는지를 매 케이스에서 같이 못 박는다.
##
## 🔴🔴 **이 그물이 못 잡는 것 — 정방향 배치 규칙의 변경**(뮤테이션 실측):
##   `layer_rings`가 칸을 **0..count−1이 아니라 1..count**에 깔도록 바꿔도, 입력을 `layer_rings`로
##   **만들어** 넣은 케이스는 입력까지 같이 밀려 **자기 자신과만 일치**한 채 그린이었다.
##   → ⓐ 그래서 **세이브에서 온 리터럴 `rings`** 케이스를 같이 둔다([2] 끝·[4]·[5]) —
##      라이브에서 vfx가 받는 건 갓 만든 배열이 아니라 `.tres`에서 로드된 정수 배열이다.
##   → ⓑ **정방향 규칙 자체의 그물은 `test_jin_layers_auto [1]`이다**(리터럴로 못 박는다).
##      여기서 그 리터럴을 **또 적지 마라**(사본이 는다).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일되므로 오토로드 식별자·모듈 preload 금지 —
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

# 문양 칸 어휘 (Enums.GlyphCode와 같은 값 — 여기 하드코딩해 모듈 preload를 피한다)
const G_GATHER := 0
const G_RADIATE := 1
const G_SPREAD := 6
const G_EXPLODE := 7
const GLYPH_NONE := -1
const SLOTS := 8

var failures: int = 0
var _board = null
var _db = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		print("TEST_BAND_INVERSE_TIMEOUT — 15초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_db = root.get_node("/root/Db")
	_board = load("res://src/drawing/ring_board.gd")

	_test_premise()
	_test_single_band()
	_test_null_band_keeps_index()
	_test_two_layers()
	_test_legacy_flat_promotes()
	_test_mixed_motif_limit()
	_test_empty_rings()
	_test_synth_def_does_not_lie()

	if failures == 0:
		print("TEST_BAND_INVERSE_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_BAND_INVERSE_FAIL — %d개 실패" % failures)
		quit(1)


# ── [0] 전제 — 이 파일이 쓰는 대조군이 실제로 살아 있나 (🔴 .tres 파싱 침묵사 그물) ──
## 🔴 대조군이 증발하면 아래 케이스들이 **검사 0건으로 그린**이 된다.
func _test_premise() -> void:
	print("[0] 전제: 대조군 문양-고리·2층 진이 Db에 실제로 로드된다")
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var ex = _db.get_glyph_ring(&"gr_explode1")
	var sp = _db.get_glyph_ring(&"gr_spread3")
	_check(r5 != null and int(r5.motif) == G_RADIATE and int(r5.count) == 5,
		"gr_radiate5 = 발산×5 (null이면 .tres가 조용히 거부됐다)")
	_check(ex != null and int(ex.motif) == G_EXPLODE and int(ex.count) == 1, "gr_explode1 = 폭발×1")
	_check(sp != null and int(sp.motif) == G_SPREAD and int(sp.count) == 3, "gr_spread3 = 확산×3")
	# 🔴 2층 케이스(ⓒ)의 전제 — 층이 2개인 도안이 애초에 생기려면 band_count 2인 진이 있어야 한다.
	var g2 = _db.get_jin(&"jin_plain_g2")
	var fu = _db.get_jin(&"jin_fuse")
	_check(g2 != null and int(g2.band_count) == 2, "jin_plain_g2 = 2층 진 (2층 케이스의 존재 근거)")
	_check(fu != null and int(fu.band_count) == 2, "jin_fuse = 2층 진(융합)")


# ── [1] ⓐ 단층 — gr_radiate5(count 5) ──
func _test_single_band() -> void:
	print("[1] ⓐ 단층 gr_radiate5: 왕복 + motif·count 직접 확인")
	var r5 = _db.get_glyph_ring(&"gr_radiate5")
	var rings: Array = _board.layer_rings([r5])          # 정방향 (라이브 패널이 쓰는 그 함수)
	var bd: Array = _board.band_defs_of(rings)           # 🔴 역방향 (이 세션이 만든 것)

	_check(bd.size() == 1, "층 1개 → 밴드 1개 (실제 %d)" % bd.size())
	# 🔴 「모티프가 맞나」만 재면 count가 틀려도 통과한다 — 둘 다 잰다.
	_check(bd.size() == 1 and bd[0] != null and int(bd[0].motif) == G_RADIATE,
		"복원된 모티프 = 발산")
	_check(bd.size() == 1 and bd[0] != null and int(bd[0].count) == 5,
		"복원된 count = 5 (실제 %s)" % (str(bd[0].count) if bd.size() == 1 and bd[0] != null else "없음"))
	_roundtrip(rings, "단층 발산5")


# ── [2] ⓑ 🔴 층 하나가 전부 -1 → null 밴드 · **인덱스가 안 밀린다** ──
## 🔴 여기가 `BAND_RADII[i]` 정렬이 걸리는 자리다. 빈 층을 **건너뛰어** 압축하면 바깥 층이
## 안쪽 반경(0.42)에 그려져 **바닥 마법진이 통째로 어긋난다** — 에러는 0이고 그림만 틀린다.
func _test_null_band_keeps_index() -> void:
	print("[2] ⓑ 🔴 빈 층은 null 밴드로 복원되고 **자리를 지킨다**")
	var ex = _db.get_glyph_ring(&"gr_explode1")

	# 앞이 빈 층 — 압축하면 폭발이 밴드 0(안쪽 반경)으로 올라온다
	var rings_a: Array = _board.layer_rings([null, ex])
	var bd_a: Array = _board.band_defs_of(rings_a)
	_check(bd_a.size() == 2, "빈 층 + 폭발 → 밴드 2개 (실제 %d — 1이면 압축했다)" % bd_a.size())
	_check(bd_a.size() == 2 and bd_a[0] == null, "밴드0 = null (빈 층)")
	_check(bd_a.size() == 2 and bd_a[1] != null and int(bd_a[1].motif) == G_EXPLODE,
		"🔴 폭발은 **밴드1**에 그대로 있다 (밴드0으로 올라오면 반경이 어긋난다)")
	_roundtrip(rings_a, "빈 층 + 폭발")

	# 뒤가 빈 층 — 꼬리를 잘라 먹지 않나
	var rings_b: Array = _board.layer_rings([ex, null])
	var bd_b: Array = _board.band_defs_of(rings_b)
	_check(bd_b.size() == 2 and bd_b[0] != null and bd_b[1] == null,
		"뒤쪽 빈 층도 자리를 지킨다 (실제 %d밴드)" % bd_b.size())
	_roundtrip(rings_b, "폭발 + 빈 층")

	# 층이 **둘 다** 비어도 자리 수는 유지된다 (자명 통과가 아님을 위 케이스들이 이미 못 박는다)
	var rings_c: Array = _board.layer_rings([null, null])
	var bd_c: Array = _board.band_defs_of(rings_c)
	_check(bd_c.size() == 2 and bd_c[0] == null and bd_c[1] == null,
		"빈 층 2개 → null 밴드 2개 (실제 %d)" % bd_c.size())

	# 🔴🔴 **저장된 도안 그대로**(리터럴) — 위 케이스들은 입력을 `layer_rings`로 **만들어** 넣는다.
	# 그러면 정방향 규칙이 바뀔 때 입력도 같이 바뀌어 **왕복이 자기 자신과만 일치**하고 넘어간다
	# (뮤테이션 실측: 정방향 배치를 칸 1..로 밀었더니 생성 입력 케이스는 전부 그린이었다).
	# 라이브에서 vfx가 받는 `rings`는 **세이브에서 온 정수 배열**이지 갓 만든 것이 아니므로,
	# 여기서 그 형태를 그대로 먹인다. 🔴 정방향 배치 자체의 그물은 `test_jin_layers_auto [1]`이다.
	var saved: Array = [
		[GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE],
		[G_EXPLODE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE, GLYPH_NONE],
	]
	var bd_s: Array = _board.band_defs_of(saved)
	_check(bd_s.size() == 2 and bd_s[0] == null
		and bd_s[1] != null and int(bd_s[1].motif) == G_EXPLODE and int(bd_s[1].count) == 1,
		"🔴 세이브에서 온 리터럴 rings도 [null, 폭발×1]로 복원된다")
	_roundtrip(saved, "세이브 리터럴(빈 층 + 폭발)")


# ── [3] ⓒ 2층 (band_count 2 진) ──
func _test_two_layers() -> void:
	print("[3] ⓒ 2층: 층 순서 = 밴드 순서 (안→밖 = 연산 순서)")
	var sp = _db.get_glyph_ring(&"gr_spread3")
	var ex = _db.get_glyph_ring(&"gr_explode1")
	var rings: Array = _board.layer_rings([sp, ex])
	var bd: Array = _board.band_defs_of(rings)

	_check(bd.size() == 2, "층 2개 → 밴드 2개 (실제 %d)" % bd.size())
	if bd.size() == 2 and bd[0] != null and bd[1] != null:
		_check(int(bd[0].motif) == G_SPREAD and int(bd[0].count) == 3, "밴드0 = 확산×3")
		_check(int(bd[1].motif) == G_EXPLODE and int(bd[1].count) == 1, "밴드1 = 폭발×1")
		# 🔴 순서가 뒤집히면 바닥 마법진이 **도안과 다른 그림**이 된다(안쪽/바깥이 바뀐다)
		_check(int(bd[0].motif) != int(bd[1].motif),
			"두 밴드가 서로 다르다 = 순서 뒤집힘이 검출 가능한 대조군이다")
	else:
		_check(false, "밴드 2개가 둘 다 복원돼야 한다")
	_roundtrip(rings, "확산3 → 폭발1")


# ── [4] 🔴 옛 8칸 한 겹도 왕복한다 — 층 판별을 **core 단일 소스로** 거치는가 ──
## 🔴 `band_defs_of`가 `RingDesign.layers_of`를 안 거치고 스스로 판별하면 여기가 빨개진다
## (`rings[0]`이 칸 값이지 층이 아니다 → 정수를 층으로 착각한다). 판별 사본 금지의 그물이다.
func _test_legacy_flat_promotes() -> void:
	print("[4] 🔴 옛 8칸 한 겹 → 층 1개 승격 (core `layers_of` 재사용의 증명)")
	var flat: Array = [G_RADIATE, G_RADIATE, G_RADIATE, GLYPH_NONE, GLYPH_NONE,
		GLYPH_NONE, GLYPH_NONE, GLYPH_NONE]
	var bd: Array = _board.band_defs_of(flat)
	_check(bd.size() == 1, "8칸 한 겹 → 밴드 1개 (실제 %d)" % bd.size())
	_check(bd.size() == 1 and bd[0] != null and int(bd[0].motif) == G_RADIATE
		and int(bd[0].count) == 3, "발산 3칸 → 발산×3")
	_roundtrip(flat, "옛 8칸 한 겹")


# ── [5] ⚠ 알려진 한계 — 혼합 모티프는 **첫 모티프 + 채워진 칸 수**로 뭉개진다 ──
## 옛 `flatten_bands` 도안은 한 겹에 여러 모티프가 섞여 있는데 `GlyphRingDef` 하나는
## 모티프를 하나만 담는다. 🔴 **발사는 멀쩡하고 그림만 거짓말한다**(발사는 `rings`를 직접 읽는다).
## 여기서 그 한계를 **명시적으로 못 박는다** — 한계가 조용히 바뀌면 이 줄이 빨개져
## `band_defs_of` 주석을 같이 고치게 만든다.
func _test_mixed_motif_limit() -> void:
	print("[5] ⚠ 한계 ⓙ: 한 겹에 섞인 모티프는 첫 모티프로 뭉개진다 (그림만·발사 무관)")
	var mixed: Array = [G_RADIATE, G_RADIATE, G_RADIATE, G_GATHER, G_GATHER,
		G_GATHER, GLYPH_NONE, GLYPH_NONE]
	var bd: Array = _board.band_defs_of(mixed)
	_check(bd.size() == 1 and bd[0] != null and int(bd[0].motif) == G_RADIATE,
		"발산3+응집3 → 첫 모티프(발산)가 층을 대표한다")
	_check(bd.size() == 1 and bd[0] != null and int(bd[0].count) == 6,
		"채워진 칸 수는 보존된다 (6칸 — 개수까지 잃으면 크기가 통째로 틀린다)")
	var back: Array = _board.layer_rings(bd)
	var want: Array = [G_RADIATE, G_RADIATE, G_RADIATE, G_RADIATE, G_RADIATE,
		G_RADIATE, GLYPH_NONE, GLYPH_NONE]
	_check(back.size() == 1 and _same_ring(back[0], want),
		"🔴 이 케이스만 왕복이 **의도적으로** 안 맞는다 = 발산 6개로 그려진다 (실제 %s)"
			% (str(back[0]) if back.size() == 1 else str(back))
		+ " — 해소했다면 이 줄·band_defs_of 주석·설계 ⓙ를 **같이** 고쳐라")


# ── [6] 🔴 빈 rings — 왕복이 성립 안 하는 **유일한** 입력 (정방향이 비단사) ──
## `layer_rings([])`는 발사 계약 때문에 **빈 층 하나를 심는다**(안 그러면 "빈 진도 날아가 몸으로
## 때린다"가 깨진다). 역함수는 심을 근거가 없어 `[]`를 준다 — 이 비대칭을 **모르고 지나가지 않게**
## 여기서 못 박는다(왕복 헬퍼로 재면 그냥 빨개져 원인을 못 찾는다).
func _test_empty_rings() -> void:
	print("[6] 🔴 빈 rings: 밴드 0개 (compose_guide_paths가 진 윤곽·룬만 그린다)")
	var bd: Array = _board.band_defs_of([])
	_check(bd.is_empty(), "rings [] → 밴드 0개 (실제 %d)" % bd.size())
	# 🔴 비대칭의 출처를 그대로 보여 준다 — 정방향은 빈 층 하나를 **심는다**.
	var seeded: Array = _board.layer_rings([])
	_check(seeded.size() == 1,
		"정방향 layer_rings([])는 빈 층 **하나**를 심는다 = 여기만 왕복이 안 맞는 이유 (실제 %d층)"
			% seeded.size())


# ── [7] 🔴 합성본이 「진짜 고리인 척」 하지 않는다 ──
## `GlyphRingDef`의 스키마 기본값은 **실존하는 `gr_radiate5`/"발산 고리 ×5"**다. 그대로 두면
## 합성본이 그럴듯한 정체를 갖고, `Db.get_glyph_ring(gr.id)`가 **엉뚱한 고리**를 돌려준다.
func _test_synth_def_does_not_lie() -> void:
	print("[7] 🔴 합성본은 motif·count만 채운다 — 정체 필드가 거짓말하면 안 된다")
	var g3 = _db.get_glyph_ring(&"gr_gather3")
	var bd: Array = _board.band_defs_of(_board.layer_rings([g3]))
	if bd.size() != 1 or bd[0] == null:
		_check(false, "합성본 1개가 나와야 한다")
		return
	_check(StringName(bd[0].id) == &"",
		"id가 비어 있다 (실제 %s — 기본값 gr_radiate5가 남으면 응집 고리가 발산인 척한다)"
			% str(bd[0].id))
	_check(String(bd[0].display_name) == "",
		"display_name이 비어 있다 (실제 '%s')" % str(bd[0].display_name))
	# ✅ 렌더가 실제로 읽는 둘은 살아 있다 — 정체를 지운 게 그림까지 지운 건 아니다.
	_check(int(bd[0].motif) == G_GATHER and int(bd[0].count) == 3,
		"그래도 motif·count는 복원된다 (glyph_ring_subpaths가 읽는 건 이 둘뿐)")


# ─────────────────────────── 헬퍼 ───────────────────────────

## 🔴 왕복 항등식 — `layer_rings(band_defs_of(rings)) == RingDesign.layers_of(rings)`.
## 층 수 + **칸 단위**로 비교한다(모티프만 보면 count가 틀려도 통과한다).
## ⚠ 자명 통과 방지: 기대값에 채워진 칸이 하나라도 있는지 같이 잰다 — 둘 다 비면 항등식이 공짜다.
func _roundtrip(rings: Array, label: String) -> void:
	var want: Array = RingDesign.layers_of(rings)
	var got: Array = _board.layer_rings(_board.band_defs_of(rings))
	_check(got.size() == want.size(),
		"왕복[%s]: 층 수 보존 (기대 %d · 실제 %d)" % [label, want.size(), got.size()])
	var same := got.size() == want.size()
	if same:
		for i in want.size():
			if not _same_ring(got[i], want[i]):
				same = false
				break
	_check(same, "왕복[%s]: 칸 단위로 동일\n      기대 %s\n      실제 %s" % [label, str(want), str(got)])
	# 🔴 대조군 — 기대값이 전부 빈칸이면 위 비교는 아무것도 증명하지 않는다.
	var filled := 0
	for layer_v in want:
		for g in (layer_v as Array):
			if int(g) != GLYPH_NONE:
				filled += 1
	_check(filled > 0, "왕복[%s]: 기대값에 채워진 칸이 있다 (자명 통과 방지 — 실제 %d칸)"
		% [label, filled])


func _same_ring(a, b) -> bool:
	var ar: Array = a
	var br: Array = b
	if ar.size() != br.size():
		return false
	for i in ar.size():
		if int(ar[i]) != int(br[i]):
			return false
	return true


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ✓ " + label)
	else:
		failures += 1
		print("  ✗ " + label)
