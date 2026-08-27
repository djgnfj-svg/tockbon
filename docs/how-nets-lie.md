# How nets lie — every green that was measured to be false

**Where this came from**: it lived inside `CLAUDE.md` until 2026-08-19 and had grown to 129 of its 726
lines. **Nothing here is edited** — it is moved so it can keep growing without CLAUDE.md growing with it.

⚠ **CLAUDE.md keeps the rule and points here for the cases.** A rule is short enough to auto-load; a
casebook is not. **Read this file before writing a check, and before believing a green round.**

⚠ **Every entry below is a measurement, not a worry.** Each one is a green round in this repo, or in one of
the two deleted games, that turned out to guarantee nothing. **Do not delete an entry because it looks
unlikely** — the whole point is that each of them looked unlikely to whoever shipped it.

---

## No fake code

Code that pretends to work is worse than code that doesn't.

- Hardcoding for this input or this test only
- Returning a plausible value instead of computing one
- Reporting a stub as finished
- Swallowing an error so it looks like success
- **Screen changes but sim doesn't (or the reverse)** — the signature fake

If you can't do it, say you can't.

**And one whole class of it was structural, not dishonest.** The deleted game ran three clocks (render,
60Hz physics, a 20Hz simulation tick) and **five separate defects came out of the seam between them** — a
60Hz event whose period shared a factor with the divider was invisible to the tick; a check that pumped one
physics frame measured nothing at all; a hit test sampling one position in three let a player and a
projectile pass through each other, which read as "this tuning value cannot be changed" for two sessions.

⇒ **If the new game ever runs a fixed timestep under its render loop, read this paragraph again and write
the traps down as they are measured.** They are not in the general case — they are what happens when two
clocks meet, and they cost more than anything else in that codebase.

## No fake nets

When the label claims more than the check measures, that green is a false guarantee.

**Invert every new check.** An uninverted check proves "it runs", not "it measures".
**If the inversion doesn't bite, suspect the check last — first confirm the mutation actually landed.**
String replacement has silently matched zero times, twice.

**A truncated search is not a search.** `grep ... | head` on a term with many hits **silently drops the one
that matters**, and an empty tail reads as an absence. That is how "there is no scan of this file" was
asserted confidently about a scan that exists — the noisy match filled the window and hid the quiet one.
⇒ **Count the hits before reading them**, and never conclude *absence* from a truncated result.

**Invert the instrument, not only the subject.** Twice in one night a check was written to catch a defect and
**shipped carrying that same defect**: a scanner for citations wrapped across comment lines joined only on
spaces, so the mid-token wrap — the shape it existed to find — stayed invisible; and a dim-check folded two
alphas into one array, so deleting one outright stayed green because the other's minimum held. **Neither was
caught by inverting the code. Both were caught by inverting the check.** ⇒ A new check needs a case that
fails *it*, not only one that fails what it points at.

These survive **even after you confirm every mutation goes red**:

- **A check that reads only final state cannot measure an ordering contract.** Iteration order was reversed,
  final state was identical, three checks stayed green. Add a check that measures the process
- **A/B comparison catches "diverged", never "vanished".** Fold two paths into one and `scan == scan` — 39
  checks all green. "Slower without it" is caught only by timing
- **A loop whose condition is false from the start never runs the check at all.** A settle loop passed with
  zero iterations. Assert the iteration count too
- **A check that greps a file measures its text, never what it computes.** Five scans shipped in one feature
  and **every one was evaded** — a decoy line, one added term, an `@export` moving the declaration off
  `^var`, the same write from another file, an early `return` between the two lines a scan compared.
  **Drive the value instead.** `_ready()` · `_gui_input()` · `_physics_process()` and ordinary methods are
  all callable on an **untreed node** with enough wiring — **and `_draw()` too**, once the runner pumps
  frames. **Nothing in this engine resists headless.**
  **"It can't be driven headless" has been claimed four times and was wrong four times.** The fourth cost
  the most: a panel that **never set `visible`** shipped under 5,576 green checks, because the same file had
  written down "no font outside the tree" as if it were a fact
- **A spy on a hook sees the HOOK, never the native call inside it.** Measured on plan 3: with the whole
  argument chain closed — a literal pinned at `_paint_body`'s call site and read back off the spy —
  **emptying `_paint_dot`'s and `_paint_outline`'s bodies left the round green.** There are no pixels to
  read back headless, so the last inch has to be pinned **structurally**: `net_draw_leaf` counts
  `draw_*` calls **per function**, and carries four cases that fail the *scanner*. ⚠⚠ **The example
  that stood here — 「in `field_view.gd` (each leaf exactly 1, `_paint_cell` 7)」 — died with the flat
  2D board and was removed 2026-08-27.** `_paint_cell` has never existed in that file, and the net's
  `field_view.gd` table is now **every entry 0**, which is the whole of what it claims about a view
  that draws a 3D world. The counting still runs, against `refit_view.gd`. ⇒ **Argument capture proves a value was computed and handed on. It
  never proves the value was used.** Chase it to a leaf, then pin the leaf by counting
