Type: grilling
Status: open

# 무엇이 병사를 강하게 하나

## Question

**섬을 이기고 고른 것이, 정확히 무엇을 바꿔서 병사를 강하게 만드나?**

## 왜 이게 제일 위인가

사용자, 2026-08-23: ***"정확하게 말하면 무엇이 병사를 강하게 하는지. 부위처럼 장비시키는 건지 아니면
종에 대한 건지 뭔지. 사실 여기서는 무궁무진해져서 어떻게 할지 이런 걸 정해야 하는 거 아닌가?"***

⚠⚠ **진단이 맞다. 무엇이든 병사를 강하게 할 수 있으므로, 여기를 안 좁히면 아래가 전부 열려 있다.**
**이 지도의 나머지 넷이 전부 이 답 밑에 있다.**

## 지금 비어 있는 자리

**부위 여섯에 부품을 끼우는 것**이 원래 답이었고, **2026-08-22 저녁에 빠졌다.** 아트 예산 때문이다 —
조립이 남으면 실루엣 조합마다 그림이 필요하다. ⇒ **그 자리가 통째로 비었다.**

⚠ **코드에는 아직 그 구조가 남아 있다**: 슬롯마다 판이 하나씩 있고, **판의 칸마다 종이 들어간다.**
칸 하나가 부위 하나였고 거기에 어느 종의 부품을 끼우는 모양이었다.

## 갈래 넷

| 무엇이 강하게 하나 | 화면에 보이나 | 그림 값 | 정비 화면에 놓을 것 |
|---|---|---|---|
| **장비** — 부위에 붙인다 | 보인다 | ⚠ **조합마다 필요** | 있다 |
| **종** — 어떤 늑대가 무리에 섞이나 | **보인다** | 크기·색으로만 갈리면 **한 벌** | **있다** |
| **무리 전체 성질** — 「우리는 물면 피가 난다」 | 약하게 보인다 | 0 | ⚠ **없다** |
| **대형과 행동** — 뭉치나 흩어지나, 누구를 먼저 무나 | 보인다 | 0 | ⚠ **없다** |

⚠⚠ **사용자가 정비 화면이 필요하다고 했으므로 놓을 자리가 있어야 한다.** 아래 둘은 놓을 것이 없어서
정비 화면이 성립하지 않는다. ⇒ **실제로 남는 것은 장비와 종 둘이다.**

## 이미 정해져 있어서 이 답을 좁히는 것들

- **아트 예산이 제일 센 제약이다.** 1인 개발이고 그림은 전용 AI로 뽑는다
- **빌드는 눈에 보여야 한다** (2026-08-22, 사용자)
- **빌드 셋의 이름이 이미 있다**: 속도 · 출혈 · 무리사냥
- **카드 한 장마다 조금씩 달라진다** — 한 판에 여덟 장이다
- **전투 중에는 손이 안 움직인다.** 시작 전에 다 정한다

## What is actually open

1. **넷 중 무엇인가** — 또는 둘을 겹치나
2. **한 번에 몇 가지를 여나.** ⚠ **넷을 다 열면 12월에 못 낸다**
3. **고른 것이 병사 하나에 붙나, 무리 전체에 붙나**

## Comments

### 2026-08-23 — two findings before the fork is put to the user

**Read out of the code**: the cell of a board holds a SPECIES, and species moves no number at all.
`Loadout.bonus` sums `Rules.part_bonus(part, col)` over filled cells, so the bonus is the sum of six
fixed per-part rows (`PART_STATS`) and the species in the cell only picks the look. `Rules.Species`
says so itself: *"It does NOTHING this round and that is decided, not forgotten: the user took set
effects out and left the species in as the place they will attach."*
⇒ **Picking the species fork means the numbers need a new home**; picking the equipment fork keeps
the numbers where they are and re-opens the art cost.

**Also read out of the code**: the third open question — one soldier or the whole pack — is already
answered by the structure. `Army` holds one `Loadout` for its whole life and the board is keyed by
SLOT, so an upgrade outlives the body that dies. **It attaches to the slot, i.e. every soldier that
slot sends out.**

**How others ship it** (required by the repo's guard against recommending an unnamed technique):

| Game | What it hands the player | Does it need art per combination |
|---|---|---|
| **Bad North** (Plausible Concepts, 2018) | Three classes — infantry, pike, archer — plus four items: bomb, squad-size upgrade, war-horn, hammer | **No.** The four items are *activated*, not worn: they do not sit on the body, so no silhouette combines |
| **Mechabellum** (Game River, 2023) | Buy a unit type, or upgrade a unit you already own to double HP and damage for half the price of a new one | **No.** The upgrade moves numbers; the body stays the same model |

⇒ **Neither ships worn, combinable equipment.** Both still give the player something to fiddle with
between fights, and both keep the art count flat by putting the choice in *which unit* and *how many*,
not in *what it is wearing*.

Sources: [Bad North review](https://saveorquit.com/2019/05/14/review-bad-north/) ·
[Bad North: Jotunn Edition patch notes](https://www.badnorth.com/news/patch/2-00-jotunn-edition) ·
[Mechabellum: upgrade or build more?](https://steamcommunity.com/app/669330/discussions/0/600766248738929634/)
