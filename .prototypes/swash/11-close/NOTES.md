# 11-close — 10 with the two measurements, and nothing else

Pictures: `../out/island/11-close_*.png`

**The baseline for this round.** 12..15 each add one term to this, so a difference between two of them
is that term and nothing else.

**Two corrections, both the user's own** (2026-08-29, on the island lab):

- 「거품하고 해안 라인 흰색이 너무 거리가 멀어 저렇게 멀 필요없음」 — *"the foam and the shoreline are
  too far apart; they do not need to be that far"* ⇒ the foam is born 0.40 tiles out, not 1.10
- 「흰색선은 더 얇아도 무방할듯」 — *"the white line could be thinner"* ⇒ 0.045 tiles at rest, not 0.075

**Buys** — the gap the user objected to, closed, and a hairline instead of a stroke. Everything 10 was
praised for is untouched.

**Costs** — nothing. It is 10 with two numbers moved.

**Cannot** — ⚠⚠ **go thinner than this.** The field is 16 texels per tile, so a texel is 0.0625 and the
resting line is already under one. It survives on linear filtering; **below about 0.035 the coast comes
out dashed on the diagonals**, which is the exact failure that pushed the bake from 4 texels to 16.
