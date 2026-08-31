# The published sway formulas, and what a `next_pass` outline does to them

⚠⚠ **READ `2026-08-29-foliage-mesh-vs-card-and-sway.md` FIRST.** That file answers *what Bad North does*
and *mesh or card*; this one answers *what is the actual arithmetic* and *what happens to our outline*.
**Two things here were not in that file**: the shipped formulas, verbatim, and the answer to whether an
inverted-hull `next_pass` shell follows a vertex displacement. **It does not.**

---

## 1. The canonical split — "main bending" and "detail bending"

**Tiago Sousa (Crytek), *GPU Gems 3* ch. 16**, describing CryENGINE 2 / Crysis. Main bending moves the
whole plant along the wind weighted by height; detail bending flutters the leaves.
[source](https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-16-vegetation-procedural-animation-and-shading-crysis) — **read**

### ⚠ The height weight is NOT linear and NOT a sine

```
float fBF = vPos.z * fBendScale;
fBF += 1.0;
fBF *= fBF;
fBF = fBF * fBF - fBF;
vNewPos.xy += vWind.xy * fBF;
vPos.xyz = normalize(vNewPos.xyz) * fLength;
```

**The weight is `(1 + h·s)⁴ − (1 + h·s)²`** — zero at `h = 0`, so the base is pinned, and quartic toward
the tip. ⚠⚠ **The last line is the part everybody drops**: renormalising back to the original distance
from the mesh origin is what makes the tip **arc** rather than shear sideways. **It only works if the
mesh origin sits at the base of the prop** — which is how `blend/props.blend` is built, so this is
available to us if it is ever wanted.

### ⚠⚠ And the wave is a smoothed triangle, not a sine

```
float4 SmoothCurve(float4 x)        { return x * x * (3.0 - 2.0 * x); }
float4 TriangleWave(float4 x)       { return abs(frac(x + 0.5) * 2.0 - 1.0); }
float4 SmoothTriangleWave(float4 x) { return SmoothCurve(TriangleWave(x)); }
```

**Unity's shipped terrain grass does the same job differently** — four summed waves and `sin⁴`, from
`TerrainEngine.cginc`
([source](https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/TerrainEngine.cginc) — **read**):

```
waves  = vertex.x * _waveXSize;      // _waveXSize = (0.012, 0.02, 0.06, 0.024) * size
waves += vertex.z * _waveZSize;      // _waveZSize = (0.006, 0.02, 0.02, 0.05)  * size
waves += _WaveAndDistance.x * waveSpeed;      // waveSpeed = (0.3, 0.5, 0.4, 1.2) * 4
waves = frac(waves);
FastSinCos(waves, s, c);
s = s * s;  s = s * s;               // sin^4 -- sharpens the crest
```

⇒ **Both sharpen the crest and flatten the trough**, so a plant rests, gusts, and rests. **A plain sine
is a metronome, and the defect has a name in this repo already**: the 08-29 note carries a reply to Bad
North's developer, 「your bush wiggling is too regular… wind is more wave like」.

⚠ **Unity's bend weight is painted into vertex colour alpha** (1 at the tip, 0 at the base), not derived
from Y, and the displacement is **XZ only**.

---

## 2. ⚠⚠ **The `next_pass` outline does NOT follow a vertex displacement**

**This is the finding that decides whether we can ever bend rather than lean.**

