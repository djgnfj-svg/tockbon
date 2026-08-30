# 04-reach — only where THIS body can get to, faded by how far

**What it buys** — it answers **the question the player actually has**, and the answer is the game's
own `can_step`, so what lights up is exactly what a step is allowed to do. The edge of the marks is
the edge of the possible, and the unreachable plateau is dark by simply not being drawn.

**What it costs** — it needs **a selected body and a move budget**, and neither exists in the code yet
(there is no command at all). It marks every 조각 rather than every 칸, so it is four times as many
marks as the shipped 판.

⚠ **What it CANNOT do** — **say anything while nothing is selected.** A resting board is bare ground.
And the fade with distance is nearly invisible at the opening zoom.