- **The plan's own fix gets applied to one value and not to its siblings.** Plan 3 predicted in writing
  that five internal slots could change nothing on screen and stay green; the builder closed **corner**
  through `_blob` and left `outline_width`, `colour_depth` and `dot_radius` open one line over — and all
  six *external* slots could stop drawing at once. Four read-only passes found ten of these on an
  already-green round of 811, each confirmed by a mutation. ⇒ **Re-measure the whole table, not the row
  someone is arguing about** — this file's older sentence, re-earned
- **"`_draw()` ran" is not "anything was drawn."** Counting the call — even through a `super()` that draws
  nothing — measures the engine, not the picture. Three separate features shipped this way in one day, each
  erasable with 6,163 checks still green. **Godot refuses to override a native draw call**
  (`draw_texture_rect`, `draw_string`) — it is a parse error. ⇒ **Cut a `_paint(...)`-shaped hook out of
  `_draw()` and override that**, then assert the arguments. And drive it **treed with `pump_frames`** —
  calling `_draw()` by hand barks "drawing outside NOTIFICATION_DRAW"
- **Wiring a node by hand in the net hides the line that wires it in the shell.** Helpers that pre-set
  `@onready` fields let you delete the real `setup()` call and stay green while the game shows nothing.
  **Null the field back out before calling `_ready()`**
- **A check whose bounds come from the thing it checks proves nothing.** A wall test read the wall's own
  extent and asserted inside it — shrink the rectangle and the test shrinks with it. **Pin literal
  coordinates**
- **Measuring a pure function is not measuring that anything calls it.** A rect function was asserted
  correct; `_draw()` was then free to pass a bare `Rect2()` and **320 checks stayed green** — the notice
  painting at zero size, invisible. **Capture the argument at the hook and assert it equals what the pure
  function returns.** The builder had closed this exact hole one file over and left it open here; a verifier
  who had not built it found it. **This is the case for the verifier never being the builder** — measured,
  not assumed
- **`visible` is not "on screen", and neither is being wired.** `set_anchors_preset` sets anchors and
  **leaves the offsets alone**, so a `Control` added to a bare `CanvasLayer` keeps `size == (0, 0)` — and
  a panel that lays itself out from `size` then piles into the top-left corner while every check about it
  passes. Assert the size against the viewport and assert the laid-out rectangles land inside it
- **A tuning constant with a floor on one end and none on the other is half-measured.** One frame-count
  constant carried `>= 12`; its twin did not, so **2 through 11 were green** and the fade collapsed to a pop —
  the very thing the beat existed to remove. **One bite does not prove the range**
- ⚠ **A ceiling with no floor passes an effect that never happens.** The presentation round found this on
  **four items at once**: every row bounded *"the lunge never overlaps more than 6px"* and none of them said
  *"the lunge is not always zero"*, so **deleting the whole animation stayed green.** ⇒ **Bound both ends,
  in the same row.** The floor is the half that proves the feature exists
- ⚠ **Mouse clicks cannot be driven through `root.push_input()` headless, and they fail silently.**
  The headless window is **64×64**, so the stretch transform is **0.05**; `Viewport.push_input` divides the
  incoming coordinate by it and a click aimed at a dock **arrives at (2000, 6520), hits nothing, and raises
  no error.** Keys carry no coordinate and pass through fine — so **half an input suite can be green while
  the other half is dead.** ⇒ Call `game._unhandled_input(ev)` directly, or multiply by
  `root.get_final_transform()` before pushing. Measured with a spy node: the `InputEventMouseButton` itself
  does reach `_unhandled_input`; **only the coordinate is wrong**
- ⚠ **A `const` Array cannot be mutated at runtime, so "zero this table entry and watch it redden" is not a
  mutation you can write.** Twelve planned net rows died on this. **Drive the accessor instead** — the
  off-by-one in `fx_gain_of` is reachable and the raw table is not
- ⚠ **A spy that CAPTURES an argument no row ever reads is a hole with a lid on it.** The map's seven
  leaves captured `col` on four of them and **not one check inspected any of the four** — so the
  you-are-here ring, the border on every reachable node, all six reward glyphs and the screen's only two
  numbers could each be drawn at **alpha 0 with 1911 checks green.** The capture *looks* like coverage in
  a code review, which is why it survived a first adversarial pass. ⇒ **List the keys a spy stores and
  grep for a reader of each.** And read them as CONTRAST against what they are drawn on, not only as a
  non-zero alpha: the shipped glyph cleared any alpha floor at **1.3 : 1** and was unreadable
- ⚠ **A bounding box of zero extent still returns the right centre.** A helper that read each captured
  ring's centre back — written precisely to prove *a count cannot say WHERE* — could not see
  `_ring_points(centre, radius * 0.0, …)` collapse every polygon and polyline to a single point.
  ⇒ **When a check reads geometry back, read the EXTENT beside the position.** This is
  `draw_circle(p, 0.0, col)` again, arriving at the geometry argument instead of the radius one
- **Measuring a pure function is not measuring that anything calls it — and the scanner has a hole shaped
  exactly like that.** `net_draw_leaf._scan` skips any function with `draw` count 0, so building geometry
  inside a helper and passing an **empty** array to the leaf reads as *1 draw call, 4/4 arguments used* —
  green, with nothing on screen. ⇒ **Build the points in `_draw()` and hand them to the leaf as an
  argument**, so the spy captures the geometry itself
