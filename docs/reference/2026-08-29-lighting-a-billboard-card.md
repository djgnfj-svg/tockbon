# How do other games keep a 2D billboard card from reading flat on 3D terrain?

**They never light the card by its own flat normal — they replace the normal (with a baked one
rendered from a real 3D mesh, or with a hand-authored sphere/dome normal), and they treat the card's
cast shadow as a separate problem solved by a separate proxy.**

Written 2026-08-29 by `research`. Bad North was excluded on purpose — the caller already holds it.

---

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Guerrilla Games** — *Horizon Zero Dawn* (2017) | Alpha-plane foliage carries a **tangent-space normal map plus custom vertex normals** (deck slides 54–55 are a straight A/B: "'NORMAL' VERTEX NORMALS" vs "CUSTOM VERTEX NORMALS"). For double-sided grass and tree canopies they additionally **Abs() the Z component of the view-space normal** so the normal leans toward the camera instead of flipping. AO is a separate texture packed BC7 with the mask — **not on grass**. Shadows: **separate visual meshes and shadow-casting meshes**, depth-only shaders, non-animated at the far cascade. Billboards appear only at the last LOD (12 triangles for trees, 8 for plants) | Shipped; the deck's own summary lists **"Shadow Casters separate"** as one of the five things that worked | [GDC 2018 deck, PDF — slides 46–58 shading, 77–83 LODs and shadows, 85 summary](https://media.gdcvault.com/gdc2018/presentations/gilbert_sanders_between_tech_and.pdf) |
| **SpeedTree (IDV)** — billboard LOD, shipped in hundreds of games | The billboard's **normal map RGB "hold a tangent-space normal map of the entire 3D tree, sampled from a rendering done in the Compiler application."** Diffuse RGB is a pre-rendered *unlit* image multiplied by light scalars and AO. The normal map's **alpha holds an ambient/skylight dimming value** "to help break up the monotony of an artificially even ambient shading." At runtime the shader **picks from an array of images by azimuthal angle**. A **separate overhead (horizontal) billboard** exists, cross-faded by camera pitch, and is "**also used to cast a better shadow when the light is more directly overhead**" | Their own claim: "amazingly good matches between the 3D trees and their billboard counterparts… the billboards have no pre-baked lighting" | [SpeedTree docs — Level of Detail](https://docs.speedtree.com/doku.php?id=overview_level-ofdetail) |
| **Epic Games** — Impostor Baker (Ryan Brucks' octahedral impostors), shipped in *Fortnite Battle Royale* | Bakes **BaseColor, Normal, and optionally Depth / Opacity / Roughness** by **rendering the real 3D mesh from many viewpoints** into an atlas; at runtime "the impostor material finds the three captured frames closest to the current camera view, and blends between them." Three trapping modes: full sphere, **upper hemisphere**, traditional billboards. Epic's own doc: "**In Fortnite Battle Royale (FNBR), we use Upper Hemisphere Imposters for all of our trees**" — chosen because the object "sits on terrain and cannot be viewed from underneath." 12×12 = 144 frames in FNBR | Shipped, and promoted from a community plugin into UE5 as a built-in | [Epic — Impostor Baker Plugin](https://dev.epicgames.com/documentation/en-us/unreal-engine/impostor-baker-plugin-in-unreal-engine) · original write-up [shaderbits.com/blog/octahedral-impostors](https://shaderbits.com/blog/octahedral-impostors) — ⚠ the shaderbits page is JS-rendered and its body could not be extracted for verbatim quoting |
| **Facepunch** — *Rust* | Hard distance split: "**forcing all trees that exceed the limit to be rendered as billboards, only rendering the trees closest to the camera as meshes.**" Impostors are **baked from several directions**. Later they wrote a dedicated impostor renderer because "impostors have become one of the biggest CPU bottlenecks" | Shipped. Their changelog also carries the line "**Fixed tree impostor shadow orientation**" — the card's cast shadow is orientation-dependent and did in fact break | [Rust — The Performance Update](https://rust.facepunch.com/news/the-performance-update) · [Devblog 197](https://rust.facepunch.com/news/devblog-197) |
| **Crytek** — *Crysis* (2007), the technique Guerrilla reused | Leaves are **double-sided alpha-tested planes**, lit with a **subsurface-scattering approximation** from "an artist-made subsurface texture map" for leaf thickness, plus a "**precomputed ambient occlusion term stored in the vertex's alpha channel**, painted by artists or computed using standard 3D modeling software." The normal is the mesh's own vertex normal | Shipped and became the reference implementation — Guerrilla state they used the Crytek tree technique rather than SpeedTree | [GPU Gems 3, Ch. 16 — Vegetation Procedural Animation and Shading in Crysis, Tiago Sousa (Crytek)](https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-16-vegetation-procedural-animation-and-shading-crysis) |
| **Airborn** (Half-Life 2 mod, dev "Warby") — the sphere-normal technique, on record | An inner "bubble" mesh sits inside the leaf cloud and its **normal orientation is projected onto the leaf cards**, so instead of flat faces you get "a very nice and soft shadow gradient all over the leafs." Warby's second reason: "you avoid too many transparent planes being rendered over each other. The big blob mesh in the middle culls most of them" | The stated goal was trees that look "**soo fluffy**" — achieved | [Simon Schreibt — Airborn: Trees](https://simonschreibt.de/gat/airborn-trees/) — ⚠ a mod, not a commercially shipped game |

---

## Who did the opposite

- **Sucker Punch — *Ghost of Tsushima*.** Threw grass cards out entirely and generate **every blade as a cubic Bézier curve on the GPU, rebuilt each frame**, so each blade has its own appearance and animation. The reason given is that a card's wind animation is welded to the whole card and individual blades cannot sway. Source: [GDC 2021 — "Procedural Grass in 'Ghost of Tsushima'", Eric Wohllaib, free video](https://www.youtube.com/watch?v=Ibe1JBF5i5Y) · [GDC Vault listing](https://gdcvault.com/play/1027033/Advanced-Graphics-Summit-Procedural-Grass). ⚠ **Unverified against the primary**: no public deck PDF was found and the talk's own wording could not be extracted here, so the "why not cards" reasoning above comes from secondary write-ups, not from a timestamped quote.
- **Campo Santo — *Firewatch*.** A stylised, flat-shaded, non-photoreal game that built **23 unique 3D tree meshes by hand** rather than cards. Jane Ng: "I had to make it by hand because Speedtree was not integrated in Unity back then," and "very few games have pine trees, because of all trees in the world pine trees are the worst in terms of being made 3D." Source: [Game Developer — coverage of her GDC talk](https://www.gamedeveloper.com/design/environmental-artist-jane-ng-only-made-23-unique-trees-for-i-firewatch-i-) · [GDC Vault — Making the World of Firewatch](https://www.gdcvault.com/play/1023191/Making-the-World-of). ⚠ The commonly repeated claim that Firewatch used flat billboards only in the far distance appears in press summaries and was **not** verified against the talk itself.

---

## Camera dependence

- **Baked multi-angle impostors (SpeedTree, Epic) assume the camera stays above the horizon.** Epic's *upper hemisphere* mode and SpeedTree's azimuth array plus separate overhead billboard both exist precisely because the object sits on ground. **A locked-pitch orbiting camera is the best case for this family**, not the worst — the angle range that must be baked is small.
- **Guerrilla's Abs(view-space normal Z) is camera-relative** and needs no baking, so it survives any camera — but it is a per-pixel correction applied to a normal map, not a substitute for having a normal.
- **A fixed sphere/dome normal is camera-independent** and costs nothing at runtime, but only reads correctly when the thing is meant to be a blob (a bush, a canopy). It is the wrong answer for a card whose subject is not roughly spherical.

## Baking the normal from a 3D render vs. inflating the silhouette

**Both exist, and the shipped systems all bake from a 3D render.** SpeedTree ("sampled from a rendering done in the Compiler application") and Epic's Impostor Baker (renders the real mesh) both take colour *and* normal from real geometry. Silhouette inflation is a 2D-sprite tool technique (Laigter, SpriteIlluminator), not a foliage-pipeline one.

**And silhouette inflation is reported to look wrong.** Moreira, Coutinho and Chaimowicz evaluated it and found the "beveling" (distance-transform inflation) method gives "**geometry much less faithful to the original image**", "**diminished control over the details, with the generated geometry different than the expected output**", and that it invents "portions of the image identified as separate objects that do not correspond directly to an existing element in the original sprite." It also cannot express negative volume. Source: [Analysis and Compilation of Normal Map Generation Techniques for Pixel Art, arXiv 2212.09692](https://arxiv.org/pdf/2212.09692), sections IV-D and V-D.

## The shadow, specifically

| Approach | Who | Note |
|---|---|---|
| Real cast shadow, but from a **separate shadow-casting mesh**, not the visual card | Guerrilla / HZD | LOD3 alpha-tested near, cheaper non-animated non-alpha-tested far |
| Real cast shadow, plus a **second horizontal billboard** to fix the overhead-sun case | SpeedTree | The vertical card's shadow is the thing that breaks |
| Real cast shadow, and it **broke on orientation** | Facepunch / Rust | "Fixed tree impostor shadow orientation" |
| **AO baked into vertex colours** instead of a shadow | Crytek / Crysis | Precomputed AO in the vertex alpha channel |
| **Blob shadow decal** on the ground | Long-standing engine idiom, documented by Epic | [UDK — Creating a Simple Blob Shadow](https://docs.unrealengine.com/udk/Three/DevelopmentKitGemsCreatingASimpleBlobShadow.html): "useful when accurate real-time dynamic shadows aren't necessary… helpful for maintaining performance when many actors require shadowing" — ⚠ no shipped-title citation found for this on *foliage* specifically |

**Godot-specific.** Billboarded `Sprite3D` shadows were wrong until [PR #72638](https://github.com/godotengine/godot/pull/72638) — during the shadow pass the billboard faced the *shadow* camera, not the main one. Fixed by piping `main_cam_inv_view_matrix` into the shader; merged 2024-02-13, milestone **4.3**. This repo runs 4.7.1, so the fix is present — but the shadow a billboard casts is still the shadow of a flat plane that rotates as the camera orbits.

## What this does not settle

- **No timestamped primary quote for Ghost of Tsushima's rejection of cards.** The claim is well attested secondhand and the talk is free to watch, but it is not verified here.
- **No shipped stylised / low-poly game was found that documents using a sphere-normal card on low-poly terrain.** The sphere-normal technique is thoroughly attested as an artist workflow (SpeedTree's Transfer Normals, Polycount threads, the Airborn write-up) but the named-and-shipped examples all use *baked-from-3D* normals instead.
- **No case was found of anyone deliberately shipping foliage cards with no shadow at all** and saying why.
