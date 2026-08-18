# docs/plans — the only folder that moves

`design/` holds concepts and `decisions/` holds rejected forks; **neither ever changes folder.** This one does,
and the folder a doc sits in *is* its status.

| Folder | Means | Who puts it there |
|---|---|---|
| `1.ready` | **A builder could start on it** | whoever finishes the design |
| `2.active` | Someone is building it right now | the build team, on start |
| `3.done` | **Implementation finished** — *not* "accepted" | the build team, on finish |

**`3.done` is not an acceptance record.** A doc lands there when the code is in and the nets are green; whether
the user has ever looked at the result is a separate axis, kept in `design/` headers. Merge the two and
"it runs but nobody has looked" stops being expressible — CLAUDE.md's own note about where this repo got burned.

**Moving a doc is three edits**: the `**Status**:` line inside it, every link pointing at it, and a report of
all three folders. **Links leak every single time** — `net_citations` catches the path form, not a stale claim.

---

## The state today

| Folder | Contents |
|---|---|
| `2.active` | [the title and the map](2.active/title-and-map.md) — **the main loop: the frame around a run.** A title with the three slots the user named, a five-floor / seven-node / four-route fixed map, the reward moved off the island and **onto the node** so a fork can ask *cells or beak*, **a chest that offers four artifacts and you take one** (결정, 2026-08-19: 「아티팩트 녗개중 선택」), three more hand-authored grids, and the cost of adding a fourth island cut from **nineteen places (fourteen of them measured) to four**. ⚠⚠ **Two OPEN questions remain and both are load-bearing**: whether the user's 「두 줄」 is one-of-two or two-columns (**it must be answered before the three grids are authored**), and what 설정하기 contains. ⚠ **The chest no longer heals, and that inverts the HP schedule** — the thin route reaches island 3 on a pool of 43.0 against a wipe threshold of 61.5–84, so as designed today that route loses; the three candidate answers are in the design doc's refutation box. ⚠ **Steps 1–4 and 6 are built and the round is green (14 nets, 1933 checks); step 5 — the three new grids — is NOT**, so `MAP_NODES`'s island column is still `[0, 1, 2, 1, 2, -1, 2]` and three grids serve six island-opening nodes. **The user has looked at the title and the map and asked for the map's readability pass, which is built; nothing else is accepted** |
| `3.done` | [plan it, then watch it](3.done/plan-then-watch.md) — the whole landing before the start button: a commit gate inside `step()`, **unlimited one-seat boats created by the drop, round-tripping** (결정 14R — the rejected five-boat cap is [unlimited boats, not a five-boat cap](../decisions/unlimited-boats-not-a-five-boat-cap.md)), a plan the player authors, a speed ladder built to change nothing, and more enemies to lose to. ⚠⚠ **OPEN 0: there is NO brake on the boats and that is a user decision on the record** — 「일단 빼고 만든 이후에 추가하자는 거임」. **Nothing here licenses writing a cap.** Built 2026-08-18; all four stages, the round **12 nets / 1328 checks** green. ⚠ **The user played it and could not operate the plan screen** — 「조작감이 너무 ㅈ같음」. That is unaccepted and it is the open wound this doc hands forward |
| `3.done` | [the boat and the landing](3.done/boat-and-landing.md) — an open coastline, a fleet that moves between several harbours, a camera. Built 2026-08-18; the round is **11 nets / 967 checks** green |
| | [the first slice](3.done/first-slice.md) — three islands, one run, end to end. Built 2026-08-17; the round was **9 nets / 725 checks** green |

⚠ **`3.done` here does not mean the design is settled, and both rows prove it.** The user played the slice
and said *"게임이 좀 애매하네. 뭔가 침공하는 느낌이 전혀 없어서"* and *"배가 곁다리인 게 여전히 별로네."*
**The boat plan answered the second sentence and not the first**: the user launched the finished build on
2026-08-18 and said *"참 애매하네. 그래도 그동안 중에서 제일 평범하네."* — 「곁다리」 is gone, 「애매하다」
is not. Both design docs carry it, [the boat and the landing](../design/boat-invasion.md) in its `Accepted` line; the GDD carries what is left as **Undecided 18**.

**Every earlier plan this repo had was deleted on 2026-08-17**, together with the design docs describing the two
games those plans built. Nothing was lost that mattered: what the plans *measured* is distilled into
[what two dead games left behind](../lessons-from-two-dead-games.md), and the plan text itself is recoverable
at the tags `v1-sim` and `v2-openfield`.

⚠ **Do not recover a plan from either tag.** `v1-sim`'s plans were written against integer determinism and a
20Hz tick; `v2-openfield`'s were written against a host, an open field, and a swarm the player steers. The
current game — a cell autobattler — has none of those, so a recovered plan quietly re-imports constraints
that no longer exist.

---

## What a plan has to carry

**Written down because the last set failed this test.** The user's report was that
**implementers keep coming back with questions**, and the cause was a plan that was a table of pointers into
design docs whose own *Open* lists were twenty items long.

⇒ **A plan carries data shapes, function names, key bindings, literal numbers, and per-piece acceptance.**
What is genuinely undecided goes in one place, where it can be seen not to block the build.

**The live design is [the cell army GDD](../design/cell-army-gdd.md)**.
The next plan comes from there.
