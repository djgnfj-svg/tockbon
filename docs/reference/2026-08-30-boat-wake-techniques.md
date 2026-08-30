# How do shipped games actually render a boat wake?

**Answer in one line.** There is no single shipped mechanism — the two that carry a *persistent* trail are
a **buffer the water shader samples** (Unity HDRP water decals, Godot's compute-texture demo) and an
**analytic wake evaluated in the water's own vertex program** (Triton); ribbons, stamps, particles and
attached V-meshes are all real but each fails on a specific, documented axis.

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Rare — Sea of Thieves** | FFT ocean (Tessendorf). Foam "is also added around objects that intersect the water surface within a camera centered window using depth buffer comparisons. We progressively blur the result of the foam buffer with feedback to simulate the foam dispersing" | Shipped. **The buffer is seeded by depth intersection, not by a boat painting a trail** — so it produces a local foam ring, not a wake | [SIGGRAPH '18 Talks, "The Technical Art of Sea of Thieves"](https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf) |
| **Unity — HDRP Water System** | Two separate things for one boat: a **water decal** for "local foam in the wake of a GameObject, such as a sailing boat", and a **Bow Wave deformer** parented to the boat | Shipped engine feature, 2022 LTS / 2023.1 onward | [Deform a water surface (HDRP 17.0)](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/water-deform-a-water-surface.html) · [Unity blog](https://unity.com/blog/engine-platform/new-hdrp-water-system-in-2022-lts-and-2023-1) |
| **Unity — Trail Renderer** | The manual names the boat wake as *the* worked example: Start Width 1, End Width 2 | Ships in every Unity version; breaks on sharp turns (below) | [Unity Manual: Trail Renderer](https://docs.unity3d.com/530/Documentation/Manual/class-TrailRenderer.html) |
| **Sundog — Triton ocean SDK** | Kelvin wakes, bow wake, propeller wash and spray, "applied in the same vertex program as everything else for the water"; "individual waves are simulated, leading to realistic waves on ships moving on any arbitrary, curved path"; extra wash segments generated during turns, LOD by camera distance | Commercial middleware, shipping since 2.3 (2013) | [Ship Wakes in Triton 2.3](https://sundog-soft.com/2013/07/ship-wakes-in-triton-2-3-kelvin-wakes-bow-wakes-propeller-wash-and-more/) · [Triton for Unity](https://sundog-soft.com/features/ocean-and-water-rendering-with-triton/unity-water-effects-with-triton-for-unity-pro/) |
| **Ubisoft — AC IV: Black Flag** | Buoyancy spheres "measure the velocity of the ship entering the water at that location, it tells the particle splashes when and how big to spawn" | Shipped 2013. Particles handle *splash*, not the trail | [simonschreibt, Black Flag Waterplane](https://simonschreibt.de/gat/black-flag-waterplane/) |
| **Godot (official)** | `compute/texture` demo: a compute shader writes height data into a texture that the material shader samples | Official demo project, Godot 4 | [godot-demo-projects/compute/texture](https://github.com/godotengine/godot-demo-projects/tree/master/compute/texture) |
| **James Finlay — Godot boat wake devlog** | Built a boat wake on that demo's compute shader: physics → submit disturbance → upload texture → dispatch → render with combined heightmap | Works, but **the wake separates from the boat once Gerstner waves are on**, because Gerstner distorts x/z while the compute buffer only handles y; artifacts where waves reach the texture edge | [Devlog: Godot Boat Wake](https://jfinlay.substack.com/p/devlog-godot-boat-wake) |
| **Namey5 — godot-interactive-water** | SubViewport ping-pong: "a ViewportTexture cannot reference its own Viewport, so we need a nested Subviewport to get working double-buffering" | Godot 4.3, works; author states "Simulation is framerate and resolution dependent" and "Configuration is limited and painful — I've tuned the defaults to work but it breaks easily" | [GitHub](https://github.com/Namey5/godot-interactive-water) |
| **Roblox community standard** | A **Beam** with low `width0`, high `width1` (funnel shape), transparency 0→1, scrolling seamless texture | Documented tutorial. Limit named: "Wakes are triangle-shaped ... we want our wake to scroll, and if its a triangle it won't be seamless" — fixed by mirroring/blending the texture | [Roblox DevForum](https://devforum.roblox.com/t/boat-wake-creation-and-tutorial/2842617) |
| **Epic — Niagara Fluids** | Grid2D shallow-water simulation for character/vehicle water interaction | Official learning path and tutorial, UE5 | [Shallow Water Simulation with Niagara Fluids](https://dev.epicgames.com/community/learning/tutorials/Ddwx/unreal-engine-shallow-water-simulation-with-niagara-fluids) |

## Who did the opposite

**Sea of Thieves ships with no persistent boat wake at all** — the flagship pirate game, with world-class
water tech, and players have been asking for a trail since launch across at least five forum threads:
[no wake behind the ship](https://www.seaofthieves.com/community/forums/topic/53630/no-wake-behind-the-ship) ·
[Missing: Ships trail](https://www.seaofthieves.com/forum/topic/66269/missing-ships-trail) ·
[Ship trails / wash](https://www.seaofthieves.com/community/forums/topic/51039/ship-trails-wash) ·
[Do You Want Ship Wakes?](https://www.seaofthieves.com/community/forums/topic/65994/do-you-want-ship-wakes) ·
[(graphics suggestion) Ships with ship wake](https://www.seaofthieves.com/community/forums/topic/139734/graphics-suggestion-ships-with-ship-wake-immersion-100).
⚠ **These pages are behind an Azure WAF and could not be opened directly** — read only through the search
index. The URLs and titles are verified; the individual player quotes are not.

**This is consistent with the SIGGRAPH talk, not contradicted by it.** Rare's foam is generated *around
intersecting geometry* and then blurred with feedback. That gives a short-lived ring at the hull. It is
not a history of where the ship has been, and nothing in the published technique would produce one.
**What it bought them**: one foam system that works identically for ships, rocks, players and the kraken,
with no world-space trail buffer to page around an open world.

**The second opposite is the Roblox beam**: a fixed funnel rigidly attached behind the hull. It does not
lag, curve, or persist through a turn — visibly wrong up close, and correct enough at distance that it is
the community's default answer.

## The far end of the scale, named with a source

Full fluid simulation for ship wakes is **offline research, not games**: *Ships, Splashes, and Waves on a
Vast Ocean* (Huang, Qu, Tan, Zhang, Michels, Jiang) couples a FLIP domain with an adaptively remeshed
Boundary Element Method domain — [arXiv:2108.05481](https://arxiv.org/abs/2108.05481). FFT ocean
(Tessendorf 2001) is *not* automatically the wrong end — Sea of Thieves' shipped ocean is FFT — but the
FFT surface is not what makes the wake in any case found here.

## What this does not settle

- **Bad North, Sailwind, Windbound, Raft, Valheim, Dredge, Wind Waker**: no developer-authored source
  describing their wake technique was found. Dredge has a developer water breakdown
  ([Unity](https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror)) but the searchable
  summary covers wave height painting, not wakes
- **Kainga** has a devlog titled ["Making Wakes"](https://www.kaingagame.com/devlog/making-wakes) that
  would likely be the closest stylised-low-poly match; **the site's TLS handshake fails and it could not
  be read**
- **Decal stamp overlap**: no source found stating how shipped titles stop overlapping foam quads from
  double-darkening. The max-blend-into-a-buffer answer is inference, not a citation
- **Orthographic cameras specifically**: no source found that discusses wake technique choice as a
  function of camera projection
