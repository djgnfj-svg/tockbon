# How do other stylised island games draw the line where water meets land?

**Answer in one line.** Nobody who ships this look draws a single constant-width white stroke: the shore
is a **mask that is blurred, broken up by an authored texture, and animated**, and the mask itself comes
either from a depth comparison or from a **distance value baked into the mesh's own UVs** — the second
needs no depth buffer and is the one that matches a CPU-baked distance-to-land map.

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Bad North** (Plausible Concept, Oskar Stålberg) | Whole art direction is **"borders, not textures"** — crisp lines at boundaries, flat fields between them. The sea is "just a mesh with a looping wavy shader"; **"most of the water is just completely flat, but then at the edge when something meets the water I highlight that instead… where these two materials meet there's a coastline, that's it."** The reflection under the island is a separate flipped copy of the mesh, not a shader trick | Shipped 2018; the coastline is the *only* signal that the flat plane is water, and it is deliberate, not an accident | [Konsoll 2018 talk, water at **31:26–32:10**, principle stated at **02:42** and **16:29**, reflection answered at **40:48**](https://www.youtube.com/watch?v=6JcFbivo8dQ) |
| **Sea of Thieves** (Rare) | Foam around anything intersecting the water is a **depth-buffer comparison into a foam buffer**, then: *"We progressively blur the result of the foam buffer with feedback to simulate the foam dispersing and to give us a softer mask, more in keeping with the style of the game. The resulting mask is blended with artist-authored textures to give a more stylized appearance to the foam."* | Shipped 2018. Three stages — mask, blur-with-feedback, authored texture — is the whole recipe for "not a stroke" | [SIGGRAPH 2018 Talks, *The Technical Art of Sea of Thieves*, §1.1](https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf) |
| **A Short Hike** (adamgryu) | *"The water turns to a **solid foamy colour** when it touches the shore. This is done by comparing the distance between the transparent water pixel to the terrain behind it using the depth buffer."* The water is one plane following the player, textured and vertex-animated **in world space** | Shipped 2019. Note the foam is a **solid band of colour**, not a thin outline — its width varies with terrain slope, which is what stops it reading as a drawn line | [adamgryu's own thread](https://threadreaderapp.com/thread/1113100182655262721.html) · [the water plane tweet](https://x.com/adamgryu/status/1112783007566450691) |
| **A Thief's Melody** (Mathias Fontmarty, Oneiric Worlds) | **No depth buffer at all.** A ring mesh belonging to the island carries one hand-mapped coordinate: `v = 0` at the sea edge, `1` at the ground edge, `2` inside the island. Foam = `ratioSinus * sin(frequency*v + speed*time) + ratioTex * tex(xz + noise(xz + noiseSpeed*time) + texSpeed*time) + v`, **alpha-clipped at a threshold**. The painted texture is an **inverted distance transform**, which supplies organic connections between foam lines that a pure sine cannot. Adding `v` makes foam "larger near the shore and thinner on the seaside"; the clip threshold sets overall width | A full public breakdown. This is the closest published match to a **baked distance-to-land map** — the distance lives in the mesh, not in a depth pass | [Oneiric Worlds devblog](https://oneiricworlds.com/en/2019/01/cartoonish-foam-using-procedural-hand-made-textures/) · [Game Developer reprint](https://www.gamedeveloper.com/programming/how-to-create-a-semi-procedural-cartoon-foam-shader) |

## Who did the opposite

- **Flotsam** (Pajama Llama Games) — **tried depth-based shore foam and took it back.** Their first attempt
  failed specifically on a top-down camera: *"the outline is only drawn over the object's mesh, meaning its
  visibility depends exclusively on the angle of the camera."* Mesh-intersection foam was next and gave
  jagged foam on sharp shapes plus a heavy framerate cost; particles "didn't end up looking like what I had
  in mind" and weren't "subtle enough". They settled on **animated spritesheet textures moving with the
  water**, working "as much as possible within the texture". Their own verdict: *"The perfect approach has
  yet to be discovered."* — [devlog](https://www.pajamallama.be/devlog/the-water-of-flotsam/)
- **A Thief's Melody** is also the opposite in the other sense the question asked: **the shore belongs to
  the island's mesh, not to the water shader.** Same source as above.
- Cyanilux's shoreline breakdown ships a **"wet sand"** layer — black at very low alpha, darkening the
  ground beyond the swash — as a distinct thing from the white foam, i.e. the land carries part of the shore
  read. — [breakdown](https://www.cyanilux.com/tutorials/shoreline-shader-breakdown/)

## The named techniques, and what each one needs

| Name | Needs | Note |
|---|---|---|
| **Depth-intersection foam** / "edge foam" | Runtime scene depth texture | The default everywhere: compare water pixel depth to scene depth, `smoothstep` the difference. Sea of Thieves, A Short Hike, Alisavakis, Ilett, Ameye |
| **Foam buffer + progressive blur with feedback** | Depth, plus a persistent render target | Sea of Thieves. The blur is what makes it soft; the feedback is what makes it trail and disperse |
| **Baked sea-floor depth / distance cache** | **No runtime depth pass** — a top-down orthographic heightfield rendered once and saved as an asset | Crest calls it the `OceanDepthCache`; it can be "saved as a baked asset for offline generation". Same data shape as a CPU-baked distance-to-land map — [docs](https://crest.readthedocs.io/en/stable/user/shallows-and-shorelines.html) |
| **UV-distance shoreline** (`UV.v` = distance from shore) | **No depth** — a shoreline mesh with authored UVs | Cyanilux's second method; A Thief's Melody's whole approach |
| **Vertex-colour shoreline** | **No depth** — painted per-vertex | Staggart's Stylized Water 2 drives intersection foam from vertex red and the depth-colour gradient from vertex green, as an alternative to automatic depth — [docs](https://staggart.xyz/unity/stylized-water-2/sws-2-docs/?section=vertex-colors-2) |
| **Animated UV foam strips / spritesheet** | No depth | Flotsam's landing place |
| **Breakup mask** | Whatever the base mask is | Ameye's shader names it outright: *"Breakup — scale and strength options for regions without foam"*. This is the parameter that stops a continuous line — [docs](https://alexander-ameye.gitbook.io/stylized-water/features/shader-properties) |

## What makes foam read as WET rather than as a stroke

Every published breakdown does at least three of these five:

1. **Width varies along the shore.** A Short Hike gets this free: depth difference widens the band on
   shallow slopes and narrows it against a cliff. A Thief's Melody gets it by adding `v` to the wave term
   so foam is fat at the sand and thin seaward. **A constant-width band is the single strongest tell of a
   drawn outline.**
2. **The mask is blurred before it is used.** Sea of Thieves blurs the foam buffer *with feedback*
   explicitly "to give us a softer mask, more in keeping with the style of the game".
3. **An authored texture cuts it up.** Sea of Thieves blends the mask with artist textures. Wind Waker
   analyses and Ilett's shader use a **Voronoi cell texture** (white cell lines on black). A Thief's Melody
   uses an **inverted distance-transform** painting, chosen because it gives connections between foam lines.
4. **It moves, and not all in one direction.** Cyanilux runs an inbound scrolling wave *and* a back-and-forth
   "swash" with a `Time Offset` of about `-2.5` to keep them in sync, amplitude `0.1`, plus a dissolve whose
   `Edge1` animates between `0.7` and `0.8`. A Thief's Melody warps the sample point by world-space noise
   that itself scrolls, so the line wobbles rather than slides.
5. **Colour: white is normal, but it is reached by a lerp, not painted on.** Ilett lerps `(1,1,1,1)` into the
   water colour over the shore gradient; Ameye keeps the shore *colour* as a separate control from the foam.
   Ameye and Cyanilux both add a **darkened wet band on the land side** as its own layer.
   — [Ilett](https://danielilett.com/2020-04-05-tut5-3-urp-stylised-water/)

Two of the five (blur, authored breakup texture) are what a hard `step()` throws away. Ilett's tutorial uses
`Step` at `0.5` and gets a hard edge on purpose — that hard edge is fine *because* the Voronoi texture
underneath it is already irregular. **Hard edge + smooth mask = a stroke. Hard edge + broken mask = foam.**

## What this does not settle

- **Bad North's coastline is described but not specified.** Stålberg says there is a highlight where the two
  materials meet; he never says its width, whether it is on the water or the island, whether it moves, or
  whether it is white. The talk is the only primary source found — there is no Bad North shader post, no
  tweet thread, no article with numbers.
- **No shipped stylised 3D island game was found that deliberately ships with no shore line at all** and
  says so. Flotsam is the nearest, and they rejected the depth technique, not the shore line itself.
- **DREDGE has a full water-shader deep dive by its 3D artist Michael Bastiaens** on Unity's site, which
  would very likely be the best top-down case of all — [the page](https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror)
  returned HTTP 403 to every fetch and could not be read.
