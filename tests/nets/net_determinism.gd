extends RefCounted
## 시뮬 코어의 결정론 계약을 소스 텍스트로 검사한다.
##
## 왜 텍스트 스캔인가: 같은 프로세스의 두 인스턴스는 float도 똑같은 답을 낸다.
## 그래서 "두 번 돌려 비교하는" 그물로는 이 계약 위반을 원리적으로 못 잡는다.
## 플랫폼이 갈릴 때만 드러나고, 그때는 이미 두 클라의 세상이 영영 다른 세상이 된 뒤다.
##
## sqrt와 sin/cos/atan2는 libm이라 플랫폼마다 답이 다르다. + - *는 IEEE-754가 비트까지 같다.
## 그래서 금지 대상은 "float 전부"가 아니라 이 목록이다.

## 격자에 닿는 순수 시뮬. 씬 트리를 모르고, 정수만 쓴다.
const SIM_FILES: Array[String] = [
	"res://src/world/cells/cell_grid.gd",
	"res://src/world/cells/cell_hash.gd",
	"res://src/world/spell/spell_sim.gd",
]

## spell_tuning.gd는 한 파일에 두 블록이다. 위쪽(SIM)만 계약이고 아래쪽(FX)은 화면 전용이라 자유다.
const TUNING_FILE := "res://src/world/spell/spell_tuning.gd"

## \b 덕분에 _isqrt 는 sqrt 로 안 걸린다(밑줄은 단어 문자라 경계가 아니다).
const BANNED: Array = [
	["\\bfloat\\b", "float"],
	["\\bVector2\\b", "Vector2"],
	["\\bsqrt\\s*\\(", "sqrt()"],
	["\\bsin\\s*\\(", "sin()"],
	["\\bcos\\s*\\(", "cos()"],
	["\\batan2\\s*\\(", "atan2()"],
	["\\brandi\\s*\\(", "randi()"],
	["\\brandf\\s*\\(", "randf()"],
	["\\brandomize\\s*\\(", "randomize()"],
	["\\bTime\\.", "Time."],
]


func run(t) -> void:
	for path: String in SIM_FILES:
		_scan(t, path, _strip(_read(path)))
	_scan_tuning(t)


## 주석과 문자열을 걷어낸다. 이 리포는 주석에 금지어를 일부러 적어 두므로
## 이걸 안 하면 그물이 자기 설명서를 잡는다.
func _strip(src: String) -> String:
	var out := ""
	for raw: String in src.split("\n"):
		var line := raw
		var q := line.find("\"")
		var h := line.find("#")
		if h >= 0 and (q < 0 or h < q):
			line = line.substr(0, h)
		elif q >= 0:
			line = line.substr(0, q)
		out += line + "\n"
	return out


func _scan(t, path: String, src: String) -> void:
	var nm := path.get_file()
	for entry: Array in BANNED:
		var re := RegEx.new()
		re.compile(entry[0])
		var hits := re.search_all(src)
		t.ok(hits.is_empty(), "%s 에 %s 가 없다" % [nm, entry[1]])


## 마커가 정확히 하나씩 있어야 한다. 없으면 아래 검사가 통째로 헛돌고,
## 둘 이상이면 어디까지가 계약인지 알 수 없다. 둘 다 실패로 친다.
func _scan_tuning(t) -> void:
	var src := _read(TUNING_FILE)
	var begin := "SIM-BLOCK" + "-BEGIN"
	var end := "SIM-BLOCK" + "-END"
	t.eq(src.count(begin), 1, "spell_tuning 에 시작 마커가 정확히 하나")
	t.eq(src.count(end), 1, "spell_tuning 에 끝 마커가 정확히 하나")

	var a := src.find(begin)
	var b := src.find(end)
	if a < 0 or b < 0 or b <= a:
		t.ok(false, "spell_tuning 마커 순서가 맞다")
		return
	_scan(t, TUNING_FILE, _strip(src.substr(a, b - a)))


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_determinism: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
