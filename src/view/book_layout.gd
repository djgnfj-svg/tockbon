extends RefCounted
## Window-axis coordinates — **a book opened to two pages.** The page rectangles come from this one place.
##
## ```
##  ┌─ title band ───────────────────────┐
##  │ ┌──────────┬┬──────────┐           │
##  │ │  left    ││  right   │           │
##  │ │ palette  ││ circle   │           │
##  │ └──────────┴┴──────────┘           │
##  └────────fold────────────────────────┘
## ```
##
## **Why a separate file — to keep the magic circle from knowing about pages.**
##  The moment `circle_layout` references this file, **the circle axis hangs off the window axis.** The day the
##  window shape changes, the magic circle's code opens with it. It is **exactly the same disease one level up**
##  as what was fixed in stage 3 when `_draw_ring` was calling `frame()["center"]`. => Splitting the file makes
##  that coupling **show up as a reference** (`net_circle` measures it as text).
##
## **Why two pages — not a metaphor but the direction of growth.**
##  The palette grows **vertically** as the tables grow (N circles, M runes, K glyphs), while the magic circle grows
##  **horizontally and in diameter** as layers and rune slots grow. Stack them on one axis and one growing pushes
##  the other — put the palette in a band below and the day glyphs go to six, the magic circle gets pushed.
##  => Side by side, each grows inside its own page.
##
## **The fold is not decoration but a picture of the boundary.** The visible boundary and the hit-test boundary
##  (of stage 4b) must be the same — differ and it becomes "I clicked this side and that side responded",
##  and **no error is raised.**
##  => Drawing and clicking both read the single `pages()` below.
##
## **Draw inside the transform and take clicks outside it and they diverge silently** (risk 22).
##  The window seats the magic circle on its page with `draw_set_transform(pages()["right"].position)`, so
##  **the click must subtract that same `position`.** This repo has the same measurement —
##  when `stage_input._to_world` fails to undo the canvas transform, "aim goes to the wrong cell while shaking".
##  **The same disease and the same answer: the value to subtract comes from this one place.**

const Fx := preload("res://src/view/fx_tuning.gd")


## The two pages and the fold, in the window's inner coordinate system.
##
## **Page size is derived from window size rather than pinned.** Pin it and the day the window grows, the pages
##  either run outside the window or leave an empty band inside, and both are screen problems, so **no error is raised.**
## It starts **below** the title band — which is why the magic circle colliding with the title becomes
##  **structurally impossible** (risk 24's 6.4px of margin disappears here. In stage 3 the whole window was
##  the magic circle's seat).
static func pages(window_size: Vector2) -> Dictionary:
	var m := Fx.BOOK_MARGIN_PX
	var top := Fx.WINDOW_TITLE_BAND_PX
	var fold_w := Fx.BOOK_FOLD_PX
	var w := maxf(window_size.x - m * 2.0, 0.0)
	var h := maxf(window_size.y - top - m, 0.0)
	# The two pages are **the same width.** Make them differ and "which one is the main body" appears,
	#  and it reads as "body text + a sidebar" rather than an opened book.
	var page_w := maxf((w - fold_w) * 0.5, 0.0)
	return {
		"left": Rect2(m, top, page_w, h),
		"fold": Rect2(m + page_w, top, fold_w, h),
		"right": Rect2(m + page_w + fold_w, top, page_w, h),
	}


## **Which page is what — this is the single source.** The window and the nets call only these two.
##
## **Left and right have already been flipped once** (spec's first proposal was "palette on the left, magic circle
##  on the right" and the user's acceptance reversed it). It may flip again, so **do not pin the keys all over** —
##  pin them and the day it flips, the window and the nets flip separately and it stays **green with only one side moved.**
## Flipping must be **swapping the two lines below.**
##
## **The only grounds for left and right is one user judgment**
##  ("put the magic circle on the left, and on the right let me pick circles, runes and glyphs" — decided by the user).
##
## **It used to say here "the magic circle is on the outside so it doesn't push the palette", and that was false.
##  It is left in place.**
##  `pages()` above splits the window **always exactly in half** (it says so itself: "the two pages are the same width")
##  and `circle_layout.circle_area()` only pads inside that box => **wherever the magic circle sits, it can only
##  narrow within its own half and can never grow outward.** That structure **did not exist.**
##
## That is a **future** rationale — it becomes true the day `pages()` can do an **asymmetric split.**
##  **What binds is the split method, not the kind of circle.** Even when a circle with several rune slots arrives,
##   it still cannot grow while `pages()` has its current shape.
##
## **The lesson binds outside this file too**: when moving a line from a plan doc into a code comment,
##  **check once more in the code whether that sentence is verified.** To call it "structural grounds",
##  that structure must actually exist. CLAUDE.md's "do not summarize a doc into a comment, point at it" is this seat.
static func circle_page(window_size: Vector2) -> Rect2:
	return pages(window_size)["left"]


static func palette_page(window_size: Vector2) -> Rect2:
	return pages(window_size)["right"]
