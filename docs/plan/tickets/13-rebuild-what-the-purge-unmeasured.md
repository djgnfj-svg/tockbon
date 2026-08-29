Type: task
Status: resolved

# Rebuild the five measurements the purge left with nothing watching them

## Answer — ✅ **닫혔다, 2026-08-29. 다섯 중 넷은 지켜볼 코드 자체가 없어졌다**

**「What NOT to do」가 예측한 그대로 됐다.** 그 절은 *"Do not rebuild these against the boat system if
that system is about to be replaced"* 라고 적어 두었고, **2026-08-29 에 그 배가 지워졌다** — 플레이어가
배를 놓는 손짓이 그 전날 지워지면서 `Battle.summon` 을 부르는 곳이 `src/` 에 하나도 없었기 때문이다.

| 다섯 중 | 지금 |
|---|---|
| `_phase_boats` 의 호 길이 걸음 | ⚠ **코드가 없다** |
| `leg` 단조성과 그 천장 | ⚠ **코드가 없다** |
| 선체가 매 서브스텝 물 위에 있다 | ⚠ **코드가 없다** |
| 돌아오는 다리의 장부 | ⚠ **코드가 없다** |
| `_try_unload` / `_free_tiles_from` 놓는 순서 | ⚠ **앞 절반은 없고, `_free_tiles_from` 은 `place_ashore` 밑에 산다** |
| ⚠⚠ **`Battle.step` 의 서브스텝 분해** | ✅ **살아 있다. 티켓 26 이 든다** |

⚠ **이 티켓의 실측은 안 지운다** — 「크기가 0 이 될 수 있는지 먼저 물어라」와 두 동사가 서로 다른 종류의
조각을 받는다는 것은 다음 배를 만들 때 그대로 참이다.

---

## What closes it

**Five behaviours that still run have a net again**, and each new net can be made to go red by breaking
the thing it names.

## Why this ticket exists

The 2026-08-27 purge deleted the harbour system, and **the checks that measured live behaviour through
it died with it.** Nothing on this list is dead code: it all still runs, every frame, unwatched.

| What still runs | What watched it |
|---|---|
| **`_phase_boats`'s arc-length walk** | the only literal check of it anywhere |
| **`leg` monotonicity and its `path.size()-2` ceiling** | same |
| **the hull is over water on every sub-step** | same |
| **the return leg's bookkeeping** — `cum` rebuilt, `dist` unchanged, `t`/`leg` reset | same |
| **`_try_unload` / `_free_tiles_from` placement order**, and the 「a fourth boat waits」 boundary | same |

⚠⚠ **AND THE HEAVIEST ONE HAS NOTHING TO DO WITH HARBOURS: `Battle.step`'s sub-step decomposition.**
The rows that pinned it — that `step(dt)` consumes whole `Rules.SIM_SUBSTEP_SEC` chunks and carries the
remainder, and that one `step(1.0)` is NOT sixty `step(1/60)` — died only because they needed a
committed plan, and a plan was made with `send`. **Every number the sim produces rests on that
decomposition.** It is the first row to rebuild, and it is cheap: a summon plus a commit gets a fight
running, and the assertion is about the clock, not about boats.

## The rule this ticket keeps

⚠⚠ **A REBUILT NET MUST BE ABLE TO GO RED, AND THIS PURGE FOUND FIVE THAT COULD NOT.** An emptied table
made `shove_tiles_of` return 0.0, which turned `t.ok(distance >= tiles - 0.01)` into `distance >= -0.01`
— true for every input. Fourteen assertions were passing on it. **Before writing an assertion that
leans on a magnitude, ask whether that magnitude can go to zero**, and put a floor under it if it can.
`how-nets-lie` carries the full entry.

⚠ **The two verbs take different tiles.** `send` took a BEACH; `summon` takes WATER inside the band.
The helpers written today say which one they return in their own names — `_summonable_water_on`,
`_a_band_water_tile` — and a new fixture should do the same.

## What NOT to do

⚠ **Do not rebuild these against the boat system if that system is about to be replaced.** The beasts
own the boats now and the player never places one; a net written against the player's summon path is a
net that dies the day bodies start the island already ashore. **Ask which of the five outlive that
change before writing any of them** — the sub-step decomposition does, and the boat arithmetic may not.
