# docs/design index — what is designed, and what actually runs

This folder holds **concepts**. Unlike `docs/plans/`, **nothing moves between folders** — a concept stays alive.
But **every doc carries "how much of this is built" in its header.**

**Why carry status**: without it, **being written reads as being present.**
The magic-circle doc lists seventeen glyphs and **zero of them run** — the whole direction was dropped. If that gap is recorded nowhere,
the next person (and the next session) **plans on top of something that doesn't exist.**

## Two separate axes — `Implemented` and `Accepted`

The distinction `CLAUDE.md` pins down holds here too. **Implementation finished ≠ acceptance passed.**

| Axis | Value | Meaning |
|---|---|---|
| **Implemented** | `none` | Doc only. Not one line of code |
| | `partial` | Some of it runs. **Write in the doc what does and doesn't** |
| | `full` | Everything the doc describes runs |
| **Accepted** | `unseen` | The user has never confirmed it on screen |
| | `pass (date)` | The user looked and said yes |
| | `fail (date)` | They looked and it wasn't. **Write the story in the doc** |

**`Implemented: full` + `Accepted: unseen` is a normal combination.** Merge those two into one column and
"it runs but nobody has looked" becomes inexpressible — this repo got burned exactly there.

## Header format

Goes directly under `# Title` and `**One line**:`.

```markdown
**Implemented**: partial — circles 1/3 · runes 2/N · glyphs 2/17
**Accepted**: unseen
```

For `partial`, **always attach what works and what doesn't, briefly.** "Partial" alone carries no information.

---

## Index

| Concept | Implemented | Accepted |
|---|---|---|
| [Cell game](cell-game.md) — **the current game.** Split, harvest, buy animal parts, climb the food chain | partial — swarm · commands · rendezvous · carrying · ecosystem · every key · **the parts economy since plan 3** (eleven slots, the part table, cards that only give parts, a placeholder trait) **and the grassland field since plan 4** (crow · horse · boss, the corpse beat, rock and water, the arena). Chimeras and further biomes do not. **Tiers and species currencies are not unbuilt — they were cut** | **the core loop passed**. ⚠ **everything since is built and unseen** — no play, no `verify-look` |
| [Stages and evolution](stages-and-evolution.md) — **newer than the GDD where they disagree.** Habitats, evolution instead of card prices, force vs disposition, special individuals, **`F` splits and `V` absorbs**, **eleven slots**, **a kill leaves a corpse** | partial — the eleven slots, the part table, wearing/digesting, the trait, and since plan 4 the three species, the corpse beat, the ground and the arena. Habitats, evolution across stages and chimeras do not | none — three conversations, nothing played |
| [Hunting and the boss (ko)](hunting-and-the-boss-ko.md) — **newest of all three, and it is what plan 4 was built from.** Force ×10, size per species, the crow is hit, the horse is herded, the boss cannot be escaped, terrain | **most of it** — force ×10, per-species size, the crow's counter, herding, the arena, terrain and two-way damage all run | none — ⚠ **the arena is not drawn at all**, so this doc's last act cannot be read off the build |
| [연출 감사 (ko)](presentation-audit-ko.md) — **화면이 말하지 않는 열두 가지**, 있는 아홉 가지와 대조해서. 맞을 때·맞힐 때·시체를 여러 입에·보스가 오는 신호·아레나. 소리와 스프라이트는 일부러 뺐다 | none — 이 문서가 다음 플랜의 입력이다 | 사용자가 1·2·3·4를 직접 지목했다. **감사 자체는 아직 읽히지 않았다** |
| [레벨 커브 (ko)](level-curve-ko.md) — **한 세션으로 보스까지 갈 수 있게 만드는 것.** 사용자가 플레이하고 *"도저히 게임이 진행이 안 돼, 잡을 수가 없어요"*라고 했고, `tools/look/probe_run.gd`가 그것을 숫자로 만들었다 — **잡을 게 화면에 없는 시간 83%, 킬 사이 최장 공백 150초.** 새 잡몹 넷(들쥐·토끼·들개·멧돼지, **부품은 안 준다**) · 시간 게이트 · 시작 주머니 · 한 대에 최대 체력의 절반(`MAX_HIT_FRACTION`) · 종별 공격 동작. ⚠ **개막 화면에 생물이 0마리인 것은 우연이 아니라 구조였다** — 개막 카메라의 반대각선이 700이 아니라 **459**이고 배치 금지 반경이 900이었다 | 대부분 — 문서 끝 「지어진 뒤」가 여섯 군데 차이를 적는다 | none — 계기가 아직 「진행 불가」다(빈 시간 61%, 기준 25%) |
| [근접전 가독성 (ko)](melee-legibility-ko.md) — **몸이 겹치는 것과 분신의 타격이 안 읽히는 것**, 사용자가 플레이하고 지목한 둘. 사용자는 겹치는 것을 **셋** 셌고(적·나·내 분신) **둘이 내 것이다**: 가림 순서 · **호스트↔분신과 분신↔크리터, 밀어내는 힘이 빠진 자리가 둘** · 실은 분신이 호스트보다 밝고 크기도 90%가 넘음 · 모든 몸이 한 실루엣 · 타격 선이 가려지거나 허공에 뜸 · 맞는 쪽에 줄어드는 양이 없음. ⚠ **[몸은 코드로 그린 선이다](../decisions/the-body-is-a-line-drawn-by-code.md)가 `valid`인데 그 거절 표의 세 줄을 빌드가 하고 있다** — 그래서 추천은 하나가 아니라 **갈림길 양쪽에 하나씩**이다 | none — 이 문서가 다음 플랜의 입력이다 | none — 사용자가 문제를 지목했을 뿐, 여기 적힌 어느 답도 고르지 않았다 |
| [Circle · rune · glyph](circle-rune-glyph.md) — the three axes, cut along time. **Belongs to the dropped magic-circle direction** | none | none — ⚠ **its `pass` was for a deleted game.** Only "order changes the kind of result" carries |
| [Cell game review (ko)](cell-game-review-ko.md) — a read of the GDD from 2026-08-13 | none | none — ⚠ **most of what it calls settled was reversed within a day.** Read it as a snapshot, never as a rule |
| [The loops, drawn](cell-loops.html) — a rendered view of `stages-and-evolution` | none | none — ⚠ **stale since 2026-08-13** |

**Recovered from `v1-sim`, not written for the current game.** Its axes survive the genre change; its
numbers and timings do not. Read the warning box in its header before trusting a line of it.

The summon/build/fit defense structure that briefly lived here was **shelved whole** on 2026-08-12 and is
preserved in [Core defense is off](../decisions/defense-shelved.md).

**A concept never changes folder, so this folder only grows.** `CLAUDE.md`: when a feature comes up in
conversation, it gets a doc here and a row in this table, headed by `Implemented` and `Accepted` on separate
lines — **without both, "written down" reads as "exists".**
