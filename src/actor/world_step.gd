extends RefCounted
## 세상이 한 프레임 산다 — 정수 분주기 · 커맨드 큐 · **틱 순서**.
##
## 🔴🔴 **이 파일이 있는 이유는 「순서가 한 곳에만 있다」 하나다.**
##  순서가 껍데기(`src/stage/`) 안에만 있으면 그물은 씬을 못 세워서 그 순서를 **손으로 베낀다.**
##  그 순간 **그물이 게임과 다른 것을 재게 되고**, 둘이 갈라져도 아무도 안 짖는다.
##  ⇒ 껍데기와 그물이 **둘 다 `frame()` 을 부른다.**
##
## 🔴 **화면을 모른다** — `src/actor/` 는 `src/view/`·`src/stage/` 를 참조할 수 없다(`net_layers`가 잰다).
##  ⇒ 뷰 통지(자취·섬광·업로드)는 여기 안 들어온다. `frame()` 이 **「이번 프레임에 틱이 돌았다」를
##  bool로** 돌려주고, 껍데기가 그걸 보고 화면을 친다.
##
## ⚠ **씬 트리도 모른다**(`RefCounted`). 그래서 그물이 헤드리스로 세상을 통째로 돌릴 수 있다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Character := preload("res://src/actor/character.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Monster := preload("res://src/actor/monster.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")

var _grid: CellGrid
var _spell: SpellSim
var _char: Character

## 🔴🔴 **몬스터 배열은 여기가 든다 — 껍데기가 따로 들면 「세상」이 두 곳이 된다.**
##  뷰는 아래 `monster_count()`·`monster_at()`(읽기 전용 질의)로만 본다(`monsters-minimum` 단계 1).
var _monsters: Array[Monster] = []
## ⚠ `reset()`은 이 값을 안 되돌린다 — id를 재사용하면 「37번이 죽었다」가 세션 안에서
##  유일하지 않게 되고 진단이 흐려진다. 되돌릴 이유가 없다(뷰가 id를 안 든다).
var _next_monster_id := 1

## 🔴 커맨드는 **「어느 틱에 적용되나」를 달고** 큐에 앉는다. 없으면 나중에 재조정이 불가능하다.
##  싱글에서는 로컬 입력이 채우고 멀티에서는 서버가 채운다 — 적용부 코드는 그대로다.
var _queue: Array[Dictionary] = []

## 🔴 틱은 float 누산기가 아니라 **정수 분주기**다(`Tuning.TICK_DIVIDER`). 누산기를 쓰면
##  프레임 시간에 따라 틱 경계가 흔들려 클라마다 다르게 쪼개진다 — 멀티에서 틱 번호는 상태다.
var _phase := 0

## 🔴 발사 수는 껍데기의 HUD 진단이 읽는다(발사 0 = 좌클릭이 안 닿는다 · 발사 > 착탄 = 격자 밖 소멸).
##  ⚠ 세는 자리가 `fire()` 가 참을 준 **직후**여야 한다 — 큐에 넣을 때 세면 거부된 커맨드까지 센다.
var _fire_count := 0

## 🔴 `_init`이 null을 받았다. **짖음만으로는 그물이 아무것도 못 잰다** — 러너는 stderr를
##  못 보고 `expect_error`는 사면 선언일 뿐이라, 짖음이 사라져도 검사가 안 빨개진다.
##  ⇒ 짖음의 흔적을 **값으로** 남겨서 「짖었나」를 잴 수 있게 한다.
## ⚠ 그리고 이 갈래 덕에 부서진 세상이 **매 프레임 엔진 에러를 뿜는 대신** 조용히 멈춘다 —
##  원인을 말하는 줄은 위에서 한 번 나왔다.
var _broken := false


## 셋 중 하나라도 없으면 세상이 없다.
## 🔴🔴 **이 검사가 막는 것은 「null이라고 손으로 쓰는 사람」이 아니라 「선언 순서를 옮기는 사람」이다.**
##  껍데기에서 `var _world := WorldStep.new(_grid, _spell, _char)` 줄이 `_grid` 선언보다
##  **위로 올라가면 셋이 전부 null인데 텍스트는 한 글자도 안 바뀐다.**
##  ⚠ 실측: 그 상태로 그물 1085개가 **전부 초록**이었고, 게임만 매 프레임 짖으며 멈췄다.
##  ⇒ 텍스트 검사로는 원리적으로 못 잡으므로 **계약을 코드가 스스로 지킨다.**
##  ⚠ 정상 경로에서는 아무 일도 안 난다 — 거동은 그대로다.
func _init(grid: CellGrid, spell: SpellSim, ch: Character) -> void:
	if grid == null or spell == null or ch == null:
		push_error("WorldStep: 세상 셋 중에 null이 있다 — 껍데기의 선언 순서를 봐라")
		_broken = true
	_grid = grid
	_spell = spell
	_char = ch


