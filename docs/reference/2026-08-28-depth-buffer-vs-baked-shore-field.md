# Depth buffer or a baked field — which one places the shore band, and can Godot's Compatibility renderer even read depth?

**Answer in one line.** Depth-buffer foam is the engine default and it ships (Sea of Thieves), but every
shipped system that also needs the shore for *anything other than one pixel on screen* bakes a
**world-space depth field** beside it — and what they bake is seabed **height**, not distance to the
coastline, which is why they keep the slope-varying band that a plain distance-to-shore SDF throws away.

⚠ Sibling note, written the same day by another agent, answers *how the band is drawn* (blur, breakup
texture, motion): `2026-08-28-how-others-draw-shore-foam.md`. This note answers *where the band's width
comes from*. It also closes that note's last open item — the DREDGE page it could not fetch.

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Sea of Thieves** (Rare) | Wave-peak foam from the FFT, and separately: *"It is also added around objects that intersect the water surface within a camera centered window using **depth buffer comparisons**."* Foam buffer blurred with feedback, then blended with artist textures | Shipped 2018. The depth buffer is the **only** shore mechanism named in the paper. Note the scope: *"within a camera centered window"* — not the whole world | [SIGGRAPH 2018 Talks, §1.1](https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf) |
| **Unity, Boat Attack water** (official URP demo, source public) | Uses **both, and splits them by job**. `AdjustedDepth()` linearises `_CameraDepthTexture` → drives absorption, scattering, refraction, soft shadows. A separate **baked top-down orthographic R8 depth tile** (`DepthBaking.cs`: ortho camera, power-of-two, `texelSize`, `AsyncGPUReadback` → `Texture2D`) → drives **the shore foam ramp** (`depthEdge = saturate(input.depth.y * 0.5)` → `foamShoreRamp`) and the edge fade. The same baked values are read on the **CPU** in a Burst job for buoyancy | Unity's own reference water puts the shore band on the **baked** field and the volumetric look on the **live** depth buffer | [`WaterCommon.hlsl`](https://github.com/Unity-Technologies/boat-attack-water/blob/main/Runtime/Shaders/WaterCommon.hlsl) · [`DepthBaking.cs`](https://github.com/Unity-Technologies/boat-attack-water/blob/main/Runtime/Modifiers/DepthBaking.cs) |
| **Crest Ocean System** (wave-harmonic, Unity, used commercially) | `OceanDepthCache` *"renders everything in those layers (and within its bounds) from a top-down orthographic view to generate a heightfield for the seabed"* and *"stores the terrain height, which can then be differenced with the sea level to obtain the water depth"*. Used *"to attenuate large waves in shallow water, to generate foam near shorelines, and to provide shallow water shading"*. *"By default this generation is done at run-time during startup, but the component exposes other options such as generating offline and saving to an asset, or rendering on demand"* | **No depth buffer in the shore path at all.** Moving geometry needs `RegisterSeaFloorDepthInput`, which re-records every frame | [Crest docs, Shorelines and Shallows](https://crest.readthedocs.io/en/stable/user/shallows-and-shorelines.html) |
| **DREDGE** (Black Salt Games) | A painted multi-channel **wave-mask texture** — *"the single largest texture in the game… We use these for a bunch of different calculations in the water shader, as well as for actual gameplay information… We also have some depth checks. One of these shaders can tell us how deep the water is in certain areas"*. And: *"We also have a whole system for painting the wave height in the world, so whenever you're near an island we have a texture that controls the maximum possible wave height. It's always set to zero at the edge of islands so that waves can't lift the boat up and beach players."* | Shipped 2023. The reason the field is baked is **gameplay** — the CPU has to read it, and the depth buffer cannot be read cheaply from gameplay code | [Unity deep dive, Michael Bastiaens, 3D Artist](https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror) · [Game Developer, Alex Ritchie, Lead Artist](https://www.gamedeveloper.com/design/trawling-in-the-deep-how-black-salt-games-made-spooky-fishing-rpg-i-dredge-i-) |
| **Bad North** (Plausible Concept, Oskar Stålberg) | *"The way I've done the water here is… fairly basic… it's just like a mesh here that plays this sort of looping wavy shader… it also ties into the idea of expressing things in borders and not in… textures, not in field. So most of the water is just completely flat, but then at the edge when something meets the water I highlight that instead… where these two materials meet there's a coastline, that's it."* At 40:48 he confirms the mirrored island is a **literal flipped duplicate mesh**, not a shader | ⚠ **The design rule is on record; the mechanism is not.** He never says depth buffer, mask, or baked field. The search did not settle it | [Konsoll 2018, water at 31:26–32:10, reflection at 40:48](https://www.youtube.com/watch?v=6JcFbivo8dQ) — auto-generated captions, wording approximate |
| **Unreal Engine** (engine documentation) | `DepthFade` is *"used to hide unsightly seams that occur when translucent objects intersect with opaque ones"*; `SceneDepth` — *"Only translucent materials may utilize SceneDepth"*. Single Layer Water: *"The fully lit scene and depth are used as input to the Single Layer Water pass, and reading the buffers is how refraction and translucency is achieved"* | Depth-difference is the **engine's own** answer for water over opaque geometry. Separately, each water body has a *"Water Info Material — the material with which this water body renders into the Water Info Texture"*, i.e. Epic also ships a baked-field path | [Depth expressions](https://dev.epicgames.com/documentation/en-us/unreal-engine/depth-material-expressions-in-unreal-engine) · [Single Layer Water](https://dev.epicgames.com/documentation/en-us/unreal-engine/single-layer-water-shading-model-in-unreal-engine) · [Water Body Actors](https://dev.epicgames.com/documentation/en-us/unreal-engine/water-body-actors-in-unreal-engine) |

## Who did the opposite

**Crest and DREDGE both deliberately keep the shore off the screen depth buffer**, and each states a reason
the depth buffer structurally cannot meet:

- **Crest** needs the field for wave physics — *"waves will be affected by the seabed when the water depth is
  less than half of their wavelength"*. That is a world-space quantity over the whole ocean, including water
  behind the camera. A screen depth buffer holds only what is on screen this frame.
- **DREDGE** needs the field in gameplay code, to clamp wave height to zero at island edges so the boat is
  never beached. Nothing sampled in a fragment shader can do that.

A third, weaker data point on the failure mode: a Godot user trying depth-buffer edge detection for water —
*"It doesn't stay consistent, wherever I put the camera it will get distorted or curved, specially when doing
a close up."* Cause is the well-known one (raw depth is non-linear clip space and needs reconstruction), but
it is what the technique feels like when it goes wrong. — [godot#77798](https://github.com/godotengine/godot/issues/77798)

## Does a baked field give up the slope-varying band?

**A distance-to-coastline SDF does. A baked depth field does not — and nothing found here bakes distance.**

- A 2D signed distance to the coast polygon is **slope-blind by construction**: it knows how far a point is
  from the shore line and nothing about how deep the water is there. Band width becomes a constant.
- A baked **height/depth** field carries exactly the quantity the depth-buffer difference approximates —
  `sea_level − seabed_height` — only in world space and view-independent. Crest says so outright ("stores the
  terrain height, which can then be differenced with the sea level"); Boat Attack bakes the same thing as an
  orthographic depth tile. **Both keep the slope.**
- ⚠ For a coast that is a short skirt down to just under the water plane and then a **vertical wall**, the
  underwater slope is near-vertical everywhere, so the depth-buffer band would be near-constant-width anyway.
  On that geometry the two techniques converge, and the "natural variation" argument has nothing to vary on.

**What baked buys:** view-independent (the band does not swim or curve when the camera turns), covers
geometry outside the frustum, readable from the CPU, unaffected by the transparency rule below, and it works
where the depth texture is awkward or absent.
**What baked costs:** memory and a texel-size-vs-sharpness trade, a bake step in the pipeline, and static
geometry only — a beast or a boat in the water gets no foam ring from it (Crest's answer is to re-record
those objects every frame).

## Godot: is the depth texture available in the Compatibility renderer?

**Yes, since 4.1** — [PR #72361, "Incorporating the availability of screen and depth textures for the GLES3
backend", merged 2023-03-27, milestone 4.1](https://github.com/godotengine/godot/pull/72361).
Godot's docs document `hint_depth_texture` for 3D shaders with no per-renderer restriction; the one hint
that *is* Forward+-only is `hint_normal_roughness_texture`. —
[Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

Caveats, each with its source:

| Caveat | Where it bites | Source |
|---|---|---|
| Raw value is **non-linear clip-space depth** and must be reconstructed with `INV_PROJECTION_MATRIX` | Everywhere. The famous "Compatibility depth range is uselessly small" report was **closed as not planned** — maintainer clayjohn: *"You are reading the raw depth buffer values which are non-linear due to being in clip space. You need to linearize the depth buffer before using it for anything."* | [godot#101640](https://github.com/godotengine/godot/issues/101640) · [docs](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) |
| Reading `depth_texture` **inside a helper function** failed to compile in Compatibility: `error C1503: undefined variable "depth_buffer"`. Hit 4.4.1 | Fixed by [PR #110241](https://github.com/godotengine/godot/pull/110241), milestone **4.6**. On older builds, sample it inline in `fragment()` | [godot#109553](https://github.com/godotengine/godot/issues/109553) |
| Depth texture **plus 3D render scaling** spammed warnings in Compatibility — *"The depth texture still seems to work though"* | Fixed by [PR #111234](https://github.com/godotengine/godot/pull/111234), milestone **4.6** | same |
| MSAA + depth texture returned 0 everywhere — **Mobile renderer only**; the same report states *"Godot 4.4 rc2, compatibility renderer"* works with MSAA on | Fixed for Mobile in 4.6 | [godot#103425](https://github.com/godotengine/godot/issues/103425) |
| **Transparent materials never appear in `hint_depth_texture`.** Engine-wide, not Compatibility-specific | A transparent water plane cannot see itself (good), but nothing else transparent gets a foam ring either | [Spatial shaders reference](https://github.com/godotengine/godot-docs/blob/master/tutorials/shaders/shader_reference/spatial_shader.rst) |

**On 4.7 all four fixes above are already in.**

## What this does not settle

- **Bad North's mechanism.** Stålberg states the design rule ("borders, not fields") and nothing about how
  the highlight is computed. There is no Bad North shader post, no numbers, no source beyond the talk.
- **What Unreal's Water Info Texture actually stores.** Epic's docs name the texture and the material that
  renders into it, but the public pages fetched here never list its channels. The claim that it holds a
  `DistanceToShore` appears only in secondary summaries and was **not** verified against Epic's docs or source.
- **Godot 4.7 specifically.** The Compatibility answer rests on PR #72361 (4.1), issue #103425 confirming
  4.4 rc2 working, and two fixes landing in 4.6 — not on reading the 4.7 GLES3 rasteriser.
- **No shipped game was found that bakes a plain distance-to-coastline SDF** for shore foam. Every shipped
  baked field found here stores height or depth.
