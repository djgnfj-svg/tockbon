# .claude/skills — 17 skills, and **every one of them fires on its own**

⚠⚠ **Nothing here has to be typed as a slash command any more** (2026-08-27, the user:
***"직접 쳐야 되는 부분이 너무 귀찮고, 차라리 그걸 내가 말로 했으면 좋겠고"***). **Fourteen locked
skills were deleted the same day**, along with one that overlapped `scout`. **Re-count instead of trusting
this total**: `ls -d .claude/skills/*/ | wc -l`.

## The chain — read this first

**`compass`** (what now) → **`breakdown`** (one chunk into tickets, sending **`survey`** inside and
**`scout`** outside first, then settling the shape with the user) → **`build-loop`** (one ticket to code,
through five agents) → **`wrap-up`** (close the session), with **`roadmap`** checking the whole way and
handing back to the roadmap file.

**`docs/plan/README.md` is the files that chain reads and writes.**

## Eight written here

| Skill | What it does |
|---|---|
| **`compass`** | Says where the work stands — the week's chunk, then every open ticket ranked |
| **`breakdown`** | One roadmap chunk into tickets. Six steps, and step three stops for the user |
| **`survey`** | What already stands at one spot, what died, which net measures it, which green went false here |
| **`scout`** | How others already did it — three cases with sources, plus one who did the opposite |
| **`build-loop`** | One ticket, plan → build → verify, each in its own agent |
| **`plan-into-ticket`** | Writes an `## Implementation plan` INTO the ticket, synthesis only, no interview |
| **`wrap-up`** | Closes the session — reflects into the docs, runs the nets, commits, **asks whether the user looked** |
| **`roadmap`** | Checks the roadmap against the commits — drift, gaps, what December still owes |

## Nine kept from `mattpocock/skills`

**They came in on 2026-08-22** on the user's ***「다가져와서 사용해보자」***. **These nine sit at spots the
chain does not cover**; the rest assumed a real issue tracker, issues raised by other people, and a team.

| Skill | Why it stays |
|---|---|
| **`grilling`** | The interview primitive. `CLAUDE.md` runs it at the end of **every** reply |
| **`tdd`** | The red-green loop, for `build-loop`'s builder |
| **`code-review-mp`** | ⚠ **The one hole in the chain** — the upstream flow closed `implement` with a review and this repo never wired it in |
| **`diagnosing-bugs`** | The hard bug: intermittent, or a regression between two known-good states |
| **`domain-modeling`** | Keeps `CONTEXT.md` a clean glossary |
| **`codebase-design`** | The deep-module vocabulary `tdd` speaks |
| **`writing-for-agents`** | How to write a skill. **The five written here were written with it** |
| **`prototype`** | Throwaway code that answers one design question |
| **`resolving-merge-conflicts`** | Two sessions have collided on `main` once already |

## What was deleted, and what it means to restore one

**2026-08-27, in two rounds.** ⚠ **The morning said keep everything** — an audit proposed cutting sixteen
and the user overruled it. **The evening reversed that** once the chain above stood:
***"안 쓰는 스킬들은 지워주면 되고"***. **The later word wins.**

| Gone | What restoring it costs |
|---|---|
| `wayfinder` `to-spec` `to-tickets` | **`compass` + `breakdown` + the roadmap file replaced all three.** Restoring means running two planning shapes at once |
| `triage` `to-questionnaire` | Both assume **other people** — a reporter filing bugs, a colleague to send a questionnaire to |
| `implement` `improve-codebase-architecture` | `build-loop` owns the build; the architecture sweep never fired once |
| `grill-me` `grill-with-docs` | Both wrap `grilling`, which is kept and runs on every reply anyway |
| `ask-matt` `handoff` `teach` `wizard` `setup-matt-pocock-skills` | The router described the upstream flow only; the rest never fired |
| `research` | **`scout` stands in its place** — same job, this repo's triggers, and the source count written in |

⚠ **`docs/skill-config/` outlived its skills.** `issue-tracker.md` is now read by `code-review-mp` alone,
and `domain.md` by anything exploring the code.
