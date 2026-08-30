Type: task
Status: resolved

# 늑대 판떼기가 정해졌고 게임에 들어간다 — **H**

## ✅ 사용자가 골랐다 (2026-08-30)

> ***"H가 좋은 거 같은데 H."***

**여덟 벌을 픽셀랩으로 뽑아 한 장에 세워 놓고 골랐다.** 설명은 여덟 벌 다 글자까지 같았고
(`grey wolf, lean, fantasy game enemy`) **스타일만 갈랐다.**

| 무엇 | H |
|---|---|
| **캔버스** | **92×92** — 나머지 일곱은 68×68 이었다 |
| **몸 크기** | **64px** — 나머지는 48px |
| **외곽선** | **검은 단색** |
| **셰이딩 · 디테일** | **기본 · 중간** |
| **시점** | **높은 top-down** — 게임 카메라가 46 도쯤 내려다본다 |
| **뼈대** | **개** |
| **방향** | **넷** — 앞 · 옆 · 뒤 · 반대 |

⚠⚠ **고른 축은 「크기」다.** H 는 B 와 **크기 말고 다른 것이 하나도 다르지 않다** — 같은 셰이딩,
같은 외곽선, 같은 시점, 같은 뼈대. **곧 사용자가 고른 것은 스타일이 아니라 해상도다.**

## ✅ 저장소에 들어와 있다

**`assets/beast/wolf_h/` 에 네 방향 PNG 넷.** 픽셀랩 캐릭터 id 는 `556ee057-1672-48da-8757-37bd7dd28e08`.

## ⚠ 지금 늑대와 무엇이 다른가

- **지금 것은 74×40 캔버스에 좌우 두 방향**이고 걷기·물기 프레임까지 마흔여섯 장이다
- **H 는 92×92 에 네 방향**이고 **프레임이 없다** — 서 있는 그림뿐이다
- ⚠⚠ **캔버스가 프레임마다 다르면 몸이 뛰고 떠오른다** — 2026-08-25 에 열여덟 장을 한 캔버스로
  맞추면서 재어 둔 것이고, 두 벌을 섞으면 그 결함이 돌아온다

## 아직 안 정한 것

1. **지금 늑대 마흔여섯 장을 버리나, H 로 갈아엎나**
2. **동작을 언제 붙이나** — 사용자: ***"애니메이션보다는 일단 늑대 판떼기를 쫙 뽑아서"***
3. **검사 판떼기도 다시 뽑나** — 사용자: ***"실제 유저 좀 티가 안 나 지금"***. ⚠ **게임이 읽는 검사
   그림은 무기 둘뿐이고 몸 그림이 없다**

## 붙일 수 있는 동작

**픽셀랩이 이 캐릭터에 바로 붙여 주는 것**: `bark` · `walk-4/6/8-frames` · `running-4/6/8-frames` ·
`sneaking` · `idle` · `fast-walk`. ⚠ **무는 동작은 목록에 없다** — 따로 만들어야 한다.

---

## Answer — **2026-08-30. H is in the game, standing on the deck**

**Eight wolves ride each boat, drawn from `wolf_h`'s four facings**, picked by the boat's heading
against the camera's yaw. They sit on the benches, they bob and roll with the hull, and each has a
shadow disc under it.

## ⚠⚠ Three things the screen taught, and one of them corrects this ticket

**This ticket said the swordsman has no body picture, only two weapons. That is wrong** —
`sword_r.png` / `sword_l.png` are full body-with-sword drawings. The bodiless ones are
`bow`/`spear`/`shield`, leftovers from a second-weapon idea dropped 2026-08-27, wired to nothing.

**「6× the sprite」 does not mean 6× the wolf.** The four `wolf_h` images fill only **22–73% of their
92×92 frame**, with 11–25 empty rows at the bottom; the walking `wolf_r.png` fills 82% with none. So
the ratio scales the FRAME. The real animal is **0.426 조각 side-on and 0.129 조각 head-on**.
⚠ **And they floated** — the empty rows put their feet 0.161 조각 above the plank, **by a different
amount per picture**, so the deck rose and fell as the boat turned. **They now stand on their ink.**

**Sized by eye at 4× then 6×.** 4× cleared 「invisible」; **6× cleared 「identifiable」** — body, four
legs, muzzle, upright tail. ⚠ **6× is the ceiling and the earlier numbers were wrong**: two rounds
wrote 「about 8×」 and 「10.1× of headroom」, both measured against the 1.0 조각 BETWEEN benches. **The
binding gap is the two seats ON one bench, 0.292 조각**, and 6× has already reached it — eight wolves
now read as **four pairs**, not eight countable figures.

## ⚠ What this ticket asked and still has no answer

**Its three open questions were not settled and are not settled by this.** They move to a new ticket:
whether the 46 walking frames are replaced by H, when animation gets attached, and whether the
swordsman is re-drawn.

**Normal maps were baked** (`north_n` · `south_n` · `east_n` · `west_n`, free, from
`.prototypes/props/bake_normals.py`) **and are NOT wired.** ⚠ **Head-on wolves are 5 screen pixels
wide and a normal map has nowhere to put a gradient in 5 pixels.** Side-on is 17.

---

## ⚠⚠ 이것이 절반만 하고 닫혀 있었다 — 2026-08-30 에 사용자가 화면에서 잡아냈다

**H 는 배 갑판에만 들어가 있었다.** 섬 위에서 걷는 늑대는 **옛 옆모습 두 장**을 그대로 쓰고 있었고,
사용자가 켜 보고 말했다: 「늑대가 내가 골랐던 H 늑대가 아닌거야? 그떄 골랐던 늑대가 아니네?」.

**같은 날 섬에도 올렸다** — 네 방향을 카메라 각도로 고르는 방식은 갑판 것을 그대로 쓴다.

⚠ **H 로 바꾸기만 하면 늑대가 오히려 작아진다** — **H 는 틀의 72% 를 채우고 옛 늑대는 82% 를
채운다.** 20.3 → 17.7 px. 그래서 크기를 1.70 배 따로 줘서 **30.1 x 19.6 px** 이 됐다.

⚠⚠ **걷기·물기 46 장은 같이 못 왔다** — 옛 규격이라 섞으면 몸이 뜬다. **티켓 58 이 그것을 든다.**
