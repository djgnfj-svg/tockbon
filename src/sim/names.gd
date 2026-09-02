class_name Names
extends RefCounted
## The names a body arrives with. **Sim data, no tree** — a constant table and one static lookup, so `Army`
## reaches it the way it reaches `Rules`: through the class name, never a path.
##
## The user, 2026-09-02 (ticket 03-02): names come from a list, one attached when the body arrives, and they
## are old-style Korean names. **The list IS the order** — a body takes the first name nobody on its roster
## holds, so the first four bodies of every run are the first four rows here, and a fifth is the fifth.
##
## ⚠ **Korean on purpose.** Every other identifier in `src/` is English; these strings are what the player
## reads on the panel, and the panel is the only place they go. The same exception `Rules.ITEMS` carries.
##
## ⚠ **A typed `const` array of strings parses on 4.7.1** — the packed-`const` trap the builder notes carry is
## the `PackedInt32Array([...])` constructor form; `const X: PackedStringArray = [...]` was probed on this
## engine before this file was written and keeps its element type.

## **Forty names, and the order is a decision** (ticket 03-02's plan lists them in exactly this order).
## The size and the two-syllable rule are pinned by `net_names`, never here.
const LIST: PackedStringArray = [
	"돌쇠", "막쇠", "개똥", "삼월", "마당", "복동", "언년", "끝순", "점순", "분이",
	"곱단", "순덕", "만석", "천석", "억쇠", "바우", "쇠돌", "곰보", "덕배", "말똥",
	"소똥", "칠성", "오월", "유월", "섭섭", "간난", "얌전", "붙들", "귀남", "방울",
	"길동", "춘삼", "갑돌", "갑순", "을순", "무쇠", "검둥", "흰둥", "노랑", "봉이",
]


## The first name in `LIST` that is not in `taken`; **when every name is taken, the list cycles** —
## `LIST[taken.size() % LIST.size()]`, so the forty-first body is 돌쇠 again and the forty-second 막쇠.
##
## ⚠ **`taken` is the caller's whole column, not a count.** A count would hand the fifth body the fifth
## name only while nobody has ever been skipped; the column keeps "unused first" true whatever order the
## rows were written in. Cycling reads the size and not the column because past forty there is nothing
## unused left to prefer — a repeat is the rule then, and it repeats in list order.
static func next(taken: PackedStringArray) -> String:
	for i in LIST.size():
		var n := String(LIST[i])
		if not taken.has(n):
			return n
	return String(LIST[taken.size() % LIST.size()])
