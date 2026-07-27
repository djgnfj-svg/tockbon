extends Sprite2D
## 🪦 늑대 둥지 (세99 D3·D4 지점) — **겉모습 · 바닥 접점 · 열림 판정**을 진다.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` §3 · §10 · 아트 = `docs/_reports/nest_art.md`.
##
## 🔴🔴 **소유권 — 여기서 끝나는 것과 부모가 지는 것** (설계 §3 소유권 ⓐⓑ · 세101에 실제로 갈랐다):
##  • **여기(props)** = 겉모습 · 열림 판정 · **재열기 가드** · 프롬프트. 열리면 `opened`를 쏜다.
##  • **부모(`boss_room`, field)** = 그 시그널을 받아 `LandmarkDef.drops`를 굴려 낱개로 뿌린다.
##  🔴 **여기서 `src/field/`를 물면 안 된다** — 리포의 preload 방향은 **field → props 단방향**이고
##   그 반대는 **한 건도 없다**(`LandmarkDef` 머리말이 못 박았다 · takbon-rules §0). 지점 씬이
##   `drop_roll.gd`나 `forest_enemy.tscn`을 물면 그 방향이 **처음으로 뒤집힌다.**
##   ⚠ 그래서 이 파일엔 `DropEntry`·`Db`·굴림이 한 글자도 없다. 넣고 싶어지면 그게 위반 신호다.
##  ⚠ **적 스폰도 마찬가지다** — 우두머리(`NamedSpawn.at_landmark`)를 세우는 것도 방이 한다.
##
## 🔴 **상태는 둘뿐이다 — 텍스처 2장 교체**(art 리포트 §「dev에게」). `AnimatedSprite2D`가 아니다:
##  애니가 없고 태그를 쓸 이유가 없다. 비워짐으로 넘기는 문은 `set_broken()` 하나이고,
##  세101에 그 문을 부르는 곳이 생겼다(`_on_open_interacted` — 「열었다」가 곧 「비워졌다」다).
## ✅ **두 컷의 접지선이 텍스처 y=140으로 같다**(art가 일부러 밑변 표를 공유시켰다) — 갈아 끼워도
##  위치가 안 튄다. 그래서 상태 전환에 좌표 보정이 **필요 없다.**
##
## 🔴🔴 **`preload`가 아니라 `load` + null 가드인 이유**(나무는 `preload`를 쓴다 — 일부러 갈랐다):
##  `.import` 사이드카가 없는 PNG를 `preload`하면 **스크립트 컴파일이 통째로 죽어** 이 씬이
##  인스턴스조차 안 되고 **방 전체가 못 선다.** `load` + 가드면 「둥지만 안 보인다」로 **번짐이 멎고**,
##  무엇이 빠졌는지 로그가 말한다. ✅ 세99에 리드가 `--import`를 돌려 지금은 정상이다 —
##  **가드는 남겨 둬라**(에셋을 옮기거나 `.godot/`를 지우는 날 다시 이 자리로 온다).
##
## 🔴🔴 **감지 상자(`nest.tscn`의 `BehindSense`)의 치수 근거** — 세100에 `.tscn` 주석에서 **여기로
##  옮겼다**. `.tscn`의 `;` 주석은 **에디터·`ResourceSaver`가 그 파일을 저장하면 통째로 증발한다**
##  (takbon-rules §5). 이 셋은 사본이 없어서 증발하면 「왜 이 숫자인가」가 영영 사라진다:
##  ⓐ **덮는 범위 = 흙더미 위쪽뿐**이다. 크기 **176×96** = 흙더미 폭(텍스처 x 12..186 = 174)
##     + 몸통 높이 44 + 마른 가지 아랫도리 ~52. 자리 `(4,-48)`이라 **아래 변이 정확히 원점(y=0)**이다.
##  ⓑ 🔴 **아래로 안 내리는 게 계약이다** — 접지선보다 **아래**(남쪽)에 선 플레이어는 둥지 **앞**이라
##     가릴 이유가 없다(그때 둥지는 z 0으로 남아 원래대로 몸 뒤에 그려진다). 각도 계산이 필요 없는
##     이유가 이것이다: **위/아래가 곧 원근**이다.
##  ⓒ 🔴 **가지 끝(원점 위 140px)까지 안 덮는다** — 거기까지 덮으면 둥지 북쪽을 지날 때마다 화면의
##     큰 물건이 흐려져 **「랜드마크가 깜빡인다」**가 된다. 실제로 몸이 가려지는 자리는 여기까지다.
##  🔴 그물 = `test_landmark_road_auto` **[5]**(아래 변이 접지선 위인가 — 형상에서 파생해 잰다) +
##   **[9]ⓑ**(접지선 바로 아래 20px에 서면 안 잡히나). 세99엔 [9]ⓑ 프로브가 260px이나 떨어져 있어
##   **상자를 아래로 250px 늘려도 전 스위트가 그린이었다**(세100 N25ⓑ에 당겼다).
##  ⚠ **그림을 다시 그려 상자를 키우거든 위로만 키워라** — 아래로 새는 순간 위 둘이 빨개진다.
##
## 🔴 **z / 겹침은 나무(`tree.gd`)와 같은 계약이다** — 보스방엔 y-sort가 없어서 **둘을 같이** 해야 한다:
##  ⓐ 앞으로 끌어오고(`z_index`) ⓑ 비친다(`modulate:a`). 하나만 하면 「아무 일도 안 난다」거나
##  「몸이 통째로 사라진다」 중 하나가 되고 **에러는 0이다.** 그래서 한 함수(`_set_seen_through`)가 쥔다.
##  ⚠ **밑동보다 아래(남쪽)에 선 플레이어는 「앞」이라 안 건드린다** — 감지 상자를 원점 위쪽에만 둬서
##   (`nest.tscn`의 `BehindSense`) 각도 계산 없이 그 판정이 공짜로 나온다.
##  ⚠ 나무와 **코드가 닮았지만 사본이 아니다**: 상자 크기·알파가 물건 크기에서 나온다(둥지는 178×121로
##   나무의 3배라 같은 값이면 화면 절반이 흐려진다). 🔴 **세 번째 프롭이 같은 걸 원하면 그때 뽑아라** —
##   지금 공용 부모를 만들면 소비자 둘짜리 추상이 되고, 나무 쪽 그물(`test_daylight_tree_auto`)까지
##   같이 흔들린다.
##
## ⚠ **물리 몸이 없다**(StaticBody2D 아님) — world 레이어에 두면 마법 캐리어(마스크 5)가 둥지마다
##  터진다(나무가 장식인 이유와 같다 — `boss_room.gd` 머리말).
##  ⚠ Area는 **둘**이다: `BehindSense`(layer 0 · 겹침 감지)와 `OpenZone`(layer 64 · 상호작용).
##   둘 다 world(1)·enemy(4) 비트를 안 켠 게 그 계약의 실질이다 — 캐리어 마스크가 5라서다.
##
## ═══ 열기 (세101 N26 3단계 · D10·D11) ══════════════════════════════════════════
##
## 🔴🔴 **[E] 한 번에 즉시 열리고, 한 판에 한 번뿐이다.**
##  • **즉시**(D10) — 사용자 확정 *"e는 한번만 누르면 상자가 열리는 걸로 타르코프 장르기본"*.
##    홀드는 **「나간다」 하나만** 뜻해야 어휘가 안 겹친다(탈출구 3초 꾹). 그래서 `OpenZone`의
##    `hold_sec`은 **0**이고 씬에 그 줄이 아예 없다.
##  • **한 번뿐**(D11) — 🔴🔴 **재열기 가드가 이 파일의 심장이다**(설계 §10-4 **S25**). 안 걸면
##    **계속 나온다** → 다 치운 뒤 안전한 자리에서 **무한 파밍이 최적 전략**이 되어 GDD §6
##    *"살아서 나간다"*가 통째로 죽는다. 🔴 **즉시 열기라 연타로 재현되고 에러가 0이다**
##    (홀드가 완충 노릇을 하지 않는다).
##  • 🔴 **연 상태를 세이브에 넣지 마라**(S19) — 방은 매 판 새로 서므로 **노드가 들면 다음 판에
##    저절로 다시 찬다**. `GameState`에 넣는 순간 **영영 빈 둥지**가 되는데 화면은 정상이다.
##    그래서 상태의 소유자는 `_broken` **하나**이고 아무 데도 안 새어 나간다.
##  • 🔴 **소진 뒤엔 프롬프트도 같이 끈다** — 안 끄면 *"눌렀는데 아무 일도 안 난다"*가 된다(S25 끝줄).
##
## ⚠ **우두머리는 잠금이 아니다**(D10-b) — 잡든 말든 열린다. 「잡아야 열린다」를 여기 얹지 마라.

