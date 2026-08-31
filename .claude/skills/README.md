# .claude/skills — 16 skills, and **every one of them fires on its own**

⚠⚠ **Nothing here has to be typed as a slash command** (2026-08-27, the user: *"having to type them
myself is far too much bother — I would rather just say it"*). **Re-count instead of trusting this
total**: `ls -d .claude/skills/*/ | wc -l`.

## The chain — read this first

**`compass`** (what now) → **`grilling`** (settle what this stretch actually builds, sending **`research`**
outside when an outside fact is needed) → **`build-loop`** (one ticket to code, through
five agents) → **`wrap-up`** (write the answers into the map and the tickets, then commit), with
**`roadmap`** checking the whole way.

⚠⚠ **When a LOOK is what is being chosen, `prototype` hangs off `grilling` at both ends** (2026-08-29):
grilling settles what the thing must do and what the candidates are **before** a folder exists, and the
remarks the user makes on the finished sheet go back through it rather than straight into an edit.

⚠⚠ **`prototype` chooses a METHOD, `commission` chooses a PICTURE.** Both end at a sheet the user looks
at, and both treat a remark on that sheet as a question rather than a work order.

⚠⚠ **The user answers, and only `wrap-up` writes.** Nothing in this chain edits the map during a
conversation — that rule was set on 2026-08-27 after it was broken twice in one session.

**`docs/roadmap/` is what that chain reads and writes** — the map, the log, and the task folders.

## ⚠⚠ How a skill here is written — **short by default, length is earned**

**The failure mode is sprawl**: a document that is simply too long, **even when every line is live and
unique.** Attention thins across the excess. `wrap-up` hit 129 lines and was cut to 69 on 2026-08-27.

| Rule | Why |
|---|---|
| **Steps first, reference under them** | The agent needs to know what to DO before it needs the facts |
| **What only some runs reach goes in a sibling file** behind a one-line pointer | It costs nothing on the runs that never need it — `wrap-up/ACCEPTANCE.md` is the example |
| **A war story earns its place only if it changes what you do** | "This cost a round once" is worth a clause, not a paragraph |
| **One trigger per branch in the description** | Synonyms renaming one branch are one branch written twice |

⚠ **`writing-for-agents` is the full standard**; the four lines above are what this repo keeps getting
wrong. ⚠⚠ **No skill here is invocation-gated** — all of them fire on their own, and it stays that way.

## The user's three

**These are the ones they said they actually use** (2026-08-27).
⚠ **It was four until 2026-08-29** — the fourth was `press`, and it went out that day. The row was pulled and this heading was not, so it read "four" over a table of three until 2026-08-30.

| Skill | What it does |
|---|---|
| **`wrap-up`** | **Closes the session** — repairs the docs that drifted, writes the new tickets, clears the loose images, runs the nets, commits. **Stops at the commit** |
| **`naming`** | **Settles what a thing is CALLED** and writes it into `CONTEXT.md`, so the next round can say it in one word |
| **`roadmap`** | **Checks the big picture** against the commits — drift, gaps, what December still owes — **then lays the weeks out again, one thing per week.** ⚠ **Never edits a file; `wrap-up` writes what it settles.** ⚠⚠ **Slicing a week is the user's call** |

## The rest of the chain

| Skill | What it does |
|---|---|
| **`compass`** | Says where the work stands — the week's row, then every open ticket ranked |
| **`scout`** | How others already did it — three cases with sources, plus one who did the opposite. **Sends the `research` agent** |
| **`build-loop`** | One ticket, plan → build → verify, each in its own agent |
| **`plan-into-ticket`** | Writes an `## Implementation plan` INTO the ticket. Synthesis only, no interview |
| **`grilling`** | Works the tree of **what is being made**, until nothing is left assumed. **Called by `roadmap`, `compass` and `build-loop`** |
| **`prototype`** | Builds one thing **three or more genuinely different ways** and puts them side by side, so a look is chosen by seeing rather than by argument. ⚠ **Called `spike` until 2026-08-29** — renamed to the word the user actually says |
| **`listup`** | **Names what is actually at one spot, one line each, grouped by kind.** ⚠ **It judges nothing** |
| **`commission`** | **시안** — pulls candidate PICTURES so the user chooses by looking. **대화 → 로컬 → 유료**, in that order. ⚠ **Asks before touching the GPU**, and paid generation only when the user says so |
| **`knowledge`** | **개발지식** — reaches `docs/knowledge/` before code is written against Godot, Blender or an instrument, and adds a page when a round measures something durable. ⚠ **It decides nothing and writes no ticket** |

## Kept from `mattpocock/skills`

**They came in on 2026-08-22.** These sit at spots the chain does not cover.

| Skill | Why it stays |
|---|---|
| **`diagnosing-bugs`** | The hard bug: intermittent, or a regression between two known-good states |
| ~~`domain-modeling`~~ | ⚠⚠ **Folded into `naming` on 2026-08-29.** Both wrote `CONTEXT.md` and asked the same question; `naming` was this repo's own. **Its ADR half was dropped** — there is no `docs/adr/` here and decisions go to `docs/roadmap/log.md` |
| **`codebase-design`** | The deep-module vocabulary interfaces are designed with |
| **`writing-for-agents`** | How to write a skill. **The ones written here were written with it** |
| **`resolving-merge-conflicts`** | Two sessions have collided on `main` once already |

## What was deleted, and what it means to restore one

**2026-08-27, in three rounds.** ⚠ **The morning said keep everything** — an audit proposed cutting
sixteen and the user overruled it. **The evening reversed that** once the chain stood, and **the night
cut three more the user said they do not use.** **The later word wins.**

| Gone | What restoring it costs |
|---|---|
| **`breakdown`** | **`grilling` asks and `wrap-up` writes** — restoring it means two skills that both split work into tickets |
| **`tdd`** | The rule it carried survives: **no check at a seam that is not agreed**, and the agreed three are in `CONTEXT.md` |
| ~~**`prototype`**~~ | ⚠⚠ **The NAME came back on 2026-08-29** on a different skill — the one written here that builds three mechanisms side by side. **The imported skill is still gone**, and restoring it now means two skills wearing one word. ⚠ This row used to say it never fired; the record shows **one** call |
| `wayfinder` `to-spec` `to-tickets` | **`compass` + `grilling` + the roadmap file replaced all three.** Restoring means two planning shapes at once |
| `triage` `to-questionnaire` | Both assume **other people** — a reporter filing bugs, a colleague to send a questionnaire to |
| `implement` `improve-codebase-architecture` | `build-loop` owns the build; the architecture sweep never fired once |
| `grill-me` `grill-with-docs` | Both wrap `grilling`, which is kept |
| `ask-matt` `handoff` `teach` `wizard` `setup-matt-pocock-skills` | The router described the upstream flow only; the rest never fired |
| `research` **the skill** | ⚠⚠ **It came back on 2026-08-27 as an AGENT, not a skill** — `scout` is the trigger, `research` is who goes and reads |

## ⚠⚠ **Three more went on 2026-08-29, and the record is what they cost**

**All three had fired ZERO times**, and the call counts were read out of the session transcripts rather
than guessed at.

| Gone | Why, and what it took with it |
|---|---|
| **`code-review-mp`** | It fetched the originating issue from a tracker. **This repo has no tracker; a ticket is a file.** Half its config was corrections saying so, and Claude Code ships its own `/code-review`. ⚠ **`docs/skill-config/` went with it** — it was the only reader left |
| **`survey`** | The four questions were right; **being behind a trigger nobody said was not.** ⇒ **They live in `plan-into-ticket` step 1 now**, where a plan is written and they actually get asked |
| **`press`** | ⚠⚠ **It put unseen forks on the table WITH a recommendation on each**, and the same day the user set the rule *"no recommendation unless I ask for one"*. **`roadmap` and `compass` call `grilling` in its place.** ⚠ **What is lost**: `grilling` works the tree of what is already on the table, so **nothing now volunteers a fork the user has not seen.** That gap is open on purpose |