- ⚠⚠ **A GREEN CHECK CAN BE AN ARTEFACT OF THE DEFECT BESIDE IT.** `net_run._timeout_loses` landed one
  soldier, held nine at the harbour, and asserted the island took **all 3600 sub-steps** of its 60 s
  limit. It had been green in every round since it was written. What made it pass was the bug in the loss condition one file over:
  `_phase_clock` lost on `army.living_count() == 0`, which counts reserves, so an island whose whole
  beachhead was dead could not end. The lone soldier actually died at **477 sub-steps (7.95 s)** — **52
  of the 60 seconds that check asserted were the defect**, and the moment the loss rule was fixed the
  fixture reddened. ⇒ **When a defect is fixed, the checks that were green around it are suspects, not
  controls.** A check that survives a fix unchanged has been re-verified; one that reddens was
  measuring the defect, and the two look identical until the fix lands

## A translated bark leaves its declaration behind

A `push_error` message and the `t.expect_error` that forgives it are **one unit**, matched by plain
substring. Translating one side and not the other leaves the bark undeclared — the net reds on a bark
nobody changed, or worse, forgives one it was never meant to.

## Two the arrangement caused, not the check

**Moved here 2026-08-22 from `implement-plan`, which was deleted.** Everything else that skill had measured
about verification was already on this page; these two were not. ⚠ **Both were measured on the cell game**,
whose `src/` is gone — they are kept because they are about **who verifies and when**, which the next game
arranges the same way.

- ⚠⚠ **NUMBERS CANNOT SEE A PICTURE.** Screen verification was held back to the last stage. With **279
  checks green**, it found three defects in minutes: the field had **no floor colour at all** (the constant
  was read in zero places, and the engine key that would have set it was nested inside its own section so
  nobody read it), the victory beat was **a still frame for 62% of its length** while the HUD still read the
  pre-battle count, and the game filled **44% of the window**. **Five of the previous round's seven surviving
  mutations were the same family** — a headline in the wrong band, labels 10,000px off, six rows past the
  left edge. **All green.** ⇒ **Look at the screen in the FIRST round that draws anything**, not at the end.
  This repo measured the same thing four separate times.
- ⚠ **A verification that overlapped an edit measured nothing, and it does not announce itself.** The tree was
  broken **three times** while the runtime verifier was observing — two parse errors and one broken table,
  all of them intermediate saves by whoever was building. ⇒ **One chunk → nets green → report → halt.**
  That halt is the verification window; without it the verdict is void whichever colour it came back.

## net_cards died silently at baseline, and the ledger blamed the wrong ticket (2026-08-24)

The reward-card net crashed with an out-of-bounds get in a leaf check — the wrapper marked it [failed],
but it still counted 63 passes, and the map's ledger attributed ALL 13 baseline reds to the 3D-move
ticket. One of them was this crash. **A crashed net is a vanished-check variant**: the checks after the
crash line ran zero times while the ledger read as if only stale expectations were red. Found when the
card-screen build rewrote the dead assertion (the old check asserted a guide-text state that cannot
render under three-pick-one) and the pass count moved 1904 → 1905 for no apparently related reason —
the +1 was the crash healing. **Lesson**: when a red round's failure list is attributed wholesale to one
cause, verify each item — a crash and a stale expectation look identical in the total.

## Green buffers, invisible picture — the death burst (2026-08-24)

The 3D fx nets measure two things per effect: the geometry buffers (proof it was built) and the committed
surface count (proof the flush ran). Both were green for the death burst, and the effect log showed it
alive for its whole 0.32 s. **It was still invisible in play.** The ring started at the SIM body radius
(10-22 px) while the drawn bodies are 84 px billboards, and this game's fights are always packed — the
ring was swallowed whole by the sprite pile every time. **Nothing in the net was wrong; the net measured
the drawing, and the drawing was too small to see.** Fixed by deriving the start radius from the sprite
width ratio, so it grows when the art grows. **Lesson**: a buffer-and-commit net proves an effect was
drawn, never that it can be SEEN. Anything sized off sim units while the art is sized off sprite units
needs an eye, and this is what verify-look is for.

## The orphan list was stale the moment it was written (2026-08-24)

A hand enumeration of zero-reader constants reached seven. A full re-derivation found EIGHTEEN — and one
of the five that survived (`FX_SETTLE_FRAMES`) had a real reader the hand list had missed, in `tools/`.
**Lesson**: sweep, never copy a list; and put `tools/` inside the sweep — a script that drives the game
is a reader like any other.

## 크래시 난 그물은 래퍼의 머리글에서 「실패 0개」로 집계된다 (2026-08-25, 티켓 15)

**실패 개수는 실패 표시가 붙은 줄을 세어서 나온다.** ⇒ **출력을 한 줄도 못 낸 그물은 그런 줄이
없으므로 실패 0으로 집계된다.**

**실제로 나온 머리글**: `통과 2971개 · 실패 0개` — **그런데 래퍼는 종료 코드 1을 냈다.**
2971 = 3043 − 72 이고 **72는 카메라 나무의 검사 수**다. 그 나무가 검사를 하나도 안 냈다.

