Type: task
Status: resolved

# 카드 화면에 그림이 없고 등급이 안 보인다

## Question

**이긴 뒤 뜨는 카드 화면에 그림을 넣고, 카드가 뜨는 연출과 등급 연출을 붙인다.**

## 사용자의 말, 그대로 (2026-08-24, 직접 플레이한 뒤)

***"그리고 이미지가 좀 있으면해"*** · ***"카드 뜰떄 연출 약간"*** · ***"카드? 에 등급에 따라 연출 필요"***

## 잰 것 — **그림이 한 장도 없다**

**보상 화면 · 정비 화면 · 타이틀 화면에서 그림을 그리는 횟수가 셋 다 0 이다.**
전부 글자와 도형뿐이다. ⇒ **「이미지가 좀 있으면」은 흐릿한 말이 아니라 정확한 관찰이다.**

⚠ **그림은 이미 있다.** 짐승 다섯 종과 병사 셋이 저폴리로 뽑혀 있고 섬에서 이미 쓰인다.
**카드가 그걸 안 쓰고 있을 뿐이다.**

## 등급은 코드에 있는데 화면에서 안 읽힌다

**등급 넷**(일반·희귀·영웅·전설)이 이미 뽑히는 확률을 정하고 있다.
⚠ **색은 카드 배경 기준으로 쟀는데 정비 화면은 어두워서 거기서는 잘 안 읽힌다** — 이미 기록된 결함이다.

⇒ **색만으로는 부족하다는 것이 이 티켓의 내용이다.** 등급이 높을수록 **연출이 세져야 한다.**

## ⚠⚠ 이 리포의 규칙 하나가 여기 걸린다

***「연출은 과할 정도로」*** — 작게 잡으면 「안 보인다」가 돌아와 라운드가 한 번 더 는다.
**전설 카드는 눈에 띄게 과하게 잡는다.**

## 이음매

**화면.** ⇒ **그물은 짓고 나서 쓴다**(2026-08-24 결정: 화면 일은 나중).
⚠ **보상 화면의 `draw_leaf` 표가 아직 카드 여섯 장을 세고 있다** — 세 장으로 이미 바뀌었으므로
**손댈 때 같이 고친다.** 안 그러면 「0 개를 돌렸다」가 된다.

## Answer

<!-- 아직 -->

## Implementation plan

### ⚠ One premise of this ticket is wrong against the code, and the plan is split on it

The ticket says 「그림은 이미 있다 … 카드가 그걸 안 쓰고 있을 뿐이다」. **Checked against the code: every
card is an EQUIPMENT ITEM, not a beast** — `Run._draw_cards` fills `run.cards` with one item int per
card, and the item table is eighteen pieces of stripped gear (가죽끈 · 청동 판 · 뺏은 창끝 …). Of those
eighteen, only about five have an honest picture among the eight existing textures (뺏은 창끝 → spear,
방패 조각 → shield, 사냥꾼의 눈 → bow, 늑대 송곳니 → wolf, 우두머리의 뿔 → bull). **A wolf picture on a
가죽끈 card is a picture that lies about what the card gives.**

⇒ **Stage 1 (deal-in + rarity presentation + census fix) does not depend on the answer and builds now.**
**Stage 2 (the picture itself) is built against an art table whose CONTENTS are the user's fork**:

- **(a)** generate eighteen item icons with local ComfyUI (`tools/pixel/`), in the soldiers' low-poly
  style, user picks from real candidates — the repo's own standing way to decide art
- **(b)** map the eighteen items onto the eight existing pictures — zero new art, ~13 mappings dishonest
- **(c)** hybrid: reuse the ~5 honest ones, generate the rest

Raised to main as one batched question. **The structure below is identical under all three** — only the
paths in one table differ.

### Seams

