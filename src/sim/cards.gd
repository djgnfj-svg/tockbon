class_name Cards
extends RefCounted
## The level-up pick. In the full GDD a card is `species · slot · price` and buys a body part; here there
## are no species and no parts, so a card moves one multiplier.
##
## **The pick exists in the prototype on purpose.** A level-up with nothing to press is a notification, and
## a notification is something you watch happen — planning principle 1. Pressing a card is the smallest
## thing that makes a level an act.
##
## **No card grows the swarm any more.** The level pays force into the host and `F` is what turns force
## into bodies; a card that handed out clones would make bodies out of nothing, with no force to halve —
## see the decision named `swarm-grows-by-a-key-not-a-level`.

enum { HOST_SPEED, HOST_BITE, CLONE_BITE, SENSE, DASH, TOUGH }

const REST := [HOST_SPEED, HOST_BITE, CLONE_BITE, SENSE, DASH, TOUGH]

## Korean, because it is in-game text — the user reads this one, unlike the comments around it.
const TITLE := {
	HOST_SPEED: "빠른 몸",
	HOST_BITE: "큰 입",
	CLONE_BITE: "굶주린 무리",
	SENSE: "먼 눈",
	DASH: "짧은 숨",
	TOUGH: "질긴 껍질",
}

const DESC := {
	HOST_SPEED: "내 이동 속도 +12%",
	HOST_BITE: "내가 먹는 속도 +18%",
	CLONE_BITE: "분신이 먹는 속도 +18%",
	SENSE: "분신이 먹이를 보는 거리 +25%",
	DASH: "대시 재사용 -20%",
	TOUGH: "체력 +1",
}


## Three distinct cards. `REST` has six entries, so three distinct is always possible — drawing without
## replacement is what makes an offer of three the same card impossible rather than merely unlikely.
static func roll(rng: RandomNumberGenerator) -> PackedInt32Array:
	var out := PackedInt32Array()
	var pool: Array = REST.duplicate()
	for _i in 3:
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out
