---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use ONLY when the user is choosing a direction or brainstorming, or uses a 'grill' trigger phrase — never as the tail of an ordinary reply.
---

⚠⚠ **This skill is the ONLY place questions are asked in rounds** (2026-08-27, the user:
*"질문이 많아 이거 스킬로 빼자 브레인 스토밍할때만 하면 될꺼같은데 너무 자주 하네 글을 읽기가 싫어짐"*).
**An ordinary reply answers and stops.** ⇒ **Do not invoke this because a reply felt short.** It is for
**a direction being chosen or an idea being brainstormed**, and for nothing else.

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

⚠⚠ **The shape of each question is the user's, given 2026-08-24** (*"질문 추천 왜 / 질문 : / 추천 : /
왜: / 이렇게가 맞는데.."*). **A horizontal rule, then numbered blocks of three labelled lines:**

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
  *"질문이 너무 길어서 그래서 정확하게 뭘 말하는 건지 잘 모르겠네"*
- ⚠ **A frontier of one is a round of one.** Never pad a round to look like grilling
- ⚠⚠ **No emoji.** The template above used them; **this repo's no-emoji rule wins**

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
