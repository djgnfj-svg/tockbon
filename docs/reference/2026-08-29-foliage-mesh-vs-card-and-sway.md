# How does Bad North build its greenery, and how do stylised low-poly games do foliage and sway?

**Answer in one line.** **Bad North's grass is quads and its forests are billboarding planes, both by the
developer's own account** — scattered by a density-and-push-apart algorithm running on the navmesh — and
**its foliage does move**: a wind vector field lives in a 3D texture that rocks and terrain deflect, and
*"the foliage wiggles in relation to how exposed it is to the wind."* It gets away with flat cards because
it has **no real-time shadows and no normal-based outline on the foliage**: the light is a baked voxel AO
3D texture and the trees' outline is an offset darker copy.

⚠ **Two source classes below, never mixed.** Talk quotes are **YouTube auto-captions** pulled with
`yt-dlp` — timestamps exact, wording approximate (the captions write `ddy` as "dvy", `C#` as "c-sharp",
"outlines" as "our clients"). Tweet quotes are **verbatim from @OskSta**, read directly on x.com.

⚠⚠ **This file corrects an earlier draft of itself.** That draft said "nothing in Bad North sways." **That
was wrong** — it was drawn only from the talk, in which the word wind never appears. The tweets settle it.

---

## 0. Bad North — what the developers actually said

