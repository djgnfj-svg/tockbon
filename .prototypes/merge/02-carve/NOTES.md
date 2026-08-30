# 02-carve — the gutter stops being geometry and becomes a number

**What it buys** — **the mesh is the dumbest possible thing**: one flat quad per 조각. The gutter is a
uniform, so it can be anything between zero and anything else without a vertex moving, and the same
mesh could hold a gutter the bake never considered.

**What it costs** — **overdraw**: the whole 조각 is rasterised and most of it is thrown away. And every
edge on screen is a shader cut, so this is the only version whose edge quality lives in the fragment
stage rather than in the triangles.

⚠ **What it CANNOT do** — **hold a shape the formula cannot say.** It draws a rounded rectangle with
four insets. The moment a 판 wants to follow a curving coast — which is where this island is heading —
the shape has to be expressed as another term in the shader rather than cut in Blender.