## 한 프레임. **틱이 돈 프레임에만 참**을 돌려준다.
##
## 🔴🔴 **아래 순서가 계약이다** — 바꾸면 결과가 달라지고, 멀티에서는 그게 곧 desync다.
##   1. `_drain_queue()`   외부 커맨드(발사)
##   2. `_grid.step()`     격자가 한 틱 산다(불)
##   3. `_spell.step()`    투사체가 **움직인 뒤의 격자**를 상대로 난다
##
## 🔴🔴 **캐릭터는 60Hz, 시뮬은 20Hz다.** 캐릭터를 틱에 묶으면 조작이 뚝뚝 끊긴다.
##  호스트 권위라 틱에 묶일 이유가 없다(GDD 멀티 표).
## ⚠ 틱 **뒤에** 도는 이유: 방금 폭발이 바꾼 지형 위를 이번 프레임에 걷는다.
## ⚠ **`jump` 는 「이번 프레임에 눌렸나」, `jump_held` 는 「지금 누르고 있나」다** — 가변 점프가
##  뒤엣것으로 상승을 자른다(`character.step`). 🔴 기본값을 안 준다: 안 넘기면 조용히 짧은 점프가 된다.
func frame(dt: float, axis: float, jump: bool, jump_held: bool) -> bool:
	if _broken:
		return false
	var ticked := false
	_phase += 1
	if _phase >= Tuning.TICK_DIVIDER:
		_phase = 0
		_drain_queue()
		_grid.step()
		_spell.step(_grid)
		# 🔴🔴 **통지를 여기서 읽는다 — 틱 갈래 *안*이다.** 프레임마다 부르면 통지 배열이
		#  다음 `spell.step()` 까지 살아 있어서 **한 대가 세 대가 된다**(계획 §6 위험 1).
		#  ⚠ 무적이 두 대를 먹어 화면에서는 정상으로 보이고, 지속 피해에서만 3배가 드러난다.
		_char.on_tick(_spell)
		ticked = true
	_char.step(_grid, dt, axis, jump, jump_held)
	# 🔴🔴 **캐릭터 뒤인 것이 계약이다**(`monsters-minimum` 단계 1). `_next_axis`가 플레이어
	#  중심을 target으로 받으므로 **이번 프레임에 캐릭터가 간 자리**를 보는 것이 맞다.
	#  ⚠ target은 `_char.center()`를 **축마다** `roundi`한 px다(판정 10: 중심 대 중심).
	#  `Vector2i(Vector2)` 생성자는 0쪽으로 자르지 반올림이 아니라 여기 안 쓴다.
	var center := _char.center()
	var target_x := roundi(center.x)
	var target_y := roundi(center.y)
	for m: Monster in _monsters:
		m.step(_grid, dt, target_x, target_y)
	return ticked


## 🔴 다음 틱에 적용될 커맨드로 앉힌다. **틱 번호는 격자가 준다** — 부르는 쪽이 세면
##  두 시계가 되고, 그러면 「넣었는데 영영 안 빠지는」 커맨드가 생긴다.
##
## ⚠ **`frame()` 과 같은 문을 지난다.** 여기만 열어 두면 부서진 세상이 「프레임은 정중히
##  멈추는데 좌클릭에서만 터진다」가 되고, 그건 규칙이 두 벌인 것이다.
func enqueue(cmd: Dictionary) -> void:
	if _broken:
		return
	_queue.append({"tick": _grid.get_tick() + 1, "cmd": cmd})


