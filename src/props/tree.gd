extends Sprite2D
## 숲 나무 (세션46) — 단색 삼각형 Polygon2D → 도트 스프라이트 3종. **위치에 따라 변형을 랜덤**으로
## 골라 배치 씬(boss_room.tscn 등)을 안 건드리고도 인스턴스마다 다 달라진다.
## 🔴 north(y<-500)=침엽수·마른나무(성긴 심층 = 어두운 바닥 그라디언트와 어울림) · south=활엽수·침엽수
##   (무성한 숲). 밑동(접지점 y=61, 시트 높이 64)이 노드 원점에 오게 offset은 씬에서 -29로 고정.
## randi = Godot 전역(부팅 시드) — 장식이라 세이브에 안 들어간다 (드롭 굴림과 같은 RNG).
##
## 🔴🔴 **세99 — 뒤로 가면 비친다** (사용자 확정 *"나무뒤에 갔을때 나무 투명화"*).
##
## 두 가지를 **같이** 해야 한다. 하나만 하면 아무 일도 안 일어난 것처럼 보인다:
##  ⓐ **앞으로 끌어온다**(`z_index = OCCLUDE_Z`). 보스방엔 y-sort가 없고 노드 순서가 그리는 순서라
##    나무(z 0)는 **언제나** 플레이어 스프라이트(z 2)·지팡이(z 3)보다 뒤다 — 즉 세98까지 플레이어는
##    나무에 **한 번도 안 가려졌다.** 투명화만 넣으면 「안 가리던 게 흐려질 뿐」이라 화면이 그대로다.
##  ⓑ **비친다**(`modulate:a`). ⓐ만 하면 이번엔 나무가 몸을 통째로 먹는다.
##  → 둘을 한 함수(`_set_seen_through`)가 같이 쥔다. **갈라 놓지 마라** — 한쪽만 부르는 경로가
##    생기는 순간 「몸이 사라진다」거나 「아무 일도 안 난다」 중 하나가 되고 **에러는 0이다.**
##
## 🔴 **밑동보다 아래에 선 플레이어는 「앞」이라 안 건드린다** — 감지 상자를 원점 위쪽에만 둬서
##  (tree.tscn `BehindSense`) 각도 계산 없이 그 판정이 공짜로 나온다. 위/아래가 곧 원근이다.
##
## 🔴 **매 프레임 순회가 아니다** — ch1에만 20그루라 「전 나무 × 매 프레임 거리 검사」로 짜면 방이
##  커질수록 비례해 는다. Area2D 두 시그널이 **겹칠 때만** 깨우므로 평상시 스크립트 비용은 0이다.
##
## ⚠ 적까지 넓히려면 **씬의 mask에 4(enemy)를 더하면 끝**이다 — `_behind`가 개수를 세므로 여럿이
##  동시에 뒤에 서도 마지막 하나가 나갈 때까지 비친 채로 있다. (이번 범위는 플레이어다.)

const PINE := preload("res://assets/sprites/field/tree_pine.png")
const ROUND := preload("res://assets/sprites/field/tree_round.png")
const DEAD := preload("res://assets/sprites/field/tree_dead.png")

## 연출값 (손맛) — 밸런스가 아니라 **보이는 값**이라 balance.tres가 아니라 여기 산다.
## 🔴 `OCCLUDE_Z = 4`는 플레이어 스프라이트(2)·떠있는 지팡이(3) **바로 위** 자리다. 더 올리면
##  날아가는 마법(RingSpellSystem z 10)까지 덮어 「내 마법이 나무 뒤로 사라진다」가 된다.
## ⚠ `FADE_ALPHA`는 **0.34에서 0.45로 올렸다**(세99 스샷 실측) — 0.34는 낮 바닥 위에서 나무가
##  거의 사라져 「거기 나무가 있다」는 정보까지 같이 지워졌다. 몸은 다 보이면서 나무 실루엣도 남는
##  자리가 0.45다. 밤 챕터를 만들면 대비가 달라지니 그때 다시 봐라.
const FADE_ALPHA := 0.45
const FADE_SEC := 0.14
const OCCLUDE_Z := 4
const BASE_Z := 0

## 지금 이 나무 뒤에 서 있는 몸의 수 (플레이어 하나지만 적까지 넓힐 때 그대로 쓴다).
var _behind: int = 0
var _fade: Tween = null

@onready var _sense: Area2D = $BehindSense


func _ready() -> void:
	# 북쪽 심층일수록 침엽수·마른나무, 남쪽은 활엽수·침엽수 (같은 값 둘 = 그쪽 가중치를 높인다).
	var pool: Array = [PINE, DEAD, PINE] if global_position.y < -500.0 else [ROUND, PINE, ROUND]
	texture = pool[randi() % pool.size()]
	_sense.body_entered.connect(_on_behind_entered)
	_sense.body_exited.connect(_on_behind_exited)


func _on_behind_entered(_body: Node2D) -> void:
	_behind += 1
	if _behind == 1:
		_set_seen_through(true)


## ⚠ `maxi(...,0)` — 씬 전환·free 순서에 따라 exited가 한 번 더 올 수 있다. 음수로 내려가면
##  다음 입장에서 `_behind == 1`이 영영 안 맞아 **다시는 안 비친다**(에러 0).
func _on_behind_exited(_body: Node2D) -> void:
	_behind = maxi(_behind - 1, 0)
	if _behind == 0:
		_set_seen_through(false)


## 🔴 앞으로 끌어오기(z)와 비치기(alpha)를 **한 자리에서** 쥔다 — 머리말 ⓐⓑ 참조.
## z는 즉시 바꾼다: 켤 때 안 올리면 흐려지기만 하고 여전히 몸 뒤라 화면이 안 변하고,
## 끌 때 안 내리면 **다 비친 뒤에도 나무가 몸 앞에 남는다**(밑동 아래 = 나무 앞인데 앞뒤가 뒤집힌다).
func _set_seen_through(on: bool) -> void:
	z_index = OCCLUDE_Z if on else BASE_Z
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", FADE_ALPHA if on else 1.0, FADE_SEC)
