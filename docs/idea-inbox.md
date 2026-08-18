# Idea inbox — what the user said, before anyone decides what to do with it

**Why this exists**: the user said it plainly on 2026-08-19 — ***"내가 그냥 대화를 하고 있지만 사실 항상
아이디어를 내는 거거든? 근데 니가 그냥 지워버림."*** Ideas arrive inside ordinary conversation, and a
conversation is lost while the repo is kept.

⚠ **A rule for this already existed and was not followed**: `CLAUDE.md` says *"when a feature comes up in
conversation, create a `docs/design/` doc and add one row to its README."* **The bar was too high.** Writing
a whole design doc for a remark made in passing costs more than the remark, so nothing got written at all.

⇒ **This file is the cheap version.** One line, the user's own words, the date, and a state. **No analysis,
no options, no recommendation** — those belong in a design doc, and an idea only gets one once it is picked.

## How to write a row

- **Verbatim where possible.** A paraphrase is already an interpretation
- **Append at the bottom.** Never reorder, never rewrite history
- **A row is added the moment it is heard**, not at the end of the session
- **State is one of**: `open` · `→ doc-name` (it grew into a doc) · `refuted` (with the one-line reason) ·
  `dropped` (the user dropped it). **Nothing is deleted** — a dropped idea coming back is information

⚠ **`refuted` is not `dropped`.** The first means arithmetic or a measurement killed it and the reason is on
the row. The second means the user moved on. Collapsing the two is how a refuted idea gets re-proposed and a
dropped one gets argued about.

---

## 2026-08-19

| # | What was said | State |
|---|---|---|
| 1 | *"ultracode를 실행가능하게하는 빌드 규칙을 정해도 될꺼같고"* | **→ `parallel-build`** |
| 2 | *"게임성 자체를 점검하는것도 좋은거 같아"* | ⚠ **open — nothing done.** Named in the same breath as the harness work and then never returned to |
| 3 | *"개발이 너무 느린게 지금 답답한점임"* | **→ `parallel-build`** section 0 — measured: the round is 6.7s, the wall clock is 24 agent round-trips |
| 4 | *"내말을 좀 이해못하고 기록안하는게 불만이고"* | **→ this file** |
| 5 | *"내가 말한대로 개발을 안하네?"* | **open.** The standing instance: the user decided six island grids, three exist, and `MAP_NODES`'s island column is still `[0, 1, 2, 1, 2, -1, 2]` |
| 6 | *"다른에이전트의 상황을 다른 에이전트가 몰라서 … 문서를 통해서 나눠서 해결할 수 있지 않을까?"* | **refuted** — an agent's doc copy freezes at spawn and never refreshes (measured), so a shared status doc cannot coordinate live agents. Worktree isolation removes the need instead |
| 7 | *"멀티 워크플로우로 분리개발하고 diff 해서 merge 하는 방법은 별로임?"* | **adopted → `parallel-build`.** It beat the alternative on the doc's own numbers: git conflicts on hunks, not files, so pre-allocating code was oversized |
| 8 | *"내가 지금 넷이 의미가 있나? 싶은게 계속 있음"* | ⚠ **open, and it is the biggest one on this page.** Every verdict the user has given came from playing, not from a net; the mutation sweep spends 20–40 min a stage proving the nets are honest. Nobody has answered what that buys |
| 9 | *"완료 할 때 각각의 작업에서 무엇을 했는지 말하는 내가 읽어야 하는 보고서가 필요함"* | **→ `parallel-build`** section 4 |
| 10 | *"문서는 영어로 하면 되는데 한국어로 되어있을필요없어"* | **done.** Eight Korean twins deleted, 5878 lines; the rule in `CLAUDE.md` replaced |
| 11 | *"어느센가 claude.md 가 너무 길어졌다고 생각함 한 300줄 정도가 적당한데"* | **done.** 725 → 381 lines (285 excluding blanks). Four sections moved out whole, nothing deleted |
| 12 | *"내가 그냥 대화를 하고 있지만 사실 항상 아이디어를 내는 거거든? 근데 니가 그냥 지워버림"* | **done — this file**, plus the rule in `CLAUDE.md` |
| 13 | *"싸움이 좀 아직은 별로네? 일단 다음 세션에서 꽉 잡아봐야겠다"* (2026-08-18) | ⚠ **open, parked by the user themselves.** Carried here because it is the only verdict about what happens *after* the start button |
| 14 | *"spec 부분을 좀 개선할까? 왜냐면 내가 말한댈 잘 안되는 경우가 있어서"* | **refuted — spec is not where it breaks.** `title-and-map`'s plan opens with a section titled *"OPEN questions — these go to the user in ONE message"*, five questions with defaults and consequences, and a warning not to infer answers. ⚠ **The message was never sent.** All five defaults shipped silently, question A gated step 5, and step 5 was descoped. **The gap is outbound, not spec** |
| 15 | Outbound questions have no route out of the plan doc | ⚠ **open.** Two rules already say to relay them (the plan's own section, and `build-feature`) and **both are honour-based, so both were skipped.** Sketched: collect open questions in one file, and **redden a net when a plan holds an unanswered question that file does not carry.** Nothing built |
| 16 | *"문서로 설계했으면 됬음 그러면 돌리면 나오도록 문서로 만들었다는거 아니여?"* | **refuted, and it is this session's own lesson twice over.** Only two things load themselves: `CLAUDE.md` and the skill being invoked. A doc under `docs/` is read only if something points an agent at it, and **nothing pointed at `parallel-build`** — the same shape as the plan section that said *"these go to the user in ONE message"* and never went. ⇒ **The report is now numbered step 7 in `build-feature`**, with the runner capture and the per-round commit that feed it |
| 17 | *"어느정도는 강제하자"* | **done — `net_process`.** Forces the round log (five fields a block) and the sent-declaration. Four plans grandfathered, **the list is pinned at four.** Both tree checks were mutation-tested: deleting the sent-line reddens 1, growing the exemption reddens 4. ⚠ **Shape only, never truth** — a `yes` on a message nobody sent passes |
