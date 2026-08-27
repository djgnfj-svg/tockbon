# .claude/skills — 16 skills, and **every one of them fires on its own**

⚠⚠ **Nothing here has to be typed as a slash command** (2026-08-27, the user: *"having to type them
myself is far too much bother — I would rather just say it"*). **Re-count instead of trusting this
total**: `ls -d .claude/skills/*/ | wc -l`.

## The chain — read this first

**`compass`** (what now) → **`press`** (put the forks the user has not seen in front of them, after
sending **`lookup`** inside and **`research`** outside) → **`build-loop`** (one ticket to code, through
five agents) → **`wrap-up`** (write the answers into the map and the tickets, then commit), with
**`roadmap`** checking the whole way.

⚠⚠ **The user answers, and only `wrap-up` writes.** Nothing in this chain edits the map during a
conversation — that rule was set on 2026-08-27 after it was broken twice in one session.

**`docs/plan/README.md` is the files that chain reads and writes.**

## The user's four

**These are the ones they said they actually use** (2026-08-27).

| Skill | What it does |
|---|---|
| **`wrap-up`** | **Closes the session** — repairs the docs that drifted, writes the new tickets, clears the loose images, runs the nets, commits. **Stops at the commit** |
| **`naming`** | **Settles what a thing is CALLED** and writes it into `CONTEXT.md`, so the next round can say it in one word |
| **`roadmap`** | **Checks the big picture** against the commits — drift, gaps, what December still owes. ⚠ **Reports only; never edits the map** |
| **`press`** | ⚠⚠ **Asks what the user did not know to ask.** The forks this direction forces that they have not seen. Called by `roadmap`, `compass` and `wrap-up` |

## The rest of the chain

| Skill | What it does |
|---|---|
| **`compass`** | Says where the work stands — the week's row, then every open ticket ranked |
| **`survey`** | What already stands at one spot, what died, which net measures it, which green went false. **Sends the `lookup` agent** |
| **`scout`** | How others already did it — three cases with sources, plus one who did the opposite. **Sends the `research` agent** |
| **`build-loop`** | One ticket, plan → build → verify, each in its own agent |
| **`plan-into-ticket`** | Writes an `## Implementation plan` INTO the ticket. Synthesis only, no interview |
| **`grilling`** | Works the tree of what is **already** on the table. ⚠ **`press` is the other half** — what is not on it yet |

## Kept from `mattpocock/skills`

**They came in on 2026-08-22.** These sit at spots the chain does not cover.

| Skill | Why it stays |
|---|---|
| **`code-review-mp`** | ⚠ **The one hole in the chain** — the upstream flow closed its build with a review and this repo never wired it in |
| **`diagnosing-bugs`** | The hard bug: intermittent, or a regression between two known-good states |
| **`domain-modeling`** | Keeps `CONTEXT.md` a clean glossary |
| **`codebase-design`** | The deep-module vocabulary interfaces are designed with |
| **`writing-for-agents`** | How to write a skill. **The ones written here were written with it** |
| **`resolving-merge-conflicts`** | Two sessions have collided on `main` once already |

## What was deleted, and what it means to restore one

**2026-08-27, in three rounds.** ⚠ **The morning said keep everything** — an audit proposed cutting
sixteen and the user overruled it. **The evening reversed that** once the chain stood, and **the night
cut three more the user said they do not use.** **The later word wins.**

| Gone | What restoring it costs |
|---|---|
| **`breakdown`** | **`press` asks and `wrap-up` writes** — restoring it means two skills that both split work into tickets |
| **`tdd`** | The rule it carried survives: **no check at a seam that is not agreed**, and the agreed three are in `CONTEXT.md` |
| **`prototype`** | Never fired once. This repo answers design questions by putting the real game on screen |
| `wayfinder` `to-spec` `to-tickets` | **`compass` + `press` + the roadmap file replaced all three.** Restoring means two planning shapes at once |
| `triage` `to-questionnaire` | Both assume **other people** — a reporter filing bugs, a colleague to send a questionnaire to |
| `implement` `improve-codebase-architecture` | `build-loop` owns the build; the architecture sweep never fired once |
| `grill-me` `grill-with-docs` | Both wrap `grilling`, which is kept |
| `ask-matt` `handoff` `teach` `wizard` `setup-matt-pocock-skills` | The router described the upstream flow only; the rest never fired |
| `research` **the skill** | ⚠⚠ **It came back on 2026-08-27 as an AGENT, not a skill** — `scout` is the trigger, `research` is who goes and reads |

⚠ **`docs/skill-config/` outlived its skills.** `issue-tracker.md` is now read by `code-review-mp` alone,
and `domain.md` by anything exploring the code.
