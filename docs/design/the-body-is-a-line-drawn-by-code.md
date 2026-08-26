Status: ⚠⚠ **게임과 함께 죽었다.** 세포 게임의 몸을 그리는 방식이고, 그 게임은 2026-08-22 저녁에 접혔다. 지금 몸은 그림 파일이다.

# The body is an outline drawn by code, not a sprite

**Status**: ⚠⚠ **FULLY REVERSED (2026-08-24)** — 절반 뒤집힘이었다가 이날 전부 뒤집혔다. 아래 덧씀을 읽어라.
⚠⚠ **2026-08-26에 진영이 뒤집히면서 명부도 뒤집혔다** — **아군은 저폴리 검사 하나, 적은 짐승 넷**이다.
**그림값은 0이었다**: 적이던 저폴리 병사가 플레이어가 되고 짐승은 있던 자리에 그대로 남았다.
**이 문서의 교훈은 그 사건에서 한 번 더 값을 했다** — 아래 덧씀의 마지막 절을 볼 것.

## What was decided

**A rounded square drawn as a line, one dot at the centre, empty between them.** Drawn by code, not loaded
from an image, **with images left open as a later swap** (the user's words: build it this way and change it
later if it wants changing). Details were in the GDD's *Screen*. ⚠ **That GDD is gone** — deleted with
the cell game and not revived, so this paragraph is the whole of it.

**And a worn part takes the host's colour, not the prey's.** Eating a cheetah's legs does not paste cheetah
onto the body — the cell digested it.

Decided by generating candidates and looking at them: `tools/pixel/out/cell_*` · `gl_*` · `part_*`.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Two dot eyes** | Made it a face, and a face has a front — which fights a top-down body that parts attach to on all six sides |
| **No dot at all** | Did not read as alive. A plain square |
| **A filled white body** | Generated and shown; the user cut the fill. Outline and dot, nothing between |
| **Sprites for the body** | Squash and stretch are free on numbers and destructive on pixels, and the whole shape is a radius, a thickness and a dot |
| **Generating each species as a whole creature** | Naming an animal overrode the top-down view every time — six species came out in front view (`tools/pixel/out/gl_*`) |
| **Forcing top-down on a whole creature** | The view came back and the animal left: a lion became an orange square, because a mane is surface and surface does not show from above (`gl_lion_td`) |
| **Every part as a generated sprite** | Jaws survive being cut off a body; **a leg does not** — detached it is a brown stick (`part_horse_leg` against `part_jaws`) |
| **Parts keeping the prey's colours** | The user rejected it on sight: what you eat does not arrive looking like what you ate |

## What's tied to it

- ⚠ **The board-per-species rule does not bind this game.** It is the biggest art constraint in this repo —
  parts from different presets can never be made to match — and it is void here because **a worn part has no
  colour of its own.** Two things were resting on it and both are released:
  **the cap of five or six part-giving species per habitat**, and **half the reason external slots were kept
  to six.** ⚠ **Slot counts belonged to the deleted game and do not bind this one** — what survives is the
  reason: **six things sticking out of one small square is all that reads**
- **Being empty inside is why an overlapping swarm still reads.** Forty filled bodies blend into one mass;
  forty outlines do not. **The known cost is that the ground shows through**, and the user accepted it on
  the grounds that the cells are small
- **Swapping in images later is only cheap if drawing stays in one place** — `src/look.gd`'s rule

## Conditions to reopen

The bodies getting big enough that seeing the ground through them reads as a mistake rather than a style.

---

## ⚠⚠ 2026-08-22 저녁 — 절반이 뒤집혔다

**게임이 세포에서 늑대로 바뀌었다.** 사용자: ***"세포로는 안 쓸 거고 바로 아기 늑대들이 있을 듯."***

**뒤집힌 것**: 몸이 **둥근 사각 외곽선 + 점**인 것. **늑대 그림이 그 자리에 온다** — 그림은 전용 AI로
뽑고, 카메라를 보는 2D 판으로 쓴다. **부위 여섯 조립도 같이 빠졌다** — 이유는 아트 예산이다.

**그대로 사는 것**:
- **속이 비어야 겹친 떼가 뭉개지지 않는다.** 2026-08-22에 마흔 마리를 그려서 다시 확인했다.
  ⚠ **늑대 그림은 속이 찬다. 그러므로 이 대가가 청구된다**
- **먹은 것이 먹은 것처럼 생겨서 오지 않는다** — 이제 먹는 것 자체가 없어서 질문이 사라졌다
- **한 마리를 크게 보면 실루엣이 읽히고, 마흔 마리를 보면 색과 덩어리가 읽힌다** (같은 날 새로 잰 것)

---

## ⚠⚠ 덧씀 (2026-08-24) — **전부 뒤집혔다. 지우지 않는다**

**판 위의 몸은 이제 전부 그림이다.** ⚠⚠ **누가 어느 편인지는 2026-08-26에 뒤집혔다** — 그날까지는
아군이 짐승이고 적이 얼굴 없는 저폴리 병사였다. **지금은 아군이 저폴리 검사 하나이고, 적이 짐승
넷(늑대 · 곰 · 까마귀 · 사자)이다.** 몸은 양쪽 다 그대로 그림이다.

⚠ **그런데 이 문서가 옳았던 이유는 안 뒤집혔다.** 「그림은 나중에 갈아 끼울 수 있게 열어 둔다」가
그것이고, 실제로 그 자리 하나(`_beast_tex`)만 고쳐서 다섯 번 갈아 끼웠다 — 원시인, 대두 병사,
저폴리 병사, 그리고 짐승 다섯 종. **선으로 시작한 덕에 그림이 싸게 들어왔다.**
⚠⚠ **2026-08-26에 그 이음매가 여섯 번째로 값을 했다**: 진영이 통째로 뒤집혔는데 **그림은 한 장도 새로
안 그렸다** — 적이던 병사가 플레이어 자리로 옮겨 앉았을 뿐이다. **방향이 뒤집혀도 그림값이 0이려면
그림이 들어오는 자리가 하나여야 한다.**

⚠⚠ **속을 비운 이유(먹은 부위가 host 의 색을 입는다)는 같이 죽었다** — 먹기가 범위 밖으로 나갔고,
부위 자체가 2026-08-24 에 장비 목록으로 갈아엎어졌다.