**The existing `_paint_*` hook seam on `reward_view` — no new seam.** Every new mark is a new hook whose
`draw_*` count is pinned in `net_draw_leaf`'s table and whose arguments a spy asserts at runtime in
`net_cards` (the spy pattern that file already uses). This is screen work, so runtime checks come AFTER
the build (2026-08-24 rule) — the census table update does NOT wait, see Order.

### Structure

- **Variant, not a new kind.** New rows in existing tables plus new leaf hooks in the existing
  `_paint_*` pattern. No new state beyond what the reveal clock (`_reveal_age`) already carries — the
  deal-in and the pulse both ride it, so no second clock is invented.
- **Adding one new item afterwards touches 2 files**: one `ITEMS` row (`rules.gd`) + one art row
  (`look.gd`). Under the 3-file bound.
- **The new axis is rarity INTENSITY, and every consumer reads one ladder.** Frame width, glow alpha,
  pulse amount and burst-on/off are all indexed by `Rules.Rarity` out of `look.gd` tables — one place
  owns "how loud is EPIC", and COMMON's row is the zero row (no extra mark), so the ladder itself is
  what makes 전설 unmissable: it is the only row with everything on.

### Files to touch and why

1. **`src/look.gd`** — every new presentation constant, nothing anywhere else:
   - `ITEM_ART` — item id → texture path, sized to `Rules.item_count()`. Points at existing
     `BEAST_*`/`HUMAN_*` paths or at new `assets/item/*.png` per the fork. An empty-string row means
     "no picture yet" and the view draws no art rather than crashing — the table may fill gradually.
   - `CARD_ART_*` — the art rectangle inside the card (offset + size; the name/effect lines keep their
     current offsets, art sits above them in the card's empty upper half).
   - `CARD_DEAL_SLIDE_PX` — the deal-in slide distance. **No new duration**: the slide eases in on the
     existing `_reveal_alpha_of(k)` value, so the fade and the slide can never disagree on when a card
     has arrived.
   - `COL_RARITY_GLOW` — four BRIGHT tones indexed by `Rules.Rarity`. ⚠ **Deliberately NOT
     `COL_RARITY` reused**: that table is dark text measured 3:1 against `COL_CARD`; the glow is drawn
     on whatever the 3D field behind the panel shows (the field stays on screen during the pick —
     `game.gd`'s own header says so), so it needs its own bright values and its own comment. LEGENDARY
     stays the only warm one, same argument as the text table.
   - Rarity ladder tables, indexed by `Rules.Rarity`: `RARITY_FRAME_WIDTH_PX` (COMMON row 0.0 = no
     frame), `RARITY_GLOW_LAYERS` / `RARITY_GLOW_ALPHA`, `RARITY_PULSE_SEC` / `RARITY_PULSE_GAIN`, and
     the legendary burst set (`LEGEND_RAY_COUNT`, `LEGEND_RAY_LEN_PX`, `LEGEND_BURST_SEC`). Every px
     ratio carries its pixel value in the comment, per this file's own rule. These are HUD-space px
     (no zoom under them), so the 2.0 px snap floor is the only width bound that bites.
2. **`src/view/reward_view.gd`** — the marks:
   - New leaves, each one call site: `_paint_card_art` (`draw_texture_rect`, skipped when the art row
     is empty), `_paint_rarity_frame` (one stroked `draw_rect` in a layer loop — the glow is layered
     strokes fading outward), `_paint_legendary_burst` (rays behind the card, one `draw_multiline` or
     `draw_colored_polygon` site, drawn only for LEGENDARY).
   - New pure helpers (0 draws): `_deal_offset_of(k)` (slide = `(1 − eased reveal) ×
     CARD_DEAL_SLIDE_PX`, applied to the DRAWN box only — `card_rect_of`/hit rects stay at rest, so
     input and the sim see nothing move), `_pulse_of(k)` (sine on `_reveal_age`), `_art_rect(k)`.
   - Textures loaded once at var init off `Look.ITEM_ART`, the same `load(Look.…)` shape
     `field_view`'s picture block uses.
   - ⚠ **Every new mark multiplies `_reveal_alpha_of(k)` into its alpha**, the same single-channel rule
     the file's own `_draw` comment states — a burst that pops fully lit before its card arrives is the
     exact failure the existing first-frame check shape catches.
   - Fix this file's own stale header while in it: it still says 「six cards … take two … part and
     species pairs」.
3. **`tests/nets/net_draw_leaf.gd`** — the census, SAME ROUND as (2): add every new function name to the
   `reward_view.gd` table (leaves at their pinned counts, helpers at 0), **re-derive the whole table
   against the final file in both directions** — an unlisted function reddens, but a listed function
   that no longer exists silently checks nothing, which is the 「0 개를 돌렸다」 this ticket names. Fix
   the table's own 「six cards」 comment to three-pick-one.
4. **`tests/nets/net_cards.gd`** — the stale 「여섯」/「두 장」 labels that measure `CARDS_PER_WIN` (= 3)
   while saying six: a green whose label says more than it measures is this repo's named false green.
   Text-only this round; the RUNTIME rows for the new marks (below) come after the build.
5. **`assets/item/*.png`** — only under fork (a)/(c), via `tools/pixel/`, user picks candidates.

### Order

1. **`look.gd` constants first** — the view cannot name a constant that does not exist, and the ladder
   tables are the design decision made concrete.
2. **`reward_view.gd` marks** riding those constants, art leaf wired to `ITEM_ART` (empty rows fine).
3. **`net_draw_leaf.gd` + `net_cards.gd` census/label fixes in the same commit as (2)** — never later.
4. **Art fork lands** (user's answer): fill `ITEM_ART` rows; under (a)/(c) generate and pick pictures.
5. **After the build**: runtime rows in `net_cards` (spy-based, existing seam) + `verify-look` pass.

### Risk

- **File overlaps with the two parallel builds** — everything this plan touches:
  `src/look.gd` · `src/view/reward_view.gd` · `tests/nets/net_draw_leaf.gd` · `tests/nets/net_cards.gd`
  · (fork-dependent) `assets/item/`. ⚠ **`look.gd` and `net_draw_leaf.gd` are near-certain collisions**
  with both the faction-select build (shell/title) and the equipment-to-unit build (refit_view) — both
  files hold every screen's constants/census. Sequence the merges.
- **`ITEM_ART` (look.gd) must track `ITEMS` (rules.gd)** — two tables in two files is a diverged
  duplicate waiting. Mitigated: empty row = no art drawn (never a crash), and a post-build row asserts
  the two sizes are equal so a new item without an art row is a red, not a silent blank card.
- **`run.gd` is NOT touched**, though its header comments also still say six-take-two with
  (part, species) pairs — it is the parallel sim build's territory. Left on record here.
- **Fake-code check**: no leaf handed a constant it ignores (census rule 3 covers it); COMMON's ladder
  row being zero is a value the table owns, not a branch that pretends.
- **Sim untouched.** The view keeps reading `run` and writing nothing; hit rects and pressability do
  not move during the deal, so no input behaviour changes.

### Acceptance

- `net_draw_leaf` green with the re-derived closed table; no `Color(` and no presentation literal
  outside `look.gd`.
- Post-build runtime rows (`net_cards` spy, existing pattern): `_paint_card_art` called once per card
  with a non-null texture inside the card rect (for every item whose art row is filled); glow/frame
  intensity strictly non-decreasing across COMMON → LEGENDARY at equal age; burst drawn iff LEGENDARY;
  first frame after `bind` has every new mark near alpha 0 (no pop); `Look.ITEM_ART.size() ==
  Rules.item_count()`.
- `verify-look`: a screenshot of the pick with a LEGENDARY card on it — the legendary card is the
  loudest thing on the screen, per 「연출은 과할 정도로」.

### Out of scope

- **정비 화면 · 타이틀 화면 pictures** — the ticket measured all three at zero draws, but its question
  line scopes the work to the card screen; the other two are their own tickets.
- **Beast CARDS** — CONTEXT.md's design row says cards give 짐승과 장비; the code gives items only.
  Adding a beast card kind is sim work and a different ticket.
- **Rarity changing what a beast LOOKS like** (티켓 01's 「LEGENDARY only」 rule) — no beast has a
  second picture; `rules.gd`'s own comment already refuses this round.
- **Sounds, screen shake on deal** — nothing here touches the shell's clock or camera.
- **`run.gd` comment fixes** — named in Risk, parallel build's file.

---

## 갈림 하나가 닫혔다 (2026-08-24) — **그림은 섞는다**

계획이 찾은 구멍: 카드는 짐승이 아니라 **장비 열여덟**을 주고, 정직한 그림이 있는 건 다섯뿐이다.
**사용자의 답**: ***"그렇게 하자"*** — **정직한 다섯은 재사용, 나머지 열셋은 로컬 도구로 새로 뽑는다**
(병사들과 같은 그림체, 후보를 뽑아 사용자가 고른다).

---

## Answer (2026-08-24) — **지어졌고, 검증 셋이 전부 통과했다**

- **그림**: 정직한 다섯이 카드에 뜨고(84px, 카드 가운데를 실제로 차지), 그림 없는 열셋은 빈 채로 정직하다.
  **남은 꼬리 하나**: 열셋의 그림은 후보 39장(장비당 셋)에서 **사용자가 고르면** 크로마 그린을 지우고
  표에 배선한다 — 표 한 곳 고치기다
- **연출**: 카드가 아래에서 밀려 올라오며 밝아지고(판정 사각형은 안 움직임 — 실행 검증이 관측),
  등급 사다리는 일반 민무늬 → 전설 광선 버스트까지 단조 증가. **전설은 화면에서 제일 시끄럽다**(눈 검증)
- **그물**: 낡은 「여섯 장에 둘」 검사들이 세 장에 한 장으로 뒤집혔고, 합계는 손 재검산으로 맞았다.
  ⚠⚠ **부수 소득**: 카드 그물이 기준선에서 침묵사 중이었음이 잡혔다(배열 범위 밖 크래시).
  이 빌드가 고쳐 통과가 1904 → 1905
- ⚠ **알려진 사소한 것**: CJK 줄바꿈이 「이동속도」를 글자 사이에서 가른다(「이동 / 속도 +2.5」).
  읽히는 데 지장 없음, 눈 검증 판정. 거슬리면 라벨·값 사이만 끊는 손질이 남아 있다
- 검증 셋: 읽기(확정 결함 0) · 실행(새 실패 0, 기준선 13 과 일대일) · 눈(수용 기준 전부 통과)

### 꼬리 진행 (2026-08-24) — 1차 선택이 위임으로 끝났다

사용자: ***"일단 다 니가 선택해둬 나중에 고를게"*** ⇒ 열셋 전부 1차안이 골라져 배선 중.
각 줄에 후보 번호 주석이 남아 **바꾸기는 한 줄**이고, 최종 판정은 사용자가 게임 화면에서 한다.

### 꼬리 완결 (2026-08-24) — 열여덟 전부 배선, 눈 검증 통과

1차 선택 열셋이 잘려서(크로마 그린 제거, 84px 정사각) 배선됐고, **눈 검증이 열셋 전부 「이름대로
읽힌다」로 판정했다.** 가장 약한 하나는 **마른 가죽**(어두운 올리브 실루엣이라 단독으로는 나뭇잎
오독 여지) — 사용자가 나중에 다시 고를 때 1순위로 볼 후보로 기록한다. 새 PNG 열셋의 `.import`
파일이 같이 생겼고 커밋에 함께 들어가야 한다.