**Two primary sources**, and both are the developer:
[Konsoll 2018, Oskar Stålberg, *Developing The Bad North Look*](https://www.youtube.com/watch?v=6JcFbivo8dQ)
· his own Twitter/X account, [@OskSta](https://x.com/OskSta).

⚠ **The 2018 "All my Bad North tech tweets in one collection" Moment is dead** — X converted Moments to
Events and the collected tweets are gone; the page now reads "Nothing to see here — yet." The tweets below
were found by dated search of his timeline, not from that collection.

### Grass: **quads**, scattered on the navmesh, and it carries gameplay

> **@OskSta, Nov 14 2018** — *"I do strive to keep my wireframes as pretty as the rest of my game. Note
> though that the **grass quads** seem to be facing the wrong way, and thus do not show up in the
> wireframe."*
> **@OskSta, Oct 30 2018** — *"The **grass** probably have its **triangles wound the wrong way**, which
> makes them not show up in wire frame."*

**That settles it: grass is drawn geometry — single-sided quads — not a terrain colour.** The green
*surface* is something else (below); these are objects standing on it.

**And they are duplicated into the water reflection:**
> **@OskSta, Mar 26 2018** — *"I should probably **stop mirroring the grass** though, as it creates
> **unnecessary overdraw** and is almost never visible."*

**Grass marks where you can walk:**
> **@OskSta, Nov 16 2018** — *"Like many of you have suggested, I finally **added grass to slopes to make
> navigability easier to read** (especially on overcast levels where the lighting ain't helping much). I'm
> happy enough with the result to **ditch the previous white dotted lines**."*
> **Talk, 15:43–16:15** — *"These little slopes in the grass here are **way patchier than the rest of the
> grass**… the plains are calm, but these more patchy areas **mark out the places where you can navigate
> between the different levels**… being a bit more consistent in how we use **grass and not grass to
> communicate navigability**."*
> **@OskSta, May 12 2018** — *"I used to **have grass on the stairs**. I thought it looked a bit messy. I
> do see what you're saying though. They are visible when the sun is shining, but not when there's an
> overcast."*

⚠ **The white dotted lines that grass replaced were a HUD-ish overlay.** Bad North solved a readability
problem with environment art rather than with UI, on purpose:
> **@OskSta, May 12 2018** — *"A particular gripe of mine is games that are too quick to add **UI
> silhouettes** to obscured units… It breaks the immersion and could often be solved with **clever
> environment art and camera controls** instead."*

### Trees / forests: **billboarding planes, billboarded in the vertex shader**

> **Talk, 19:10–19:43** — *"A lot of the art in Bad North tries to blur the line between 2D and 3D… Also
> for the **forests** and also for the units in the game we use… they of course **billboard**… they are
> **just billboarding planes**, and we do that billboarding **in the vertex shader** instead of doing it in
> C# because that would be quite slow."*

**Confirmed later, looking back at it:**
> **@OskSta, Dec 3 2019** (on a newer project) — *"…And with a free camera **I can't billboard them like in
> Bad North**."*
> **@OskSta, Oct 23 2019** — *"I'm afraid its like with VR: **our billboards only really work from one
> angle**."*

⚠ **Bad North's fixed, orbiting camera is what makes the billboard legal.** He says so by naming the free
camera as what takes it away.

### What lights a flat plane: **voxel-space normals**

> **@OskSta, Jan 4 2021** — *"But **voxel space normals** are good to. I use them for some things in
> Townscaper and **in Bad North. Lighting of foliage for example.** Or mix em with the normal normals for
> slightly softer lighting."*
> **Talk, 13:03** — *"…the **trees add a little bit of voxel coverage** to them. This is used for lighting
> as well."*
> **Talk, 15:16–15:29** — *"…the trees use these kind of **normals from the voxel space**, so when the
> light comes from the side they **light up the trees as a blob** instead of lighting up each individual
> tree."*

**This is the piece that makes a card work.** A quad has one normal and cannot be lit; the normal is taken
from the voxel field instead, and a forest reads as one mass.

### **There are no real-time shadows** — AO baked into a 3D texture

> **@OskSta, Aug 30 2018** — *"The shaders are indeed **entirely custom, including the lighting system**.
> It's a **voxels based AO system stored in a 3d texture sampled in the vertex shader**, with some crispy
> outlines on top."*
> **Talk, 20:20–21:25** — *"…a sort of **ray marcher**, but a very very simplified one… **not ray marching
> in straight lines but doing it in a tree structure**, so if it stops early it doesn't have to keep
> branching out. It doesn't produce perfect lines, but it's perfectly good enough for something as soft as
> the shadows we use in Bad North… **baked down into an AO texture — a 3D texture**."*
> **Talk, 21:41–22:11** — cheap enough that *"the units walking around, I can just sample the 3D texture to
> get their lighting; the **particle systems** can sample this."*
> **Talk, 22:22–22:26** — the goal is depth *"without taking a lot of attention from like **sharp shadows
> and weird shapes**."*

⚠⚠ **Sharp shadows are named as the thing being avoided.** Bad North does not have the sun-and-real-shadows
setup this project has.

### The outline: **inverted hull for the island, an offset copy for the trees**

> **Talk, 17:48–18:13** — *"For the island itself I use this basic, very old-school technique where I just
> **draw the mesh twice, once inside out and once right side out** — one pixel pushed out the first time
> and one pixel pushed in the second time. When you push it out as far as this it looks very artifacting —
> you get these **weird spiky triangles at the outer edges** — but at one pixel it looks good."*
> **@OskSta, Sep 26 2018** — *"The outline here is a mix of the **classic extruded inside-out mesh** and a
> distance field texture that separates the roof from the wall."* ⚠ **Posted a month after launch and about
> a roof and a wall, i.e. almost certainly a Bad North house — but he does not name the game.**

**The trees get something else entirely:**
> **Talk, 16:43–17:18** — *"One thing I do for the trees… you see that each tree has a little bit of a
> **shadow behind it** — that means **it's drawing each tree twice**: first darker, **pushed back a little
> and one pixel further out**, then again in the right place one pixel further in, in the right colour. So
> the **outlines of the trees will kind of form a common outline**… more of a common blob than individual
> blobs."*

⚠⚠ **A screen-space offset silhouette, not a normal-expanded hull — which is exactly why it survives on a
flat plane.** A plane has no normals to expand along, but it does have a silhouette to offset.

**And the outline is opt-in, per object:**
> **Talk, 40:56–41:40** — *"…some things are **marked up that they're supposed to have an outline**, or
> they're supposed to have a **mirror**, and if they're supposed to have a mirror I just create another
> instance of that game object… and in the shader it flips that upside down."*

**Outline thickness scales with resolution:**
> **@OskSta, Jul 12 2018** — *"Making some **thicker outlines** for all you 4k high ballers out there."*

**A third trick, for the ground under the grass:**
> **Talk, 18:23–19:09** — *"You see the little shadow under the grass — that's also all done in shader, and
> it uses a shader function called `ddy` which measures how a pixel's value changes in the vertical axis of
> the screen. You can put a tiny bit of shadow underneath something **in just one pass**, without drawing
> the shadow in one polygon and the grass on top in another."*

### ⚠⚠ **Foliage DOES move — a wind field in a 3D texture**

> **@OskSta, Dec 20 2017** — *"Note also how the **foliage wiggles in relation to how exposed it is to the
> wind**."* — [the tweet](https://x.com/OskSta/status/943236461880594432)
> **@OskSta, Dec 20 2017** — *"The snowflakes positions are stored in a texture, and the **wind vectors go
> in a 3D texture**, so it's a neat little pixel shader doing all the work."*
> **@OskSta, Dec 20 2017** — *"…obviously the snow flakes are **affected by the wind system and thus flow
> around the island**."*
> **@OskSta, Nov 5 2017** — *"That big **rock to the right splits the wind**, for example."*
> **@OskSta, Apr 25 2019** — listing Bad North talk topics: *"…My implementation of WFC with rules, import
> script, deriving adjacency.. **Using the generated voxels for lighting, wind, collision**.. Generating a
> nav mesh and running flow fields on it."*

**Read together: the same voxel field that gives lighting also carries a wind vector field, terrain and
rocks deflect it, and how much a plant wiggles is how exposed its spot is.** ⚠ **The exact shader is never
described** — no vertex-colour mask, no phase-offset scheme, no per-instance detail is stated anywhere.

⚠ **Not everyone liked it.** A reply on that thread, from a viewer and not a developer:
> **@ryanmong, Dec 20 2017** — *"your **bush wiggling is too regular**… wind is more wave like against
> objects."*

### How foliage is placed — **the generator scatters it, and rocks and tombstones ride the same system**

> **@OskSta, Feb 3 2018** — *"A great unexpected joy in this project has been writing my own navmesh… Here
> you see some **pulsating vertex cells; a dual to the triangular grid** and a suitable place to start with
> **foliage placement**."*
> **@OskSta, Feb 3 2018** — *"Each **foliage system has a density function** based on things like
> **convexity, perlin noise**, etc. That function is run **for each cell**, and foliage is **randomly placed
> within it until the density has been achieved**. After that, a few iterations of **push dynamics** help
> reduce overlap."*
> **@OskSta, Feb 3 2018** — *"I run some **push-apart dynamics on the foliage after it's been placed**.
> These cells are for the initial placement, and it's where the **initial density targets** are calculated."*
> **@OskSta, Dec 9 2022** — *"Also, **in Bad North, the Nav Mesh was crucial in foliage generation**."*
> **Talk, 37:44–37:52** — *"When I run the **grass placing algorithm**… the **grass runs on the navmesh**."*

⚠⚠ **"Foliage" is a general prop scatterer, not just plants:**
> **@OskSta, Feb 3 2018** — *"**Tombstones are a legitimate type of foliage.** Don't let anyone tell you
> otherwise."*

**And he keeps the scattering out of the tile algorithm on purpose:**
> **@OskSta, Jun 29 2022** — *"…use WFC for what it's good at: fitting tiles together. **Placing props,
> painting walls, growing foliage**, connecting powerlines, all probably want **their own algorithms**."*

### The green surface is the **navmesh**, and there is no rock texture

> **Talk, 38:16–38:23** — *"If you look at… **the green part here in the meshes — that's actually the
> navmesh**."*
> **Talk, 13:40–14:11** — *"There's very very few colours going on in the base island. There's basically
> **three elements: walkable areas, non-walkable areas, and cliffs**, and that's it… I **don't need to have
> a rock texture** telling you over and over there's a rock here, rock here, rock here."*

### Rocks

**Rocks exist as objects on the island** — the wind tweet above says one *"splits the wind"* — but **no
source found says what they are made of, or whether they come out of the same foliage scatterer.** Cliff
faces are one of the three flat colours and carry no texture.

### Why the islands are sparse

**Readability and headcount, never draw calls. No performance number exists in any source found.**

- **"Borders, not textures"** (talk 02:42), restated as a principle:
  > **@OskSta, Sep 26 2018** — *"I feel like with a detailed tiling texture, you just keep telling people
  > over and over **'this is grass, this is grass, this is also grass'**. Just put some fuzz around the
  > edges, they'll get it, and then focus on telling more important stories."*
- **Trees deliberately under-detailed** (talk 14:32–15:02) — *"a junior artist would make a very beautiful
  detailed tree, but… if you put a thousand of those around it becomes very cluttered — whereas as a player
  you're probably just interested in 'there's a forest here'."* Same point on Twitter:
  > **@OskSta, Apr 4 2018** — *"**A tree that looks great when seen alone in a concept will probably look
  > terrible as part of a bigger forest**, and vice versa."*
- **"Minimal labour"** (talk 04:32) — *"me and one other guy full-time and then an audio guy half time."*
- **Sprites for units for the same reason**:
  > **@OskSta, Sep 22 2018** — *"**2D characters are cheaper in terms of performance and production**, and
  > you can get away with way more shortcuts. 3D characters take a lot of rigging, animation and animation
  > tech work before they stop looking bad."*
- **Scale**: ~**400 hand-built Maya tiles** grown over two years; the first working prototype needed ~**10**
  (talk 06:34–07:08). Modules span multiple grid squares, which is what allows stairs, tunnels and bridges
  (08:27–09:19). The terrain is **merged into one mesh** (talk 37:25).

### ⚠ What this changes about section 1 below

**I reported earlier that the majority ships real geometry. Bad North is on the other side of that line**,
and it is the project this game is measured against. The reconciliation is that Bad North's card-friendly
tricks — offset-silhouette outlines, voxel-field normals and voxel-field wind, baked AO instead of shadows,
a camera that never leaves its orbit — **are a package**. Taking the billboard without the package is what
runs into the Godot billboard-shadow bugs and the inverted-hull-on-a-quad problem listed below. **The
developer says this himself about a later project with a free camera:**
> **@OskSta, Sep 29 2023** — *"Especially if they need to **move in the wind**. But **with billboards i
> need to fight with clipping and outlines become a lot less clean**."*

---


## 1. Mesh vs card for one bush, elsewhere

### Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Ghost of Tsushima** (Sucker Punch) | **Real geometry per blade, no cards.** Each blade is a cubic Bézier from 4 control points, generated on the GPU; **view-space thickening** shifts vertices toward the camera when a blade is edge-on, and **curved normals** fake roundness rather than adding geometry | Shipped 2020 | [GDC 2021, *Procedural Grass in 'Ghost of Tsushima'*](https://gdcvault.com/play/1027033/Advanced-Graphics-Summit-Procedural-Grass) (Vault, login-gated) · [second-hand write-up](https://tigerabrodi.blog/grass-in-ghost-of-tsushima) |
| **Genshin Impact** (miHoYo) | **Per-blade mesh grass**, 48–114 triangles per blade by LOD, instanced up to 32 clusters per draw call, bend done in the vertex shader from pseudo-random per-instance values | Shipped 2020 on phones | [GDC 2021, *Crafting an Anime Style Open World*](https://gdcvault.com/play/1027539/-Genshin-Impact-Crafting-an) · ⚠ **the tri counts come from [this breakdown](https://parsers.vc/news/250124-the-art-of-game-rendering--a-deep-dive-into/), not from the talk itself** |
| **hexaquo's Godot grass series** | Weighs both **in Godot 4** and picks full geometry: *"very heavy on vertex count"* but *"preferable to the high overdraw caused by transparent billboards."* Cards stay more flexible — swap a texture, get a new plant | A complete public Godot project, `MultiMeshInstance3D` | [Part 2](https://hexaquo.at/pages/grass-rendering-series-part-2-full-geometry-grass-in-godot/) · [repo](https://git.hexaquo.at/karl/godot-grass) |

### Who did the opposite

- ⚠⚠ **Bad North itself** — billboarding planes for the forests, quoted above. **The strongest opposite
  case is the reference project.**
- **Cyanilux's soft-foliage breakdown** — the canonical stylised bush is **intersecting quads**, generated
  by a particle system over a proxy and frozen with `ParticleSystemRenderer.BakeMesh`. And it confesses its
  own cost: the shader **deliberately does not receive shadows**, because *"quads in the foliage mesh can
  cast shadows onto itself making the quads much more obvious."*
  — [breakdown](https://www.cyanilux.com/tutorials/soft-foliage-shader-breakdown/)
- **Firewatch** (Campo Santo) — opposite in another sense: **hand-modelled and deliberately few.** 23 trees
  total, 14 of them the "stars", built by hand because *"SpeedTree was not integrated in Unity back then."*
  Jane Ng's rule: *"if you can get away with 23 trees, don't make 25."*
  — [Game Developer](https://www.gamedeveloper.com/design/environmental-artist-jane-ng-only-made-23-unique-trees-for-i-firewatch-i-) ·
  [GDC 2016](https://www.gdcvault.com/play/1023191/Making-the-World-of)

### The two things that decide it in *this* project, and not in general

- **The inverted hull hates flat cards.** The hull is the mesh drawn again, expanded along its normals with
  front faces culled — so **hard-edged, low-poly and flat geometry breaks the outline into gaps**, and it
  needs normal-smoothing into UV2 or tangents to survive. A flat quad's hull is a rectangle around the quad,
  not around the leaf. **Stålberg hit exactly this** and solved it by not using a hull on trees at all
  (16:43 above). —
  [toon-rp wiki](https://github.com/Delt06/toon-rp/wiki/Inverted-Hull-Outline) ·
  [Unreal forum thread on hull gaps](https://forums.unrealengine.com/t/best-way-to-fix-gaps-in-toon-outlines-when-using-inverted-hull-method/1319625) ·
  [Daniel Ilett](https://danielilett.com/shader-toolbox/hull-outlines/)
- ⚠ **Godot billboards and shadows are a live bug surface.** A billboarded mesh's shadow is computed with
  the mesh **facing the light, not the camera**; a Y-billboard `Sprite3D` **stopped casting shadows at all**;
  billboard `Sprite3D` shadows have been reported stuck at the node's zero rotation. A fix PR exists and the
  behaviour has moved between versions. —
  [#936](https://github.com/godotengine/godot/issues/936) ·
  [#27738](https://github.com/godotengine/godot/issues/27738) ·
  [#41420](https://github.com/godotengine/godot/issues/41420) ·
  [PR #72638](https://github.com/godotengine/godot/pull/72638)

---

## 2. Idle wind sway

**The standard technique, in one sentence.** Displace vertices in the vertex shader by a scrolling noise or
a sine of time, multiply the displacement by a **per-vertex weight** so the base stays nailed down, and
**offset the phase per instance** so no two objects move together.

| Who | What they did | Cost | Source |
|---|---|---|---|
| **Unreal Engine** (Epic) | Ships it: **`SimpleGrassWind`**, taking a **weight map** and a strength, plugged in last on the World Position Offset chain; **`ObjectPivotPoint`** returns the instance pivot in world space as the phase seed | ⚠ `SimpleGrassWind` is **non-directional** — a wind vector must be injected by hand to match a `WindDirectionalSource` | [UE 5.8 docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-position-offset-material-functions-in-unreal-engine) · [UE 4.27](https://docs.unrealengine.com/4.27/en-US/RenderingAndGraphics/Materials/Functions/Reference/WorldPositionOffset) |
| **Source engine** (Valve) | `$treesway`, a shipped material proxy animating a static prop | ⚠ Documented outright: *"lightmap shadows cast by swaying static props will remain static."* | [Valve wiki](https://developer.valvesoftware.com/wiki/$treesway) |
| **Godot 4** | **Ships nothing for foliage.** The docs' nearest thing is the ABZÛ-style vertex-animation tutorial: per-instance variation goes through **`INSTANCE_CUSTOM`** — `float time = (TIME * time_scale) + (6.28318 * INSTANCE_CUSTOM.x);` — fed by `MultiMeshInstance3D` as a per-instance Color | You write the shader | [Animating thousands of fish](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html) |
| **hexaquo (Godot 4)** | Global `uniform vec2 wind_direction` + a `NoiseTexture2D` (Simplex Smooth, Ridged) sampled at world position and scrolled by `wind_position -= TIME * wind_direction * wind_strength`; bend ramps by a `bottom_to_top` parameter, bent parts darkened for fake self-shadow | Working Godot project | [Part 3](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/) |

**The vertex-colour convention.** R = leaf/twig flutter · G = branch bend, 0 at the joint → 1 at the tip ·
B = whole-asset sway base to canopy · black at the roots so the base never leaves the ground.
⚠ **Sources agree on the roles and disagree on the channel order.**
— [Cyanilux](https://www.cyanilux.com/tutorials/soft-foliage-shader-breakdown/) ·
[Victor Karp, Godot 4](https://victorkarp.com/godot-foliage-wind/) (uses R = trunk→canopy, G = branch
base→tip — a different order) ·
[vertex-colour write-up](https://salivity.github.io/game-development/article/making-foliage-react-to-wind-using-vertex-colors) ·
[minifloppy, UDK](https://minifloppy.it/posts/2014/udk-wind-vertex-shader/)

**Nobody in these sources uses bones or baked vertex-animation textures for idle foliage sway.**

### ⚠ The gotchas people actually report

| The bite | What happens | Source |
|---|---|---|
| **Culling against a stale AABB** | The AABB is computed from the *undisplaced* vertices, so a bush that sways outside it **pops out of existence near the screen edge**. Fix: `custom_aabb`, or `extra_cull_margin` ≥ the shader's maximum displacement | [godot#28933](https://github.com/godotengine/godot/issues/28933) · [godot#72614](https://github.com/godotengine/godot/issues/72614) · [write-up](https://bugnet.io/blog/fix-godot-rendering-server-mesh-instance-aabb-wrong) |
| **The shadow does not sway** | The shadow/depth pass often runs a stripped vertex shader without the displacement — the mesh sways, its ground shadow stands still | [Valve `$treesway`](https://developer.valvesoftware.com/wiki/$treesway) · [Unity URP shadow-caster pass](https://bugnet.io/blog/fix-unity-shadergraph-vertex-position-not-affecting-shadow) · [UE forum](https://forums.unrealengine.com/t/foliage-wind-creating-weird-shadows-on-top-of-mesh/229082) |
| **Rotated instances sway different ways** | Displacement is applied in **model space**. Fix: transform world-space wind into model space with `inverse(MODEL_MATRIX)` (hexaquo) or a TransformVector node (Karp). Without it the field *"dances rather than being blown by the wind"* | [hexaquo Part 3](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/) · [Karp](https://victorkarp.com/godot-foliage-wind/) |
| **Batching kills world-position phase** | Static/dynamic batching rewrites the model matrix, so phase derived from object position silently collapses — every batched bush moves in lockstep | [Cyanilux](https://www.cyanilux.com/tutorials/soft-foliage-shader-breakdown/) |
| **The base lifts off the ground** | Prevented by the weight mask being **zero at the roots**, not by anything clever | [vertex-colour write-up](https://salivity.github.io/game-development/article/making-foliage-react-to-wind-using-vertex-colors) |

---

## 3. Interaction sway — bending when a body walks through

**Two implementations, and they are not the same size.**

| Scale | How | Cost |
|---|---|---|
| **Field of thousands** | A **displacement / bend render texture** covering a box **around the camera**. Everything that should push grass draws into it each frame; the grass shader samples it at its own world position | One extra render target and one extra pass every frame |
| **Tens of objects** | **One (or a small array of) global shader uniform(s)** holding the bender's world position and radius. No texture, no extra pass | One script setting one uniform per frame |

### Cases

| Who | What they did | Source |
|---|---|---|
| **Ghost of Tsushima** (Sucker Punch) | Wind is heuristic, not fluid sim: a base vector from player toward objective modulated by time-varying Perlin noise, plus **"vorticles"** — invisible wind-emitting particles carrying position, orientation, radius and direction; *"amazingly works even up to hundreds of vorticles"* by brute-force array sampling. Grass and foliage additionally take **local disturbance inputs from character footfalls** | [Game Developer, by Sucker Punch](https://www.gamedeveloper.com/design/using-vorticles-to-simulate-wind-in-i-ghost-of-tsushima-i-) · [GDC 2021](https://gdcvault.com/play/1027033/Advanced-Graphics-Summit-Procedural-Grass) |
| **hexaquo (Godot 4)** | The cheap version written out in this engine: `uniform vec3 object_position`, `uniform float object_radius`; strength `= max(object_radius - object_distance, 0.0) / object_radius`, direction the normalised vector from object to blade, uniform pushed by a script each frame. For several benders the uniforms become **arrays** | [Part 3](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/) · [repo](https://git.hexaquo.at/karl/godot-grass) |
| **Staggart, Stylized Grass Shader** (shipped Unity asset) | A URP **render feature**; any Mesh/Trail/Line Renderer or Particle System becomes a **"Grass Bender"**. *"Shape and position is translated to the shader on the GPU, so no actual physics calculations are being used."* The processed area is **a box around the camera**, drawn as a white wireframe in the scene view. ⚠ Particle benders must use 3D meshes, **not flat billboards** | [docs](https://staggart.xyz/unity/stylized-grass-shader/sgs-docs/?section=using-grass-bending) |
| **Staggart, Fantasy Adventure Environment** (the older cheap one) | A `FoliageBender` component parented to the player plus a `BendingInfluence` material parameter. ⚠ **"You can only have one of these scripts active at a time"** — the shipped cheap version supports exactly **one** bender | [docs](https://staggart.xyz/unity/fantasy-adventure-environment/fae-documentation/?section=grass-bending) |
| **Unreal, community route** | Bend through World Position Offset from a player-position material parameter; SpeedTree's `extra bend` input since 4.19 does the same; the scaled version is a **scene capture + particle system writing a vector field**, or Render Targets driven by particles — called *"a much safer method"* than the alternatives | [80.lv](https://80.lv/articles/tutorial-interactive-grass-in-unreal) · [Kodeco](https://www.kodeco.com/6314-creating-interactive-grass-in-unreal-engine-4) · [SpeedTree forum](https://forum.speedtree.com/forum/speedtree-modeler/using-the-speedtree-modeler/5254-interactive-character-collision-bending-on-foliage-wheat-corn-etc-in-ue4) |

### Who did the opposite

- **Alan Zucconi** names the uniform version's real ceiling: *"only one object can affect and bend the
  grass, and to allow multiple to do so, you need to add more variables to store character positions and
  update the shader accordingly."* The render-texture version exists **because uniforms do not scale**, not
  because it looks better. — [Shader Showcase Saturday #3](https://www.alanzucconi.com/2018/07/28/shader-showcase-saturday-3/)
- ⚠ **Bad North's wind is environmental, not character-driven.** Foliage responds to a wind field the
  terrain and rocks deflect; **no source describes anything bending away from a unit walking through it.**

---

## What this does not settle

- **What Bad North's trees are made of, specifically.** *Forests* are stated to be billboarding planes and
  *grass* is stated to be quads; **whether a tree is one card, a cross of cards, or the same system as the
  grass is never said.**
- **The wind shader itself.** That foliage wiggles by exposure to a 3D-texture wind field is stated. **The
  mask, the phase offset and the per-instance scheme are not, anywhere.**
- **What Bad North's rocks are made of.** A rock is stated to split the wind, so rocks exist as objects, but
  **no source says whether they are meshes, cards, or output of the same foliage scatterer.**
- **Any draw-call or frame-time number for Bad North.** None given. The sparseness is explained entirely as
  readability and a three-person team.
- **Asset inspection.** **No post, video or thread was found where anyone unpacked Bad North** with
  AssetStudio/AssetRipper and described its meshes, materials or shaders. Everything above is the
  developers' own account; **nothing here rests on a third-party reconstruction.**
- **Breath of the Wild's grass geometry.** Named second-hand as per-blade mesh grass; no Nintendo talk or
  primary breakdown found. **Treat as unverified.**
- **A measured Godot number for this project.** No source gives a frame cost for N low-poly bushes with an
  inverted hull in Godot 4. **This one has to be measured here, not read.**