## 열렸다 — 🔴 **산출은 부모가 굴린다**(머리말 소유권). 여기서 무엇이 나오는지 **알지도 못한다**.
##  ⚠ 인자가 없는 게 계약이다: 어느 지점인지는 **부모가 노드↔id를 쥐고 있다**(`boss_room` 쪽 meta).
signal opened

## 🔴 상호작용 지점의 **타입**만 문다(씬은 `nest.tscn`이 인스턴스한다). 타입이 있어야
##  `zone.interacted`가 컴파일타임에 잡힌다 — `Area2D`로만 두면 시그널 이름을 문자열로 넘겨야 하고
##  그 오타는 **에러 없이 조용히 연결이 안 된다.**
## ✅ 순환 preload가 아니다 — `interact_zone.gd`는 아무것도 안 문다(씬끼리 PackedScene을 무는
##  세26 함정과 무관하다. 여기서 무는 건 **씬이 아니라 스크립트**다).
const InteractZone := preload("res://src/actors/interact_zone.gd")

## 🔴 **경로 상수다**(preload가 아니다 — 머리말 참조). 파일명이 곧 계약이라 여기 한 곳에만 적는다.
const TEX_INTACT := "res://assets/sprites/props/nest_wolf.png"
const TEX_BROKEN := "res://assets/sprites/props/nest_wolf_broken.png"

