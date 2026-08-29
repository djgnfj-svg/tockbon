Type: task
Status: open

# An outside fact never reaches the `scout` skill

⚠ **Not a game ticket.** This is the harness — the skills and agents themselves. It is on the map
because the user asked for it to be, not because it is this week's island work.

> ***"검색하는 스킬이나 에이전트는 안 쓰네? 트리거가 좀 약한가 보다 이건 조정필요로 TODO에 넣어줘"***
> — *"you don't use the searching skill or agent, do you? The trigger must be a bit weak. This needs
> adjusting, put it in the TODO."*

## What actually happened

**2026-08-29.** The user asked one outside question — **whether Bad North's characters are 3D**. The
main session answered it by running **four `WebSearch` calls and three `WebFetch` calls itself**.
**`scout` was never invoked and `research` was never dispatched.** Nine blocks of raw search results
landed in the main window — **which is the exact thing `scout` exists to prevent**: *"the moment a
search result lands in this session's window, the context this skill exists to save is gone."*

## Two causes, and the second one is the hard one

### 1 — The trigger list has no room for a fact check

**`scout` fires on 남들은 어떻게 · 다른 게임은 · 레퍼런스 · 사례 찾아줘**, and on *"whenever a technique
the user has not named is about to be recommended or built."*

**Every one of those is about a technique or an example.** ***"Is Bad North's character 3D?"*** is
neither — it is **one outside fact about one game, with no recommendation attached**. It falls through
the whole list.

### 2 — Even a hit could not have dispatched the agent

**`scout`'s first line is 「Dispatch it, do not read it here」** — the skill is nothing but a wrapper
around sending the `research` agent.

⚠⚠ **But Claude Code appends *"Do not call the AgentTool unless the user requested it"* to every session
in this repo**, and **this repo has no line that lifts it.** ⚠ **The user's other project does** — its
`CLAUDE.md` carries an explicit override that says the default instruction does not apply there, and
notes there is no settings toggle for it, so that line is the only switch.

⇒ **Fixing the trigger alone changes nothing.** The skill would fire and then be unable to do the one
thing it is written to do.

## What is not yet decided

- **How wide the trigger should open.** Every outside fact is too wide — most of them are one search and
  the answer is a sentence. Where the line sits is the question this ticket has to answer
- **Whether the delegation switch goes in `CLAUDE.md` at all**, or whether `scout` is rewritten to search
  in the main session when the question is small
- **Nothing was measured about cost.** How much window the seven direct calls actually spent was never
  counted, so how much a dispatch would have saved is unknown
