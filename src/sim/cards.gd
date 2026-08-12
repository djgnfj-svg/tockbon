class_name Cards
extends RefCounted
## The level-up pick. In the full GDD a card is `species · slot · price` and buys a body part; here there
## are no species and no parts, so a card moves one multiplier or hands out clones.
##
## **The pick exists in the prototype on purpose.** Splitting automatically means the level-up is a
## notification, and a notification is something you watch happen — planning principle 1. Pressing a card
## is the smallest thing that makes growth an act.
##
## **One of the three is always a split.** Not a fairness rule — the swarm is what the build measures, and
## a level that cannot grow it removes the experiment's only independent variable for that level.

enum { SPLIT_1, SPLIT_3, HOST_SPEED, HOST_BITE, CLONE_BITE, SENSE, DASH, TOUGH }

const SPLITS := [SPLIT_1, SPLIT_3]
const REST := [HOST_SPEED, HOST_BITE, CLONE_BITE, SENSE, DASH, TOUGH]

## Korean, because it is in-game text — the user reads this one, unlike the comments around it.
const TITLE := {
	SPLIT_1: "분열",
	SPLIT_3: "삼중 분열",
	HOST_SPEED: "빠른 몸",
	HOST_BITE: "큰 입",
	CLONE_BITE: "굶주린 무리",
	SENSE: "먼 눈",
	DASH: "짧은 숨",
	TOUGH: "질긴 껍질",
}

const DESC := {
	SPLIT_1: "분신 하나가 늘어난다",
	SPLIT_3: "분신 셋이 한꺼번에 늘어난다",
	HOST_SPEED: "내 이동 속도 +12%",
	HOST_BITE: "내가 먹는 속도 +18%",
	CLONE_BITE: "분신이 먹는 속도 +18%",
	SENSE: "분신이 먹이를 보는 거리 +25%",
	DASH: "대시 재사용 -20%",
	TOUGH: "체력 +1",
}


## Three distinct cards, the first of which always grows the swarm.
static func roll(rng: RandomNumberGenerator) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.append(SPLITS[rng.randi() % SPLITS.size()])
	var pool: Array = REST.duplicate()
	for _i in 2:
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out