⚠⚠ **숫자 줄만 훑으면 초록으로 읽힌다.** 진실은 **종료 코드와 그 줄의 실패 표시**가 들고 있다.
⇒ **「실패 0개」를 통과의 근거로 삼지 않는다. 통과의 근거는 종료 코드 0과 스무 장이 다 보고했다는 것이다.**

**원인은 그물이 아니었다.** 그 라운드가 남긴 파일을 찾아 읽었다 — 출력은 **75바이트로 엔진 배너 한 줄**,
오류 출력은 **0바이트**. 엔진이 부팅해서 배너를 찍고 첫 검사에 닿기 전에 죽었다. 파스 오류도 스크립트
오류도 한 글자 없다. **남아 있는 그물 출력 3931개를 전수 조사해 그런 파일이 정확히 하나**임을 확인했다
(0.025%). **특정 나무의 결함이 아니라 어느 프로세스에나 균일하게 걸리는 사고**이고, 114회 중 1회이며
그 뒤 90회 연속 초록이라 재현되지 않는다. **왜 죽었는지는 증거가 없어 단정하지 않는다.**

---

## 이름을 바꾸면 그 이름으로 짜인 검사가 조용히 다른 것을 재기 시작한다 (2026-08-25, 티켓 15)

**소와 까마귀가 적에서 아군으로 옮겨 가면서 네 검사가 껍데기가 됐다.** 넷 다 **뮤테이션으로 실측**했다 —
지키라고 이름 붙인 코드를 지웠는데 초록이었다.

| 껍데기였던 것 | 왜 안 물었나 |
|---|---|
| **광역 상태이상이 형제에게 흐른다** | 쏘는 병사가 개명되며 **까마귀**가 됐고, 까마귀 종 표가 **같은 값(0.5/2.0)으로 출혈을 다시 공급**했다. 지키려던 코드를 통째로 지워도 결과가 같았다 |
| **밀치기가 목표와 예약을 같이 옮긴다** | 픽스처의 적이 첫 서브스텝에 걸어서 **목표가 이미 밀린 자리에 가 있었다.** 넷 중 셋이 안 재졌다 |
| **늑대가 한 덩어리로 뭉친다** | 판에 **적이 하나뿐**이라 어느 점에서 재도 같은 답이 나왔다. **무리 반경을 0으로 죽여도 소수점까지 같은 값**(2.24)으로 통과했다. 셋이 좁혀진 것은 무리가 아니라 「같은 놈에게 걸어가는 세 몸」이었다 |
| **까마귀 공격력** | 어디에도 안 박혀 있어서, 1.5 를 2.5 로 바꿔도 **엉뚱한 HP 총합 줄 하나**만 빨개졌다 |

⚠⚠ **셋은 이름을 바꾼 그 순간에 죽었고 아무도 안 짖었다.** ⇒ **어떤 이름이 다른 것을 가리키게 되면,
그 이름으로 짜인 검사를 전부 다시 읽는다.** 개명은 안전한 변경이 아니다.

⚠ **넷을 되살릴 때 쓴 처방이 각각 다르다**: 쏘는 쪽을 **제 종 상태이상이 없는 곰**으로 · 표적을
**궁수**로 바꿔 적이 안 걷게 · 판에 **멀리 떨어진 적 둘**을 놓고 무리 아닌 종이 갈리는 것을 대조군으로 ·
**옮겨온 숫자를 리터럴로 박기**. ⇒ **공통점은 하나다: 재려는 것 말고 다른 것이 같은 답을 낼 수 없는
판을 만든다.**

---

## 색을 섞는 순서가 뒤집혀 있어도 「값이 화면에 도달했다」는 초록이었다 (2026-08-25, 티켓 15)

**출혈 색을 몸에 60% 섞은 뒤, 편 색 처리가 그 결과를 흰색 쪽으로 45% 되돌리고 있었다.**
실행 검증은 **「출혈한 몸의 색이 안 출혈인 몸과 다르다」로 통과**를 냈다 — 그리고 그것은 사실이었다.

⚠⚠ **다른데 틀린 방향으로 달랐다.** 붉은 채널의 몫을 재 보니 **출혈 0.399 · 안 출혈 0.408** 로
**붉은 기가 오히려 줄어 있었다.** 화면에서는 「빨개진다」가 아니라 「그늘에 들어간다」로 보였다.

⇒ **색을 재는 검사는 「달라졌나」가 아니라 「어느 쪽으로 달라졌나」를 재야 한다.**
순서를 뒤집은 뒤 값은 **출혈 0.541 · 안 출혈 0.408** 이 됐다.

---

## 화면 한가운데만 누르는 검사는 화면 좌표 변환을 하나도 재지 않는다 (2026-08-25)

**사용자가 게임을 돌리고 말했다**: ***"놓는 위치랑 배의 위치가 다른데? 내가 놓는데에 배가 놔지지
않는데"***. 그때 라운드는 **3043개 초록**이었고, 배 놓기를 재는 그물(`net_slots`)만 **159개**였다.

