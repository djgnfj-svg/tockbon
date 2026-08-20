# docs/plans — the only folder that moves

`design/` holds concepts and rejected forks; **it never changes folder.** This one does,
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

**`1.ready` is EMPTY** — `sea-summon` left it on 2026-08-19 when its implementation landed. Nothing is
waiting for a builder.

| Folder | Contents |
|---|---|
| `3.done` ⚠⚠ **BUILT and ACCEPTED 2026-08-19 (「잘되네」) — 17 nets / 2508 checks green — and its question 1 is STILL UNANSWERED, so the build stands on one side of a bet.** Verification and all thirteen acceptance rows are open; four of them are `user only` | [summon on the sea](3.done/sea-summon.md) — **arm one of five slots with a number key, press the green band of water hugging the coast, and hold: cells come out THERE on boats and each sails to the nearest shore it can land on.** The user asked for this **four times** — the earliest is 2026-08-18, at the head of `plan-then-watch`, where 「바다위에 초록색 지역」 was read for its second half (boats are unlimited) while its first half, *where the player's hand goes*, was never built. **This is the standing instance of 「내가 말한대로 개발을 안하네」 for the part loop.** ⚠ **A previous plan named `slot-summon` was deleted because its press target was a landable COAST tile; the target is the SEA.** **Re-measured for the plan off `islands.gd`, all three islands**: the band at `d = 2` is **190 / 174 / 186** water tiles and reaches **82 / 75 / 80** landings against sendable **84 / 76 / 82** — so the derivation costs **two coast tiles out of eighty**, and 20–26 precision acts become **one press**. ⚠ **And it does NOT make aiming easier** — the design refutes its own most attractive claim: median catchment is 1–2 tiles, the same as the drop it replaces. The wall is that **`water_route` is indexed by HARBOUR and a summon has none**, answered by ONE multi-source BFS in `load_rows` with its OWN counter, so `net_coast`'s `water_field_builds` expectation must not move. ⚠⚠ **Ten OPEN questions and NONE has been sent**, question 1 first: does the hold happen **before 시작 or during the fight?** The build assumes **before**, so the cadence is a `look.gd` constant — and the plan names **four seams** a live-fire version plugs into and forbids sealing any of them. ⚠ **The band is a positive mark on the field and the user deleted exactly that shape for the land** (「못내림만 표시하면 됨」); the plan argues they answer different questions and **the user has not heard that argument.** ⚠ **Nothing here adds a cost, and nothing in it may invent one** — 「일단 빼고 만든 이후에 추가하자는 거임」. **Landed: 17 nets / 2508 / 4.8 s green**, two new (`net_summon` 122, `net_slots` 123). ⚠⚠ **Three of its planned mutations do not bite and all three are structural** — the `water[t]` clause, `summon`’s own band test, and the descent’s same-landing restriction, which **no shipped island can measure at all**; each is recorded in the code and in the net beside the row, and G8’s second fixture is where the third one bites. ⚠ The plan’s `net_draw_leaf` total was wrong (132 against a real **131**) and was caught by re-deriving rather than nudging — the exact failure it warned about. See its round log |
| `3.done` | [delete the speed ladder, and make landing a denylist](3.done/speed-off-open-landing.md) — **built 2026-08-19, three rounds, 15 nets / 2216 checks green.** The `0 1 2 3 6` chips and the pause are gone; landing is a denylist and **every 8-way coast tile on all three islands is sendable** (50→84 · 44→76 · 48→82), a boat sails a **string-pulled water route** around headlands, and the green shore tint is replaced by a refusal mark drawn from the same call `send` refuses on. Also: **variable grid size with culling, and one 144×32 long map** not wired into any node. ⚠⚠ **A8 and A9 are `user only` and OPEN** — verify-look drove S1–S5 and all five read right, but **the user has not launched it.** ⚠ Carried out: the smoother spends headland clearance down to ~3 px and no hull-width floor was set — **two things the user asked for on 2026-08-19 while watching the game run.** The `0 1 2 3 6` chips come out (they read as node numbers — the user asked what they were), and **landing inverts from an allowlist to a denylist**, which is what [the boat and the landing](../design/boat-invasion.md)'s decided #1 said all along. ✅ **All three OPEN questions were sent and answered on 2026-08-19**: the pause goes with the ladder, the tint is deleted in favour of a blocked-only mark, and ⚠⚠ **the user chose to open the shadowed coastline too** — so **a boat sails a water ROUTE instead of a straight line**, `grid` grows a water field, and the boat stops being one segment. **Measured**: sendable goes 50→84 · 44→76 · 48→82, and since all water on all three islands is one connected body the refused set becomes exactly *cliff + inland*. ⚠ **It moves the clock** — a route is longer than the line it replaces and crossings were already 20% of it; the plan measures and reports, and forbids retuning `TIME_LIMITS` |
| `2.active` ⚠ **PAUSED, and its step 5 is being REPLACED** — not three grids assigned to nodes, but variable map size plus one long map (user, 2026-08-19; see `push-inland`) | [the title and the map](2.active/title-and-map.md) — **the main loop: the frame around a run.** A title with the three slots the user named, a five-floor / seven-node / four-route fixed map, the reward moved off the island and **onto the node** so a fork can ask *cells or beak*, **a chest that offers four artifacts and you take one** (결정, 2026-08-19: 「아티팩트 녗개중 선택」), three more hand-authored grids, and the cost of adding a fourth island cut from **nineteen places (fourteen of them measured) to four**. ✅ **The five OPEN questions were sent on 2026-08-19 and four came back answered**: 「두 줄」 is **one-of-two** (⇒ step 5 is unblocked, and the rejected branch is [one node per floor](../design/one-node-per-floor-not-two-columns.md)), 설정하기 **does not press**, the roster grows 14→20. ⚠⚠ **The chest was REOPENED by the user in the same message** — *"상자 보상은 아직 미정이고"* against their own 2026-08-18 quote saying artifacts. **Both quotes stand; do not build the chest's payout.** ⚠ **The chest was designed not to heal, and that inverts the HP schedule** — the thin route reaches island 3 on a pool of 43.0 against a wipe threshold of 61.5–84, so as designed today that route loses; the three candidate answers are in the design doc's refutation box. ⚠ **Steps 1–4 and 6 are built and the round is green (**15 nets, 1953 checks**); step 5 — the three new grids — is NOT**, so `MAP_NODES`'s island column is still `[0, 1, 2, 1, 2, -1, 2]` and three grids serve six island-opening nodes. **The user has looked at the title and the map and asked for the map's readability pass, which is built; nothing else is accepted** |
| `3.done` | [plan it, then watch it](3.done/plan-then-watch.md) — the whole landing before the start button: a commit gate inside `step()`, **unlimited one-seat boats created by the drop, round-tripping** (결정 14R — the rejected five-boat cap is [unlimited boats, not a five-boat cap](../design/unlimited-boats-not-a-five-boat-cap.md)), a plan the player authors, a speed ladder built to change nothing, and more enemies to lose to. ⚠⚠ **OPEN 0: there is NO brake on the boats and that is a user decision on the record** — 「일단 빼고 만든 이후에 추가하자는 거임」. **Nothing here licenses writing a cap.** Built 2026-08-18; all four stages, the round **12 nets / 1328 checks** green. ⚠ **The user played it and could not operate the plan screen** — 「조작감이 너무 ㅈ같음」. ⚠⚠ **That verdict was DROPPED by the user on 2026-08-19** (`idea-inbox` row 23) — dropped, not answered. ⚠ **And its speed ladder was deleted** by `speed-off-open-landing`, which took with it this doc's only pressable thing during a fight. ⚠ **That row said 「the `1.ready` plan above」 and pointed at whatever happened to be sitting there** — a folder is not a name, and the day something else landed in `1.ready` the sentence started naming the wrong plan |
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

---

## Two rules `net_process` forces, and one it cannot

**Moving a doc between these three folders means three edits**: the `**Status**:` line inside it, every link
pointing at it, and a report of all three folders. **Links leak every single time.**

⚠ **Two rules are forced by `net_process` rather than by good faith**, because both were written in two
places each and skipped both times: **a plan carrying an `OPEN questions` section must declare whether they
were sent**, and **a plan must carry a `## Round log` with all five fields per block.** Four plans predate it
and the exemption list **is pinned at four — plan number five is checked.**

⚠ **It forces the shape, never the truth**: a `Sent to the user: yes` on a message nobody sent passes.
**This exists because the heavier rule was never followed** — *"내가 그냥 대화를 하고 있지만 사실 항상
아이디어를 내는 거거든? 근데 니가 그냥 지워버림."* A design doc costs more than a remark, so the remark was
dropped instead.
