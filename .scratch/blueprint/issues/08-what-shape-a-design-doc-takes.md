Type: grilling
Status: open
Blocked by: 01, 02, 03, 04

# 기획 문서는 어떤 양식을 갖나

## Question

**What form does a design take — the finished ones and the ones still to come — and who reads it?**

## Whose question it is

Row 76, the user's own second step: ***"그다음에 완료된 기획이나 앞으로의 기획문서의 양식을 좀 정할
생각이야"***. ⚠ **They raised it while being shown blueprint tooling and pulled back to the content.** Read
that as **「도구보다 내용이 먼저」** — which is why this ticket sits behind the four content tickets rather
than in front of them.

## Why it is blocked and not just later

**A format decided before there is content to hold is the failure this repo has already paid for twice.**
Ten concept docs carried `Implemented` / `Accepted` headers and were **deleted on 2026-08-22 because nobody
could read them** — the headers were a form with nothing behind them. The form comes out of what the settled
designs turn out to be, not before.

## The live target, already named

- `docs/design/` **dropped `Implemented` and `Accepted` on 2026-08-22 and nothing replaced them.** The folder
  README says out loud: *"Whatever replaces them will be decided when the blueprint is charted again"*
- **The fork docs have a form and it works**: a `Status:` line, a date, who decided, and **a reversal written
  onto the doc rather than by deleting it.** They survived the clearing for that reason
- **The GDD has a form and it works**: **one page**, 한국어, numbers read out of code and not out of prose
- **`.scratch/` has a form imposed by a net**: five map sections, and `Type:` / `Status:` / `Blocked by:` on
  a ticket. ⚠ `net_process` measures **absent → present and nothing more** — a `Status: resolved` nobody
  resolved passes, and an `## Answer` holding one word passes

## What is actually open

1. **What replaces `Implemented` / `Accepted`**, given that what is built is now read out of `src/` and
   `tests/nets/` and what the user has judged is read out of `acceptance-debt`
2. Whether a settled detailed design is **a doc at all**, or a resolved ticket plus a line in the GDD
3. **What language.** The GDD's exception was made on one argument — **the user is the one who reads it** —
   and if that argument covers design docs too, only the user can say so
