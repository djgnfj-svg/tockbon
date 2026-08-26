# Between-run progress unlocks content; it does not raise numbers

**Status**: ⚠ **REVERSED on 2026-08-16 by the user. Both are in: unlocks AND stat boosts.**
The reasoning below is kept because **the trap it names did not go away** — see 「뒤집은 뒤」 at the bottom.
⚠⚠ **The trap is now due (2026-08-26)**: December is a **release**, not a demo, and a released roguelike
ships with whatever meta layer it has. **The first run has to be worth playing with nothing unlocked** —
that condition is the live part of this doc, and it has never been measured.
⚠ It was decided for the open-field cell game, which no longer exists. **The design it pointed at,
`cell-army-gdd`, is gone too** — deleted with the cell game, kept only in commit `62ff57d`, and **not
revived.** There is no GDD; what is being made is read out of `.scratch/island-hold/`.

## What was decided

Permanent progression adds **new species and new parts to the pool**. It never raises a stat, a rate or a
percentage. The layer is built **after** the core loop stands.

## What wasn't chosen

| Rejected | Why |
|---|---|
| Permanent stat/rate upgrades (harvest 25% → 40%) | Forces the first run to be deliberately weak so there is headroom to sell. The first run is the one that decides whether anyone keeps playing |
| A research tree as its own system | A third noun beside swarm control and parts — planning principle 4 |
| No meta layer at all (Brotato) | Defensible, but unlocks are the cheapest reason to start run two, and they cost nothing at design time |

## What's tied to it

The starting percentages in the GDD are meant to be **playable as they are**, because nothing will ever
raise them. ⚠ **That GDD is gone and its percentages with it** — the rule outlived the numbers: whatever a
run starts with has to be playable as it stands. ⚠⚠ And the clause after the comma **was reversed on
2026-08-16** — numbers do get raised now, which is exactly why the trap above is a condition and not a
footnote.

## Conditions to reopen

~~None before the core loop is playable.~~ **Reopened and reversed before the core loop existed at all** —
see below.

---

## 뒤집은 뒤 — 2026-08-16

사용자: *"내용이 될 듯. 숫자도 올리고 둘 다 할 듯. 열려 있어."*
**연구 해금이 새 내용과 숫자 둘 다를 준다.** 위 표의 첫 줄은 더 이상 거절이 아니다.

⚠ **다만 그 줄이 적어 둔 함정은 그대로 남는다**: 영구 강화가 팔리려면 **헤드룸이 필요하고, 헤드룸은
첫 런을 약하게 만들어서 만든다.** 그리고 **첫 런이 계속할지 말지를 정하는 판이다.**

⇒ **그래서 이것이 조건으로 남는다: 첫 런은 아무것도 해금되지 않은 채로 그 자체로 재미있어야 한다.**
숫자를 올릴 수 있다는 것이 첫 런을 약하게 튜닝해도 된다는 뜻이 아니다.
**해금 0개 상태를 기준으로 밸런스를 잡고, 해금은 그 위에 얹는다.**

⚠ 그리고 표의 둘째 줄 — *연구 트리를 그 자체로 하나의 시스템으로 두지 않는다* — 은 **아직 안 뒤집혔다.**
해금이 어디에 붙는지(별도 화면인가, 타이틀의 한 칸인가)는 정해지지 않았다.
