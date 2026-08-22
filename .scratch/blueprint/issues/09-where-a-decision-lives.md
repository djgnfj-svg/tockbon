Type: grilling
Status: resolved

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

## Answer

**ⓐ — 결정은 티켓 안에 산다.** 사용자, 2026-08-22: ***"티켓에서 사는 걸로 하는데"***.

**그리고 기획문서는 마지막에 한 장 뽑는다.** 들여온 스킬 넷이 이미 사슬이라서 그렇다:

1. **`wayfinder`** — 정한다. 답은 티켓 안. 스킬이 직접 못박아뒀다: ***"a decision lives in exactly one
   place, its ticket"***, 지도는 색인이라 절대 다시 안 적는다
2. **`to-spec`** — 인터뷰 없이 **이미 정해진 것만** 합쳐서 기획문서 한 장을 뽑는다
3. **`to-tickets`** — 그 문서를 **개발 티켓**으로 쪼갠다 (위아래를 관통하는 얇은 한 줄씩)
4. **`implement-plan`** — 티켓 하나를 다섯 에이전트로 만든다

## 왜 이게 개념 문서 열 개를 다시 안 만드나

**개념 문서가 죽은 이유는 「계속 바뀌는 게임을 미리 서술해서 삭고 거짓말이 됐다」였다.** 이 순서는
**문서를 마지막에, 정해진 것에서만** 뽑으므로 미리 서술하는 단계가 아예 없다.

## 이 답이 같이 닫는 것

- **인박스 76번 ②「기획문서 양식」** — 양식은 `to-spec`의 것이 된다. 티켓 08은 이제 **그 양식을 이
  저장소에 맞게 고치는 일**이지, 처음부터 정하는 일이 아니다
- **인박스 77번「개발은 어떻게 하는게 좋을까」** — 개발 단위는 `to-tickets`의 것이 된다. 지도의 안개에서
  내려온다

## ⚠ 남은 것 둘, 08로 넘긴다

1. **`to-spec`의 「User Stories」 절이 이 게임에 안 맞는다** — ***"As an <actor>, I want a <feature>, so
   that <benefit>"***. 게임에서 `so that` 칸은 「재미있으라고」로 무너지는데, **계획이 재미를 정할 수 없다**는
   게 이 저장소의 두 번째 원칙이다. 그리고 행위자가 플레이어 하나뿐이라 모든 줄이 똑같이 시작한다
2. **`to-spec`이 「extremely extensive」를 요구한다** — GDD가 한 장인 것과 정면으로 부딪힌다

⚠ **접은 갈래와 풀린 티켓이 같은 모양이라는 충돌은 아직 안 풀렸다.** 08이 가져간다.
