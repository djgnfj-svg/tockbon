Type: research
Status: open

# 보는 게임에도 히트감이 옮겨오나

## Question

**Impact feel's three decisive features were all measured on games where the player swings. This is an
autobattler. Does any of it carry over, and is there anything to check?**

## Where it came from

Row 78, the user's own words: ***"게임적으로 확인해야하는 것들 기획들도 있어야하지 않을까? … 연출 부터
히트표현 등등 이런걸 검사하는게 필요할까"***.

## What one round of reading already found, so it is not re-found

- The named crafts are **game feel** (Swink: real-time control · simulated space · **polish, which by
  definition does not change the simulation**), **juice** (Jonasson & Purho, GDC Europe 2012), and for hits
  specifically **impact feel** — a study ranking action games by Steam sentiment that pulled out **19
  features**, of which **three are called decisive: hit stop, sound matching the visual, camera response**
- ⚠ **The references disagree on purpose.** Vlambeer's *The Art of Screenshake* stacks 30 effects; Game
  Developer ran *「Indies, resist the urge to juice it or lose it」* against exactly that
- ⚠⚠ **Unresolved and important: hit stop sells a reaction to INPUT, and here the player does not swing.**
  **No source found says whether the three carry over to a game you watch**

## What this repo has already measured, which any answer must survive

- **A flash stops being an event and becomes a state as the numbers grow.** At the value that shipped,
  0.18 ÷ 1.2 = **15%**, so the ceiling is **six or seven attackers**. Past it the flash never turns off.
  **This class of defect gets worse as the army gets bigger**
- **A global freeze becomes a permanent freeze once there are many bodies.** ⚠ Sakurai's stated reason for
  shortening hitstop is **fairness, not readability** — a third player moves in free while both are frozen —
  and **an autobattler has no controlling third party, so his reason does not carry over.** The real reason
  here is the freeze arithmetic above
- **If nothing on screen decreases monotonically, there is no way to tell hitting from swinging at air**
- ***"Too much here buries everything else."*** A large effect on the event that happens several times a
  second erases the other eleven

## What to find

1. Whether anyone has studied or shipped impact feel in **games the player watches** — autobattlers, idle
   games, Underlords/TFT-likes, replay and spectator modes
2. If nothing exists, **say so plainly** rather than transferring the swing-game result. ***Code that
   pretends to work is worse than code that doesn't***, and a citation that pretends to cover this case is
   the same failure

⚠ **Capture the findings as a file and link it from this ticket.**
