---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use ONLY when the user is choosing a direction or brainstorming, or uses a 'grill' trigger phrase — never as the tail of an ordinary reply.
---

⚠⚠ **This skill is the ONLY place questions are asked in rounds** (the user: *"There are too
many questions. Let us pull this out into a skill. It only needs to happen when brainstorming, but it
happens far too often. It is making me not want to read."*).
**An ordinary reply answers and stops.** ⇒ **Do not invoke this because a reply felt short.** It is for
**a direction being chosen or an idea being brainstormed**, and for nothing else.

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

⚠⚠ **The shape of each question is the user's, given ** — they wrote the three labels out and
said that was the right shape. **A horizontal rule, then numbered blocks of three labelled lines.**
⚠ **The labels stay Korean**: they are printed to the user, who reads Korean, so translating them would
break the very thing they name.

```
---
**질문 1** : <one line>
**추천** : <one line>
**왜** : <one line>

**질문 2** : <one line>
**추천** : <one line>
**왜** : <one line>
```

- **One line each.** The reasoning that does not fit belongs in the body above, not in these lines
- ⚠ **Only ask what has a recommendation and a reason.** A confirmation check is not a question
- ⚠ **Do not bury the recommendation in prose above and leave a bare question at the bottom.** The user:
  *"The questions are so long that I cannot tell what is actually being asked."*
- ⚠ **A frontier of one is a round of one.** Never pad a round to look like grilling
- ⚠⚠ **A frontier of many is STILL a round of one.** See the section below — the frontier decides what
  may be asked, never how much is asked
- ⚠⚠ **No emoji.** The template above used them; **this repo's no-emoji rule wins**

## ⚠⚠ **Everything that is not a question is kept to a MINIMUM** (the user)

***"Do not do anything but those questions and recommendations this session. It gets too long. And from
now on too, when brainstorming, everything but the question and the recommendation is too long. It makes
the body above them too hard to look at. So everything but the questions and recommendations should be
the bare minimum."***

**The round IS the questions.** Everything above them is overhead the user reads before reaching what
they are actually being asked.

- **Three lines above the rule, at most** — what the last round settled, and nothing else
- ⚠⚠ **No section headings above the questions.** A heading is the sign the body grew into a document
- ⚠ **A measurement goes in the `왜` line, never in a table above it.** If it does not fit on that line,
  it is not what the user needs in order to answer
- **Nothing after the last question** — no summary, no next step, no offer

## ⚠⚠ **And the QUESTIONS are minimised too** (the user)

***"I said minimise this — minimise what is outside the questions. Minimise the questions too. The
questions too."*** ⚠ **Said one round after the body was cut**, because cutting the body alone left four
questions still filling the screen.

**One question is the round.** A second is attached only when it is answerable no matter how the first
goes AND it is blocking work today. **There is no third.**

- **Ask the most upstream one and let the rest wait** — the user's answer usually dissolves two of them
- ⚠ **An unasked frontier question is not lost** — it is named in one line above the rule and re-asked
  in a later round
- ⚠⚠ **A question the user has already half-answered is not re-asked to be sure.** Write down the
  reading, and let them correct it

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself.
**Inside this repo — docs, code, nets, git history — read it yourself.** For anything OUTSIDE it, send
**`research`**, which comes back with sources.
⚠⚠ **`research` never answers from memory**, and it is the only agent here that goes to the web. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
