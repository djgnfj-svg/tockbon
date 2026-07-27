extends Sprite2D
## 🪦 늑대 둥지 (세99 D3·D4 지점) — **겉모습 + 바닥 접점만** 진다.
## 정본 = `docs/takbon-design/dungeon_structure_design.md` §3 · 아트 = `docs/_reports/nest_art.md`.
##
## 🔴🔴 **장치는 여기 없다** (사용자 확정 *"그냥 간단한데"*) — 무한 스폰·핵 깨기·상호작용은
##  **이번 범위가 아니다.** 설계 §3이 「몹이 계속 기어나온다 / 핵을 깨야 멈춘다」라고 적어 뒀지만
##  지금 이 씬은 **서 있는 물건**이다. 나중에 얹을 때 지켜야 할 소유권만 미리 못 박아 둔다:
##  🔴 **적을 스폰하는 건 지점이 아니라 방이다**(설계 §3 소유권 ⓐ). 여기서 `forest_enemy.tscn`을
##  물면 리포의 preload 방향(field → props 단방향)이 **처음으로 뒤집힌다**(takbon-rules §0 위반).
##  지점은 「지금 하나 내보내라」를 부모에게 **시그널로** 알리고, 세우는 건 `boss_room`이 한다.
##
## 🔴 **상태는 둘뿐이다 — 텍스처 2장 교체**(art 리포트 §「dev에게」). `AnimatedSprite2D`가 아니다:
##  애니가 없고 태그를 쓸 이유가 없다. 지금 쓰는 건 온전함뿐이고, 비워짐으로 넘기는 문은
##  `set_broken()` 하나다 — 그게 나중에 「핵을 깼다」가 이어 붙을 자리다.
## ✅ **두 컷의 접지선이 텍스처 y=140으로 같다**(art가 일부러 밑변 표를 공유시켰다) — 갈아 끼워도
##  위치가 안 튄다. 그래서 상태 전환에 좌표 보정이 **필요 없다.**
##
## 🔴🔴 **`preload`가 아니라 `load` + null 가드인 이유**(나무는 `preload`를 쓴다 — 일부러 갈랐다):
##  `.import` 사이드카가 없는 PNG를 `preload`하면 **스크립트 컴파일이 통째로 죽어** 이 씬이
##  인스턴스조차 안 되고 **방 전체가 못 선다.** `load` + 가드면 「둥지만 안 보인다」로 **번짐이 멎고**,
##  무엇이 빠졌는지 로그가 말한다. ✅ 세99에 리드가 `--import`를 돌려 지금은 정상이다 —
##  **가드는 남겨 둬라**(에셋을 옮기거나 `.godot/`를 지우는 날 다시 이 자리로 온다).
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


func _ready() -> void:
	_apply_texture()
	_sense.body_entered.connect(_on_behind_entered)
	_sense.body_exited.connect(_on_behind_exited)


## 🔴 **「비워졌다」로 넘기는 유일한 문** — 나중에 「핵을 깼다」·「무리를 전멸시켰다」가 여기로 이어진다.
## 지금 부르는 곳은 없다(그래서 상태 기계도 안 만들었다) — **문 하나만 내 둔다.**
func set_broken(on: bool) -> void:
	if _broken == on:
		return
	_broken = on
	_apply_texture()


func is_broken() -> bool:
	return _broken


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