## ⚠ **`keep` 갈래는 지금 소비자가 없다** — `enqueue`가 늘 `tick + 1`을 달고 `target`도 같아서
##  전부 이번 틱에 빠진다. 멀티(서버가 미래 틱 커맨드를 보낸다)를 위한 이음매이고,
##  그때까지는 **죽은 분기**라는 걸 알고 봐라.
func _drain_queue() -> void:
	if _queue.is_empty():
		return
	var target := _grid.get_tick() + 1
	var keep: Array[Dictionary] = []
	for e: Dictionary in _queue:
		if int(e["tick"]) > target:
			keep.append(e)
			continue
		var cmd: Dictionary = e["cmd"]
		# 🔴 커맨드가 두 시뮬로 갈린다. **`kind` 키를 공유하지 않는 게 이 분기의 안전장치다** —
		#  같은 키를 쓰면 두 enum의 숫자가 겹쳐 엉뚱한 커맨드가 실행되고, 값이 우연히 유효
		#  범위면 **에러 하나 없이** 발사가 채우기가 된다.
		if cmd.has("spell_kind"):
			# 🔴🔴 **쓰러지면 못 쏜다.** 안 막으면 지팡이도 총구도 안 그려지는데 **마법이 나가고
			#  그 반동으로 시체가 날아다닌다**(실측: 발사 10 → 11 · 위로 59px).
			# 🔴 **껍데기가 아니라 여기서 막는다** — 껍데기는 로컬 입력만 지나지만 이 문은
			#  **모든 커맨드가 지난다**(멀티에서는 서버가 채운다). 룬 검사를 `spell_sim.fire()` 에
			#  둔 것과 같은 이유다.
			if _char.downed:
				continue
			if _spell.fire(cmd):
				_fire_count += 1
				# 🔴🔴 **`fire()` 가 참을 준 *뒤*다.** 큐에 넣는 시점에 걸면 거부된 발사에도
				#  밀려서 「안 나갔는데 밀린다」가 된다 — 그건 고장으로 읽힌다.
				_char.recoil(int(cmd.get("adx", 0)), int(cmd.get("ady", 0)))
			continue
		_grid.apply(cmd)
	_queue = keep


## 🔴 껍데기의 디버그 스폰 키(M)가 부른다. 만들었으면 id, 못 만들었으면 0.
##  🔴🔴 **상한을 넘으면 안 만든다 — 이미 있는 놈을 버리지 않는다.** 탄 상한(단계 6)과
##  같은 어법이다: 버리면 「쏘아도 몇 마리가 안 나온다」가 고장으로 읽힌다.
func spawn_monster(kind: int, px: int, py: int) -> int:
	# 🔴 `enqueue`(위)와 같은 문이다 — 부서진 세상에서도 배열이 늘고 HUD 숫자가 오르면
	#  「프레임은 정중히 멈추는데 M에서만 늘어난다」가 되고, 그건 규칙이 두 벌인 것이다.
	if _broken:
		return 0
	if _monsters.size() >= MonsterDefs.MAX_MONSTERS:
		return 0
	var id := _next_monster_id
	_next_monster_id += 1
	_monsters.append(Monster.new(id, kind, px, py))
	return id


## 🔴🔴 읽기 전용 질의 — 뷰가 이걸로만 본다. 껍데기가 배열을 따로 들면 「세상」이 두 곳이 된다.
func monster_count() -> int:
	return _monsters.size()


func monster_at(i: int) -> Monster:
	return _monsters[i]


## 무대 리셋(R)이 부른다. 🔴 **이 객체가 든 것만 되돌린다** — 격자·투사체·캐릭터는
##  각자의 리셋이 있고, 여기서 한 번 더 만지면 되돌리는 자리가 두 곳이 된다.
##
## ⚠ **`_phase` 는 안 건드린다.** 무대 리셋은 틱 위상을 바꾸는 사건이 아니다 —
##  0으로 두면 R을 누른 프레임의 다음 틱이 최대 2프레임 밀린다.
## 🔴 `_monsters.clear()` — `monsters-minimum` 문서 「화면」이 「비우는 자리는
##  `world_step.reset()`이다」로 못 박았다. ⚠ `_next_monster_id`는 안 되돌린다(위 선언부).
func reset() -> void:
	_queue.clear()
	_fire_count = 0
	_monsters.clear()


## 🔴 렌더 보간이 읽는다. **시계를 하나 더 만들지 않는 게 요점이다** — 뷰가 자기 `delta`를
##  누산하면 그 순간 시계가 둘이 되고, 투사체가 틱 경계에서 미끄러진다.
func phase() -> int:
	return _phase


func fire_count() -> int:
	return _fire_count