## 연출값 (손맛) — 밸런스가 아니라 **보이는 값**이라 balance.tres가 아니라 여기 산다.
## 🔴 `OCCLUDE_Z = 4`는 나무와 **같은 자리**다: 플레이어 스프라이트(2)·떠있는 지팡이(3) 바로 위이고,
##  날아가는 마법(RingSpellSystem z 10)보다는 아래다(더 올리면 「내 마법이 둥지 뒤로 사라진다」).
## ⚠ `FADE_ALPHA`가 나무(0.45)보다 높다 — 둥지는 **랜드마크**라 흐려져도 「저기 목적지가 있다」가
##  남아야 한다. 나무는 사라져도 되지만 이건 길이 가리키는 물건이다.
const FADE_ALPHA := 0.5
const FADE_SEC := 0.14
const OCCLUDE_Z := 4
const BASE_Z := 0

var _broken: bool = false
## 지금 이 둥지 뒤에 서 있는 몸의 수 (플레이어 하나지만 적까지 넓힐 때 그대로 쓴다).
var _behind: int = 0
var _fade: Tween = null

@onready var _sense: Area2D = $BehindSense
## 🔴 상호작용은 **공용 `interact_zone.gd`**를 그대로 쓴다(설계 §10-4 S21) — 프롬프트 표시·범위
##  판정·`interacted` 신호·모달 중 잠금이 이미 그 안에 있다. **자체 상호작용을 짜면 그게 함정이다**
##  (관측점이 두 벌이 되어 그물이 갈린다 — S17이 드롭 기계에 대해 한 말과 같은 형태).
@onready var _open_zone: InteractZone = $OpenZone
@onready var _open_prompt: Label = $OpenZone/Prompt


func _ready() -> void:
	_apply_texture()
	_sense.body_entered.connect(_on_behind_entered)
	_sense.body_exited.connect(_on_behind_exited)
	_open_zone.interacted.connect(_on_open_interacted)


## 🔴 **「비워졌다」로 넘기는 유일한 문** — 열기가 이 문을 지나고, 나중에 「핵을 깼다」·「무리를
## 전멸시켰다」가 붙어도 같은 문을 지난다.
## ⚠ **겉모습만 바꾼다 — 프롬프트·구역은 안 건드린다.** 트리 밖 인스턴스에도 부를 수 있어야 하고
##  (`test_landmark_road_auto [4]`가 `add_child` 없이 왕복시킨다) `@onready`가 거기선 null이다.
##  「연 뒤의 뒷정리」는 `_on_open_interacted`가 한 자리에서 진다.
func set_broken(on: bool) -> void:
	if _broken == on:
		return
	_broken = on
	_apply_texture()


func is_broken() -> bool:
	return _broken