Godot's `Material` docs: next_pass *"renders the object again using a different material"* — **the
object again**, i.e. the original undisplaced mesh through the second material's own vertex stage.
The engine forum states it outright: **"The vertex displacement does not carry over to the next pass
material"**, with the fix being to put everything in one `ShaderMaterial`.
([forum](https://forum.godotengine.org/t/applying-standardmaterial3d-after-vertex-displacement-shader/128383) ·
[docs](https://docs.godotengine.org/en/stable/classes/class_material.html) — **both read**)

**What that costs us concretely:**

- A `StandardMaterial3D` shell using `grow` **can never follow the wind.** The ink stays on the rest
  pose while the mesh sways out from under it.
- The shell has to become a `ShaderMaterial` repeating the **identical** displacement first and only
  then offsetting along the normal — same uniforms, same `TIME`, same phase — or the two desync.
- ⚠ Second gotcha, same docs page: **next_pass materials are not necessarily drawn immediately after
  the source**; order depends on material properties, `render_priority` and distance.

**At 25–55 screen px a one-pixel mismatch is 2–4% of the prop's width**, and under an orthographic
camera there is no perspective jitter to hide it.

⇒ **This is why the game leans the node instead of bending the mesh.** A `Basis` per prop per frame
moves the shell for free, because the shell is a second pass over a node that has already moved.

---

## 3. Rotating the whole object is a documented tier, not a shortcut

- **SpeedTree's own wind ladder is Full → Branch → Global → None**, and **"Global motion"** is described
  as the **"simplest rocking of the entire tree model."** Their performance page advises reaching Global
  or None early. ⚠ **Not verified** — `docs.speedtree.com` refused the fetch; this is the search index's
  text of [wind_overview](https://docs.speedtree.com/doku.php?id=wind_overview).
- **Unreal ships `InteractiveFoliageActor`** — a static mesh that takes touch impulses into a damped
  spring (`FoliageDamping`, `FoliageStiffness`, `FoliageStiffnessQuadratic`, `FoliageTouchImpulseScale`)
  and outputs a rotation axis and angle, described as animating the mesh **"with minimal performance
  impact."** ⚠ **Not verified** — docs 403'd.
- **The middle rung** is *GPU Gems 3* ch. 6 (Renaldas Zioma, EA/DICE): rotate rigid branch segments about
  joints rather than bend vertices. Measured on 2007 hardware: **256 instances / 20,480 branches =
  9.68 ms**. Unreal's **Pivot Painter** is the productised form.
  [source](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-6-gpu-generated-procedural-wind-animations-trees) — **read**

⚠ **Two of the three documented traps do not apply to a leaning node**, and both bite a displacing
shader (they are listed in the 08-29 note): the **stale AABB** — a bush displaced outside its bounds pops
out near the screen edge — and the **shadow that does not sway**, because the depth pass often runs a
stripped vertex shader. **A node that moves carries its own bounds and its own shadow.**

---

## 4. Making foliage bend AWAY from a body walking through it

**Four tiers, cheapest first.**

| | What it is | What it costs | ⚠ |
|---|---|---|---|
| **a. Interactor array** | positions + radii as uniforms; the vertex shader pushes radially away. hexaquo's Godot 4 line: `float bend = max(radius - dist, 0.0) / radius;` | one loop of N in `vertex()` | *"does not scale well, and is only limited to just a few characters"* ([Alan Zucconi](https://www.alanzucconi.com/2018/07/28/shader-showcase-saturday-3/) — **read**) |
| **b. Trample render target** | an orthographic camera above the player renders into a small top-down texture the foliage shader samples by world position | one extra RT + camera pass, one fetch in `vertex()` | **the only tier that gives PERSISTENCE** — grass stays flattened and unbends over time. ⚠ needs a depth pass too when props sit at different heights, **which ours do** — two storeys and a stair |
| **c. Per-object damped spring** | Unreal's `InteractiveFoliageActor` | one rotation per prop, CPU | fits props, not grass fields. **This is the tier our leaning node is already one step away from** |
| **d. Fluid wind sim** | God of War's wind motors and receivers | a GPU sim | not in scale |

⚠ **Bad North's wind is environmental, not character-driven** — the 08-29 note establishes that from the
developer's own tweets. **Nobody has asked for trample here yet.**

---

## 5. What could not be found

- ⚠⚠ **No stylised shipped game with a published statement that it keeps foliage static ON PURPOSE**, for
  art direction or readability. Townscaper, Islanders and Bad North were all searched specifically and
  none has a developer statement of that kind. **Do not cite them as an argument for stillness.**
- The only verified opposite case is small: the *Shroom* devlog on itch.io — **"Grass wind was removed
  because of performance."**
  ([source](https://goury.itch.io/shroom/devlog/224371/another-iteration-on-textures-and-grass) — **read**)
- **Godot ships nothing** for foliage wind. Its official answer is the
  [Making trees](https://docs.godotengine.org/en/stable/tutorials/shaders/making_trees.html) shader
  tutorial (**read**), which is worth two lines verbatim: use **world coordinates** *"so the tree can be
  duplicated, moved, etc."*, and give **every axis a different near-1.0 multiplier** *"so axes don't
  appear in sync."* `NODE_POSITION_WORLD` is the idiomatic per-clone phase seed.
- Horizon Zero Dawn, God of War and Ghost of Tsushima are **GDC Vault, paywalled** — summaries only, not
  read.
