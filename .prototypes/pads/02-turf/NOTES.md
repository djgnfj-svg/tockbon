# 02-turf — the ground is drawn differently, and nothing is added on top

**What it buys** — **no overlay exists.** The walkable surface simply grows a patchy turf, so nothing
can fight the art, nothing needs a key, and the mark cannot be at the wrong height or the wrong angle.
This is Bad North's own answer, in the developer's words.

**What it costs** — it is a **bake**: every change to it means re-baking the island. And it spends the
island's clean flat colour — the whole surface becomes busy, which is the opposite of what the flat
sea decision bought two days ago.

⚠ **What it CANNOT do** — **mark one 칸.** There is no unit for the cursor to pick out and no way to
answer 「이 몸이 어디까지 가나」. On a board where nearly all the land is walkable it draws a texture
and says nothing.
