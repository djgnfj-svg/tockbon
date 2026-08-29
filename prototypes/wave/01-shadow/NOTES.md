# 01-shadow — the island's shadow, and nothing else

**Where it comes from:** the sun, blocked by the island. The water keeps the flat colour it ships with;
the only thing that ever changes it is a solid object standing in the light.

**What it buys** — **it is the only true statement on the sheet.** No pattern, no noise, no wave: the
island stops being a sticker laid on the water. It costs one line of shader and it survives every zoom,
because a shadow is the same shape at any distance.

**What it costs** — the sea has to become a lit surface. That is the whole of it: `unshaded` comes off
and a light function goes on, and the flat sea and the missing highlight are both kept deliberately.

**What it CANNOT do** — ⚠⚠ **almost nothing shows, and it was measured.** The island stands 0.85 tiles
out of the water and the sun is 52 degrees up, so the shadow it throws on the sea is **about two thirds
of a tile** — and the white shoreline is already a third of a tile wide, sitting exactly where the
shadow lands. **3,510 pixels of the opening view change and they are nearly all the outer white going
grey**, not blue water going dark. ⚠ To make this read, the sun has to come down — and the sun's pitch
lights the whole island, so that is a decision about the island, not about the sea.