## 🔴🔴 **[E]를 눌렀다 — D10·D11이 여기 한 함수에 다 들어 있다**(설계 §10-4 S25).
##
## 🔴 **가드·겉모습·프롬프트·발신이 한 원자다.** 나누면 어느 하나가 빠져도 화면이 멀쩡해서
##  에러 0으로 지나간다:
##   • 가드가 빠지면 → **연타로 무한 파밍**(D11 무효 · GDD §6 정면 충돌)
##   • `set_broken`이 빠지면 → 열었는지 아닌지 **화면에서 구분이 안 간다**(S20 — 「한 번만」이
##     플레이어에게 **보이지 않는 규칙**이 된다)
##   • 프롬프트를 안 끄면 → *"눌렀는데 아무 일도 안 난다"*
## ✅ `set_broken`이 동기라 **`opened.emit()` 시점엔 이미 `is_broken()`이 참**이다 — 수신자가
##  같은 프레임에 무엇을 하든 두 번 열리지 않는다.
func _on_open_interacted() -> void:
	# 🔴🔴 재열기 가드 (S25). ⚠ 이미 비워진 채로 들어올 수도 있다(밖에서 `set_broken(true)`를
	#  부른 경우) — 그때도 **문구는 내린다**. 안 그러면 「누를 수는 있는데 아무 일도 안 나는」
	#  프롬프트가 화면에 남는다.
	if _broken:
		_close_open_zone()
		return
	set_broken(true)
	_close_open_zone()
	opened.emit()


## 소진 — 다시는 안 열린다. 🔴 **둘을 같이** 해야 한다:
##  ⓐ `monitoring = false` — 안 끄면 걸어 나갔다 다시 들어오는 순간 `InteractZone`이 **스스로**
##     프롬프트를 다시 켠다(그게 그 스크립트의 계약이다). 즉 ⓑ만 하면 한 번 걸었다 풀린다.
##  ⓑ 문구를 **직접** 내린다 — `monitoring`을 끄면 `body_exited`가 온다는 보장에 기대지 않는다.
## ⚠ `set_deferred` — 물리 콜백 중에 감시 상태를 바꾸면 엔진이 짖는다(여기선 입력 경로지만,
##  같은 함수가 나중에 충돌 콜백에서 불릴 수 있으므로 안전한 쪽으로 통일한다).
func _close_open_zone() -> void:
	if _open_zone != null:
		_open_zone.set_deferred(&"monitoring", false)
	if _open_prompt != null:
		_open_prompt.visible = false


## 🔴 지금 화면에 [E] 안내가 떠 있나 — **헤드리스 관측점이다**(`charge_band_visible()` 선례).
##  내부 필드를 더듬지 않고 「소진 뒤에 문구가 꺼졌나」를 잴 수 있어야 S25의 끝줄이 측정된다.
func open_prompt_visible() -> bool:
	return _open_prompt != null and _open_prompt.visible


func _apply_texture() -> void:
	var path := TEX_BROKEN if _broken else TEX_INTACT
	var tex := load(path) as Texture2D
	if tex == null:
		# 🔴 침묵 금지 — 안 짖으면 「지점이 데이터대로 섰는데 화면엔 아무것도 없다」가 된다(에러 0).
		push_error("nest: '%s'를 못 읽었다 — PNG는 있는데 `.import` 사이드카가 없으면 여기로 온다 (리드의 --import 필요). 둥지가 안 보인다" % path)
		return
	texture = tex


func _on_behind_entered(_body: Node2D) -> void:
	_behind += 1
	if _behind == 1:
		_set_seen_through(true)


## ⚠ `maxi(...,0)` — 씬 전환·free 순서에 따라 exited가 한 번 더 올 수 있다. 음수로 내려가면
##  다음 입장에서 `_behind == 1`이 영영 안 맞아 **다시는 안 비친다**(에러 0 — tree.gd가 밟은 자리).
func _on_behind_exited(_body: Node2D) -> void:
	_behind = maxi(_behind - 1, 0)
	if _behind == 0:
		_set_seen_through(false)


## 🔴 앞으로 끌어오기(z)와 비치기(alpha)를 **한 자리에서** 쥔다 — 머리말 ⓐⓑ 참조.
## z는 즉시 바꾼다: 켤 때 안 올리면 흐려지기만 하고 여전히 몸 뒤라 화면이 안 변하고,
## 끌 때 안 내리면 **다 비친 뒤에도 둥지가 몸 앞에 남는다**(밑동 아래 = 둥지 앞인데 앞뒤가 뒤집힌다).
func _set_seen_through(on: bool) -> void:
	z_index = OCCLUDE_Z if on else BASE_Z
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", FADE_ALPHA if on else 1.0, FADE_SEC)
