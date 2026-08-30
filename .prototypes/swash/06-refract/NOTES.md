# 06-refract — It breaks hard on the points and goes quiet in the bays

Pictures: `../out/06-refract_*.png`

**Buys** — the only liveliness in these nine that is computed FROM the coastline. A wave slows in
shallow water, so the part of a crest reaching a headland first slows first and the rest swings round
to follow; energy spread across open water arrives concentrated on the point. Take the field's gradient
a second time and that is exactly the number you have.

**Costs** — four more samples on a wide stencil, and the wide stencil is not optional.

**Cannot** — ⚠⚠ **be measured tightly.** It is a difference of differences of a texture read, so
sampled at the gradient's own step it reports the bake's texels rather than the island's shape.
`curve_step` is five times `grad_step` for that reason, which means **it cannot see a bend smaller than
about a third of a tile** — and the island's outline bends by whole blocks, so this is a floor it is
currently living just above.
