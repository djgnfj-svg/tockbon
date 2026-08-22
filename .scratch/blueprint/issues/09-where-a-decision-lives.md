Type: grilling
Status: open

# 정해진 것은 어디에 사는가

## Question

**티켓의 `## Answer`가 세부 기획 그 자체인가, 아니면 나중에 따로 쓸 문서로 가는 이정표인가?**

## Why it cannot wait behind the others

**It changes how every other answer on this map is written.** If a resolved ticket **is** the design, its
`## Answer` has to be readable cold in three months by someone who never saw the map. If it is a waypoint,
the answer can be terse and the real writing happens once at the end.

⚠ **This ticket is taken FIRST despite its number.** It arrived after 01–08 were charted, and the frontier's
「번호 빠른 순」 rule would otherwise put it last — which is backwards.

## Where it came from

The user, 2026-08-22, reading the map that had just been charted: ***"지도와 티켓이 기획문서인건가?"***

## The case for ⓐ — the ticket IS the design

- **`CLAUDE.md` already says it**: ***"A picked idea becomes a ticket on the map, not a design doc."***
- **`docs/design/` has no category for a 세부 기획 any more.** It holds the GDD and the rejected forks, and
  nothing else. The ten concept docs that used to be that category were deleted on 2026-08-22
- **A resolved ticket has the shape that survived the clearing.** The folder README says the forks stayed
  because ***"a fork record describes a decision that was already made, and it does not go stale — it only
  gets reversed."*** A dated decision with its reasoning is exactly what an `## Answer` is
- **A concept doc describes a game that keeps changing, so it goes stale and then lies.** That is the stated
  reason ten of them died

## The case for ⓑ — a separate document at the end

- **Eight scattered answer files are not something a person reads to learn the game.** The map indexes them
  **one line each**, and one line is not a design
- **The GDD is one page by rule**, so the detail cannot be folded up into it
- **`implement-plan` points at ONE ticket.** Nothing in the harness hands a builder 「the whole settled
  design」, and the destination of this map says a plan can be handed over
- ⚠ The counter-case is on the record too: 「양식을 정하는 것」이 내용보다 앞서면 그게 개념 문서 열 개다

## ⚠ The collision that must be named either way

**접은 갈래 and a resolved ticket are the same shape** — a dated decision, with its reasoning, that does not
go stale and can only be reversed. If both categories live, **this repo holds the same kind of fact in two
folders**, which is the exact drift the Korean twins were deleted for on 2026-08-19.

## What is actually open

1. **ⓐ or ⓑ**
2. If **ⓐ** — does a resolved ticket get promoted into `docs/design/` once it is settled, or do 접은 갈래
   and 정해진 것 become one category in one place?
3. If **ⓑ** — **what stops the new documents from becoming the ten concept docs again?** An answer that does
   not name the thing that stops it is not an answer
