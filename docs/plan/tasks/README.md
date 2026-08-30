# tasks — the work, one folder per task

**A task is one numbered folder.** Its `TASK.md` says what is on screen when the task ends. The
`MM-<english-slug>.md` files beside it are its tickets.

**The roadmap is drawn first, and the tasks fall out of it.** Nothing is written here that the map
does not already carry a row for.

## The two-tier number

**A ticket is numbered from `01` inside its own task, never across the repo.**

- Task `03`'s second ticket is **03-02**
- Task `04` has its own `02`, and it is a different ticket
- **A ticket is always said with both halves.** Saying "ticket 02" names two files and is not an answer

## ⚠⚠ A ticket is one day

**The week was the grain until 2026-08-30 and it did not hold — a week is too big to keep quality
inside it.**

⇒ **A ticket that cannot be finished in a day is two tickets.** ⚠ **How it splits is the user's call,
never the model's.**

## The rules that do not change

- **Status is a `Status:` line inside the file.** ⚠⚠ **Files never move between folders**
- **`open` → `claimed` → `resolved`**, and a ticket may carry `Blocked by: MM`
- ⚠ **`Type: task`** is code to write; **`Type: grilling`** is a question only the user can answer

## Who writes here

| Skill | What it writes |
|---|---|
| `wrap-up` | **Every file here**, and only after the conversation is finished |
| `plan-into-ticket` | The `## Implementation plan` section of one ticket, and sets it `claimed` |
| `build-loop` | The `## Answer` section, and sets it `resolved` |
| `roadmap` · `compass` | **Nothing.** They read |

## `00-example/`

**The shape, not work.** Every line in it is a placeholder. **Copy it; never build it.**