⚠⚠ **누르는 자리를 잡는 도우미가 항상 타일을 화면 한가운데에 갖다 놓고 있었다.** 그리고
**한가운데는 변환이 아무리 망가져도 맞는 단 하나의 화면점**이다 — `screen_to_world_px(640, 360)` 은
정의상 `_ground_centre_px()` 이고, 줌·요·피치·높이 어느 것도 그 점을 못 옮긴다. 그 도우미의 주석은
이 사실을 **장점으로** 적어 두고 있었다("the centre is the one screen point whose ground point is
exact at every zoom, yaw and pitch").

**그 초록 밑에 결함이 셋 있었다. 하나가 아니라 셋이다.** 전부 `Camera3D.unproject_position` 을 기준으로
실측했다. ⚠ **그 측정을 돌린 탐침 `probe_pick.gd` 는 그 뒤 지워졌고, 남은 것은 아래 표다** —
다시 재려면 탐침부터 새로 써야 한다:

| 결함 | 무엇이었나 | 얼마나 틀렸나 |
|---|---|---|
| **카메라가 180° 돌아 있었다** | `_place_camera` 의 `back.z` 가 음수라 카메라가 표적의 -z 쪽에 섰다. +z 를 보는 고도 카메라는 제 +x 가 세계 **-x** 를 가리킨다 | 물 위 **평균 18.6조각** |
| **눕힌 각의 단축률이 코사인이었다** | 피치는 **수평선에서 잰 각**이라 땅의 단축은 **사인**이다. 90°면 안 눕고(sin 90 = 1) 0°면 완전히 눕는다(sin 0 = 0). 코사인은 양끝이 다 거꾸로다 | 세로 **19% 오차**, 화면 아래에서 **2조각** |
| **누른 자리를 평면으로 풀었다** | 땅에 높이가 생겼는데 변환은 y=0 평면 하나로 답했다. `h` 타일 위에 선 것은 `h / tan(pitch)` 만큼 화면 위에 그려진다 | 땅 위 **평균 2.8조각, 최대 4조각** |

⇒ **누르는 검사는 화면 한가운데에서 떨어진 곳을 눌러야 한다.** 그리고 **떨어진 거리 자체에 바닥을
둔다** — 안 그러면 우연히 가운데만 표집한 훑기가 같은 초록을 낸다.

### ⚠⚠ 그리고 하나가 더 있다 — **한 투영을 두 군데에 적어 놓으면 둘 다 초록일 수 있다**

**순수 카메라 함수들(`_visible_ground_px` · `screen_to_world_px` · `_ground_right`)과
`_place_camera` 는 같은 투영을 두 번 적은 것이다.** `net_camera` 는 순수 쪽을 손 산수 리터럴로
54개나 물고 있었는데, **그 리터럴들이 전부 초록인 채로 카메라가 반대쪽에 서 있었다.**

⚠ **한쪽만 재는 검사는 「둘이 어긋났다」를 절대 못 잡는다.** ⇒ **엔진에게 물어서 맞대 본다** —
`Camera3D.unproject_position` 은 그 투영의 제 역함수라 절대 안 어긋난다. 1280×720 `SubViewport`
안에서 섬 하나를 두 줌 두 각도로 704점 훑어 뷰의 정투영과 비교하는 행 하나가 새로 생겼고,
**부호를 되돌리면 2507px 로 빨개진다.**

⚠ **왕복은 결함을 상쇄한다.** 새로 쓴 `net_slots` 의 누르기 행은 뷰의 **정**투영으로 조준하고 셸의
**역**변환으로 읽는데, **정과 역에 같이 있는 결함은 왕복 안에서 지워진다** — 180° 와 코사인을
되돌려도 그 파일은 176개 초록 그대로였다(실측). **그래서 사슬이 두 마디다**: 엔진↔정투영은
`net_camera` 가, 누르기↔정투영은 `net_slots` 가 잡는다. **사슬이라는 사실을 두 파일에 다 적어 뒀다.**

### 리터럴이 결함 그 자체였다

`net_camera` 의 `(-144.00, -170.66)` · `939.89` · `340.11` · `(0, sin40°, -cos40°)` **넷은 틀린 식을
받아 적은 값**이었다. 고치자 18개가 빨개졌다. ⇒ **결함을 고치면 그 옆에서 초록이던 검사는 대조군이
아니라 용의자다**(이 문서 위쪽 항목의 재확인). **다시 적을 때는 코드를 읽지 말고 기하에서 다시
유도한다.**

## 길찾기가 길을 아는 것과 몸이 그 길을 걷는 것은 다르다 (2026-08-25, 티켓 19)

**티켓 19 가 층과 계단을 넣었고 그물 3177 이 전부 초록이었는데, 게임에서는 몸이 층 경계마다 얼어붙어
20 초 동안 0 픽셀 움직였다.** 벽을 사이에 둔 아군과 적이 영구 교착이었고, 제한 시간 패배가 없으므로
**그 판은 영원히 안 끝난다.**

**검사가 뭐라고 적혀 있었나**: *"안 닿으면 그 판은 영원히 안 끝난다"*.
**검사가 실제로 잰 것**: **길찾기 필드가 그 조각까지 뻗는가.**

⚠⚠ **실측에서 필드는 값을 주었고 몸은 안 갔다.** 원인은 걷기의 「도착했으니 선다」 판정만 평면으로
남은 것인데, **필드는 그것을 통과하지 않는다.**

⇒ **움직임을 재려면 실제 보행자를 불러야 한다.** 걷기를 재던 다른 행들은 격자의 한 걸음 함수를
직접 루프로 돌리고 있었고, 게임이 쓰는 보행자는 그 위에 한 겹 더 있다.
**「순수 함수를 재는 것은 누가 그것을 부르는지를 재는 게 아니다」의 재확인이다.**

## 대조군이 교착을 풀어 버리면 교착을 잰 것이 아니다 (2026-08-25, 티켓 19)

위 결함을 빨갛게 만드는 데 **세 판이 걸렸고, 실패한 두 판이 이 항목이다.**

1. **계단을 몸들의 진행선에 두었더니** 길찾기가 얼어붙는 띠를 **우회**시켜서 아무도 안 얼었다 — **초록.**
   ⚠ **띠는 목적지에 있는 것이 아니라 위층 몸의 평면 사거리 안에 있는 모든 낮은 조각이다.**
2. **둘은 띠 안, 하나는 밖에 대조군으로 두었더니** 밖의 하나가 혼자 돌아 올라가 교전했고,
   **적이 움직인 순간 얼어 있던 둘이 띠에서 빠져나와 풀렸다** — **둘이 얼어붙은 채로 초록.**
3. **셋 다 띠 안에 두어야** 판 위의 무엇도 아무것도 못 건드려 빨개졌다.

⚠ 그리고 그 검사 자체가 **「누구든 하나 움직였으면 통과」로 OR 묶여 있었다.** 몸마다 따로 봐야 한다.

⇒ **제3의 몸이 깰 수 있는 교착은 잰 교착이 아니다.**

## 보호막을 짝으로 넣으면 서로를 가려서 하나씩 빼도 안 빨개진다 (2026-08-25, 티켓 19)

상륙이 몸을 벽 위에 올려놓는 결함에 보호막 **둘**을 넣었다(벽을 가로질러 탐색하지 않는다 · 착지 조각과
같은 층만 수집한다). 주석에 **「둘 중 하나만 빼도 구멍이 다시 열린다」**고 적었는데, **실측하니 하나씩
빼서는 아무것도 안 빨개졌다** — 고원 조각에 대해서는 **둘이 서로를 가려 준다.**

⇒ **각 보호막만 답할 수 있는 판을 하나씩 따로 지어야 한다.** 계단 조각은 탐색이 지나가야 하는 조각이라
수집 쪽만 거절할 수 있고, 섬을 가르는 고원은 아래쪽이 낮은 층이라 걷기 쪽만 막는다.

⚠ **뮤테이션이 안 물렸다는 사실 자체가 발견이다** — 안 물리면 「검사가 약하다」가 아니라
**「판이 그 보호막만 답하게 되어 있지 않다」**일 수 있다.

## 사용자의 불평이 초록 검사로 박혀 있었다 (2026-08-25, 티켓 19)

사용자가 ***"처음 시작할떄 가메라 좀더 뒤에서 시작할 수 있게해줘"*** 라고 했다. 원인은 **첫 섬이
줌 천장에 걸려서 여백 상수가 그 섬에 대해 아무 발언권도 없던 것**이었다.

⚠⚠ **그리고 그 사실이 `net_shell` 에 「소형 첫 섬은 서베이가 천장에 걸려 열린다」로 적혀 초록이었다.**
**불평의 내용이 그대로 보장으로 적혀 있었던 셈이다.**

⇒ **검사가 재는 것이 사실인지와 그것이 원하는 것인지는 다른 질문이다.** 리터럴을 확정할 때
「지금 이렇다」를 적으면 「이래야 한다」로 굳는다.

## ⚠ 「크래시 난 그물이 실패 0으로 집계된다」가 재현됐다 (2026-08-25, 티켓 19)

위쪽 항목(티켓 15, 114 회 중 1 회)이 **실제로 다시 났다.** 한 라운드가 **「통과 3115 · 실패 0」인데
종료 코드 1** 이었고, 3227 − 3115 = **112 = `net_draw_leaf` 의 검사 수**로 그 장이 출력을 한 줄도 못
내고 죽은 것이었다. 다시 돌리니 같은 지문으로 스물한 장 전부 보고하며 초록이었다.

⇒ **잡아낸 것은 종료 코드와 「몇 장이 보고했나」 둘뿐이다. 숫자 줄만 보면 초록으로 읽힌다.**

⚠⚠ **그리고 같은 날 두 번째가 났다.** 흔들림을 지우다 `net_fx_view` 의 `run()` 에 **호출만 남고 함수가
사라져 파스 에러**가 났는데, 머리글은 **「통과 3126 · 실패 0 · 21개 그물」**이었다. **그 장은 검사를
하나도 못 냈다.** ⇒ **하루에 두 번이면 「114 회 중 1 회」가 아니다.**

⚠⚠ **빨강을 거르는 필터로는 못 본다** — `x net_` 같은 필터는 **빨강 표시 줄이 애초에 없으므로**
아무것도 안 보여 준다. **종료 코드와 stderr 의 침묵사 검출이 유일한 문이다.**

## The island was rebuilt and the game kept drawing the old one (2026-08-26)

**Measured, not reasoned.** `tools/blender/island_build.py` writes `assets/terrain/island.glb`, and the
game loads that file. The Blender run said `exported glb + json`, the file's timestamp moved, and the
game **drew the previous island anyway** — three screenshots were taken of a mesh that no longer existed
on disk, and nothing anywhere said so.

⚠⚠ **The cause is Godot's import cache.** A `.glb` is imported into `.godot/imported/*.scn`, and a run
started with `-s` does not notice that the source changed. The cached scene was 90 minutes older than
the file it came from.

⇒ **After every Blender rebuild, run the engine once with `--headless --import` before shooting or
playing.** Without it the picture on screen is evidence about a file that is gone.

⚠ **This is the exact shape this document exists for**: every signal said the change had landed. The
tool printed success, the file changed, the game launched, the screenshot saved. Only the picture was
of the wrong thing, and a picture cannot go red.


## A whole net file reported zero and read as one line of red (2026-08-26)

**Measured.** `tests/nets/net_islands.gd` printed `islands 통과 0 [실패]` for at least a day. It was read
as "the island checks are red, and the island changed, so of course they are".

⚠⚠ **The file did not compile.** A `var rows` inside a loop shadowed a `var rows` at the top of the same
function, GDScript refuses to parse a shadowed local, and **the entire file was skipped.** Not one of its
checks ran. Renaming the inner one brought **35 back to green immediately** and the rest are the ordinary
"the island changed" reds.

⇒ **A net reporting 통과 0 is not a very red net. It is a net that did not run.** The two look identical
in the summary line and mean opposite things: one is a measurement, the other is the absence of one.
**Read the runner's per-file line before believing a zero.**

## A colour was written three times and landed wrong twice (2026-08-26)

**Measured while building the first buildings.** Their palette came out pale pink, then near-black, then
right. Three separate causes, and each one alone looked like the whole story:

1. **The export carried two colour attributes** (`COLOR_0` and `COLOR_1`) and Godot read the empty one —
   every building came in pure white. ⇒ The buildings are painted with materials now, not vertex colours;
   the ground still uses vertex colours, and that difference is deliberate and written down where it lives.
2. **glTF stores base colour in LINEAR** and a colour is picked in sRGB. Written straight through, every
   tone lands several shades too light.
3. ⚠⚠ **Blender keeps materials between runs of a script.** `flat_mat` reused one by name, so the FIRST
   run's colours survived every rebuild — the fix for (2) appeared to do nothing, which sent the next
   attempt off to convert twice and produce black. **The build script clears materials now.**

⇒ **When an edit appears to do nothing, suspect the cache before suspecting the maths.** Two of the three
rounds here were spent correcting arithmetic that was already right.

## The keep's shadow node exists, is visible, and does not draw (2026-08-26 — CLOSED, the node is gone)

⚠⚠ **Do not go looking for this node.** The whole drawn-shadow approach — a soft dark quad laid on the
ground under every standing thing — was **deleted later the same day**, and the island now has exactly one
kind of shadow: the real one the single sun casts. **The bug below was never solved; it was removed.**
The entry is kept for its last paragraph, which is about evidence and outlives the node it was found on.

**Measured, not guessed.** Every standing thing on the island gets a drawn shadow — a soft dark quad on
the ground. The trees and rocks show theirs. **The keep does not, and the node is there:** a print at the
moment it is added reports position `(7.68, 1.322, 5.46)`, `visible = true`, scale `1.9`. The plateau's
surface is at `1.31`, so it sits a centimetre above it, exactly as the props' do above theirs.

⚠ **What was tried and did not change it**: widening it, darkening it, using the shared material instead
of a duplicated one, capping how far it slides from its caster, and lifting it five times further off the
ground. **All five produced a pixel-identical frame.**

⇒ **It is not a size, a colour, a material or a depth-bias problem.** Something else is stopping that one
node from being drawn, and this entry exists so the next attempt does not start by re-running these five.

⚠⚠ **The lesson that generalises**: a node reporting `visible = true` at the right position with the
right scale is **not** evidence that it is on screen. It is evidence that the code that creates it ran.

## The keep looks right in Blender and wrong in the game (2026-08-26 — OPEN)

**Measured both ends.** The same mesh, rendered inside Blender by the script that builds it, is cleanly
flat-shaded: every face one tone, every edge hard. **In the game its white walls and its stone base come
out in wedges of bright and dark that meet at the triangle seams.**

⚠ **The mesh is not the problem, and this is now established rather than assumed.** The exported file
splits vertices per face (a two-box `wall` exports 48 vertices for 12 quads — the count flat shading
requires), carries `NORMAL` and `POSITION` and no colour attribute, and the Blender render of it is
correct.

⚠ **Four fixes were tried on the game side and every one produced a pixel-identical frame**:
- `bm.normal_update()` before `to_mesh`, and `Mesh.shade_flat()` on top of the old per-polygon flag
- sinking every stacked part so no two faces share a plane (coplanar faces z-fight, which looks like
  exactly this) — kept, because it is correct regardless
- not calling `_use_vertex_colours` on the buildings, which was switching on
  `vertex_color_use_as_albedo` for a mesh with no vertex colours
- reimporting the asset each time, so none of the above was tested against a stale cache

⇒ **Still open.** Written down so the next attempt starts after these four rather than at them.

⚠⚠ **The lesson**: "it renders wrong" is not one question. **Where it renders wrong is the first
measurement**, and taking it — the same mesh in the DCC tool and in the engine — cut the search space in
half in one step, after two rounds of guessing had cut it by nothing.

## A dial that could not reach the screen (2026-08-26)

**Measured.** The sea's ripple was given a strength dial, and four candidate values were rendered side by
side to pick from. **All four came out identically flat.** The dial was not weak; it was multiplied by
zero.

⚠⚠ **The cause was a fade written as "far from the camera".** The ripple faded out beyond a distance
from the camera, to stop fine detail aliasing when zoomed out. **This game's camera is ORTHOGONAL and
sits far back**, so every point on the sea was already past the fade. On an orthogonal projection,
distance-from-camera is not a stand-in for "small on screen" — a near tile and a far tile are drawn at
exactly the same size.

⇒ **Before comparing candidates, prove the dial moves the picture at all.** Four renders were spent
comparing four numbers that could not differ.

## The approved picture was of numbers the game did not have (2026-08-26)

**Measured.** The tool that renders water candidates overrides the shader's uniforms so each candidate
can differ. It also silently overrode the ripple strength to a value the game did not use. **The user
approved a look from a sheet the game could not reproduce**, and would have found the difference on the
next launch.

⇒ **A comparison tool must start every candidate from the SHIPPED values** and change only what the
candidate names. Anything it overrides on the way past is a lie about what was chosen.

## A shadow the size of its caster is not a shadow (2026-08-26)

**Measured twice, independently, an hour apart** — once on the buildings and once on the props. A drawn
ground shadow was sized from the caster's own footprint. **Almost all of it lands underneath the caster**,
so what shows is a smudge peeping out at the base, and on the small props nothing showed at all.

⚠ It also has to get DARKER as it gets wider: the same opacity spread over thirty times the area is
thirty times fainter everywhere. Widening the keep's shadow alone changed nothing visible.

⇒ **Size and strength are one decision, not two.**

## 2026-08-26 — **측정은 맞았고 원인 추정이 틀렸다: 「이 렌더러는 작은 물체의 그림자를 못 만든다」**

**섬 위의 집도 나무도 바위도 땅에 그림자를 한 개도 안 던졌다.** 밀어내는 값(`shadow_normal_bias`)을
**다섯 번 재고** 문서에 이렇게 박혔다 — 「**이 렌더러의 그림자맵은 이 규모에서 반 미터짜리 물체를
해상할 수 없다**」. 그리고 그 결론이 「**그러니 발밑에 그림자를 그려 넣는다**」로 이어져, 반투명
원판과 그것을 조절하는 숫자 다섯이 태어났다.

⚠⚠ **다섯 번의 측정은 전부 정확했다. 틀린 것은 그 다음 한 줄이다.**

**진짜 원인**: **직교 카메라에서는 `directional_shadow_max_distance` 가 무시되고 카메라의 `far` 가
쓰인다** (엔진의 알려진 문제, godot issue #58332). 이 게임의 카메라 `far` 는 **기본값 4000** 이었고,
그림자맵 한 장이 4000 조각에 펼쳐지면 **텍셀 하나가 반 조각** — **나무 한 그루보다 넓다.**

⇒ **`far` 를 140 으로 바꾸자 모든 물체가 그림자를 던졌다.** 밀어내는 값 1.8 은 손대지 않았다.

**여기서 배울 것 둘**

- ⚠⚠ **「A 를 다섯 번 바꿔도 안 되더라」는 「A 가 원인이 아니다」이지 「B 는 불가능하다」가 아니다.**
  문서에 박힌 문장은 뒤쪽이었고, 그것이 한 달치 우회로를 만들었다
- ⚠ **그 우회로가 다시 증상을 만들었다.** 그려 넣은 원판은 **방향이 없고**, 게다가 **해 쪽으로**
  밀려 있었다. 진짜 그림자가 살아나자 물체마다 방향이 다른 그림자가 둘이 됐고, 사용자가
  ***"해 기준으로 그림자가 있어야 하는데 이게 좀 안 그런거 같음"*** 이라고 했다

## 2026-08-26 — **재보지도 않고 원인이라고 말한 것: 「창을 키우면 720 을 늘려 그린다」**

사용자가 ***"확대할때 깨지는건 어쩔슈없나?"*** 라고 물었을 때, 원인을 둘로 답했다. 하나는 맞았고
(안티에일리어싱이 아예 꺼져 있었다) **하나는 재보지 않고 말한 것이었다** — 「화면 늘리기 설정이
1280x720 으로 그린 뒤 창 크기로 늘린다」.

**2560x1440 으로 실제로 띄워 재보니 한 장의 크기가 그대로 2560x1440 이었다.** 그 설정은 **글자와
단추만** 늘리고 **3D 는 창 해상도 그대로 그린다.** 고칠 것이 없었다.

⇒ **재는 데 걸린 시간은 2 분이었다.** 그 2 분을 안 쓴 대가로, 사용자는 없는 문제를 고칠지 말지
결정하는 질문을 받았다.
