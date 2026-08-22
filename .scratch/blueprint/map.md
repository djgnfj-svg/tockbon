# 청사진 — the detailed designs, re-settled

**Charted 2026-08-22, the first map in this repo.** The idea is the user's own, and it is row 76 of the idea
inbox: ***"지금 내가 원하는건 이 프로젝트의 청사진하고 세부 기획들을 다시 잡는 것이고 그다음에 완료된
기획이나 앞으로의 기획문서의 양식을 좀 정할 생각이야"***.

## Destination

**The detailed designs behind the GDD, re-settled, so that a person can sit down and judge whether this game
is fun.** Done means the GDD's five 「아직 안 정한 것」 lines and every open inbox row that touches the game
are each **decided or explicitly ruled out of scope**, and one plan can be handed to a builder.

⚠ **No code is written on this map**, and **this map does not decide whether the game is fun** — planning
principle 2 says it cannot, and both dead games died proving it. It settles what must be settled so the
question can be put to a person.

## Notes

**Domain**: a cell autobattler in Godot 4.7.1. The words are `CONTEXT.md`. **What is built is read out of
`src/` and `tests/nets/`**, never out of a design doc — ten concept docs were deleted on 2026-08-22 for
exactly that reason.

**Skills every session on this map consults**: `grilling` and `domain-modeling` by default; `how-others-do-it`
**before recommending any technique the user has not named themselves**; `planning-principles` first.

**Standing preferences for this effort**, all from the user's own words:

- ***"바닥에서 네가 한번 적대적으로 검토해서 채울 것 채운 다음에 질문을 좀 해줄래?"*** (row 70) — **fill the
  obvious in adversarially first**, mark what was assumed and what would overturn it, and ask only what
  genuinely blocks. An invented question is a failure, not diligence
- **채택 여부는 하나씩 물어본다** — one fork per question. This is why a ticket is one question and a session
  resolves one ticket
- ***"MVP잖아"*** (row 70) — a detail the MVP does not need answered is not a ticket
- **Anything the user says in passing goes into `docs/idea-inbox.md` that turn**, verbatim, dated
- ⚠ **Ticket 09 is taken first, ahead of its number.** It asks where a settled decision lives, and until it
  is answered **nobody knows how fully to write any other ticket's `## Answer`.** It was charted after 01–08,
  so 「번호 빠른 순」 would otherwise put it last, which is backwards
- **The map is English** because `CLAUDE.md` says docs are English and excepts only the GDD. ⚠ **Only the
  user can add a second exception** — if this page is one they will not open, that is the same failure the
  GDD exception was made to prevent, and it is theirs to call

## 지금까지의 결정

<!-- one line per closed ticket: the gist, then the link. Nothing is restated here — the ticket holds it -->

**Nothing yet.** Charting decides nothing; the first resolution lands here.

## Not yet specified

<!-- in-scope fog: seen coming, not yet sharp enough to phrase as one question. Graduates into tickets -->

- **재미를 어떻게 판정하나.** The GDD's first undecided line is ***"재밌는가"*** and the honest state is that
  **only 연출과 소환 동작 have ever passed** — the game itself never has. What the sitting looks like, what
  is in front of the user when they sit, and when in the route it happens **cannot be phrased yet**: the
  thing they would play does not exist in a settled form until the fight's hand-count and the reward/refit
  loop are decided. ⚠ This is the destination's own reason for existing, so it graduates last, not never
- **개발은 어떤 단위로 하나** (row 77, the user's own open question). The proposed shape was 청사진 → 직접
  해봐야 아는 것만 throwaway prototype → one plan → the five agents. ⚠ **The case against is on the record
  and unanswered**: this game already runs, so **a temporary thing inside the real game may beat a separate
  prototype**, and every reference cited assumes a project with nothing built. Hangs on how large the settled
  designs turn out to be. Row 65 (배치냐 일괄이냐) is the same family and leans, undecided
- **속도 조절.** In the code, taken off the screen. Only sharp once the fight's hand-count is settled — a
  speed control is either a comfort or the fifth hand-movement, and which it is depends on ticket 01
- **맵이 한 화면을 넘어가도 되나** (row 21). It **removes a constraint the map arithmetic was built on** —
  the coordinate table exists because *"160px does not fit 720"*. Only bites if the floor or node count moves
- **적이 셋뿐이다** — 들소 · 까마귀 · 사자. Nothing in the record says how many an MVP needs, and the second
  dead game's answer to thin content was four more small species, which **failed every time it was measured**

## Out of scope

<!-- ruled beyond this destination. Never graduates; returns only if the destination is redrawn -->

- **메타 진행 — 세포연구소, 해금, 판이 끝난 뒤에 남는 것** (row 62, and the GDD's third undecided line).
  **Out of scope because the destination is making the game in front of us judgeable**, and row 62's own
  surviving line says it: **the first run must be worth playing with zero unlocks**, and run one is what
  decides whether there is a run two. ⚠ `meta-unlocks-not-stat-boosts` is reversed, so this is **not** a
  refutation — it is a scope line
- **아티팩트와 보물섬 — the third reward axis** (the GDD's second undecided line). Row 72 made **every node a
  fight node** by the user's decision and the chest is already gone from `Rules.NodeKind`. A third axis needs
  a node type that does not exist, so it is past this destination
- **하네스 — 아웃바운드 질문 경로, `grilling`의 세 구멍, `grill-me` 껍데기** (rows 2 · 15 · 74). Tooling, not
  this project's blueprint. ⚠ Row 24 records the user's own instruction that these are being handled
  elsewhere and are not to be raised again
