# Billboarded 2D sprites in a 3D world — the checklist, and where this game actually stands

**Brought in by the user on 2026-08-30**, translated from their own message. **The right-hand column is
this repo audited against it the same day**, read out of `src/view/field_view.gd`, `src/look.gd`,
`project.godot` and the `.import` files.

⚠ **The audit is a snapshot.** `field_view.gd` and `look.gd` were being edited by another agent while it
was taken — re-read before acting on a row.

## The checklist

| Item | What goes wrong without it | The fix | **Where this game stands** |
|---|---|---|---|
| **Billboard axis** | It spins on every axis and reads as a paper doll | Y-axis billboard only | ⚠ **`BILLBOARD_ENABLED`, not `BILLBOARD_FIXED_Y`** — full billboard |
| **Pixel density (PPU)** | Sprite resolution and terrain texels disagree and sit apart | Match sprite PPU to world texel size | **N/A as built** — the terrain carries no texture, it is vertex-coloured low poly. One 조각 is 1 world unit and a sprite texel is 1/40 |
| **Filtering** | Smeared and blurry | Point/nearest, mipmaps OFF, compression OFF | ✅ **All three.** `TEXTURE_FILTER_NEAREST`, `mipmaps/generate=false`, `compress/mode=0` |
| **Ground contact** | The body floats | A shadow under the feet, pivot at the feet | ✅ **A ground shadow went in 2026-08-28** on the user's own line 「동그라미정도해줘」, and sprites are placed at the body's feet |
| **Alpha** | Sorting breaks and it sinks into the terrain | Alpha clip (cutout), depth write ON | ✅ **`ALPHA_CUT_DISCARD`** |
| **Light response** | The scene is dark and only the character is bright | Normal map, or at least the same ambient/fog/grade | ⚠⚠ **`shaded = false`. Bodies take no light at all.** A wolf normal map was baked and never attached — ticket 50 |
| **Camera angle** | The angle the art was drawn at disagrees with the scene | Fix the camera pitch and draw to it | ⚠ **The pitch is NOT fixed** — `CAM_PITCH_MIN_DEG` 20 to `CAM_PITCH_MAX_DEG` 80, in 5° steps |
| **Number of facings** | Only a side view, so turning looks wrong | Four at minimum, eight if affordable | ⚠ **Four exist on disk for the wolf; the code's table has two slots (left/right)** — ticket 25 |
| **Perspective** | A perspective camera distorts the sprite | Orthographic, or a low FOV | ✅ **Orthographic** |

## The three most often missed

| | The claim | **Where this game stands** |
|---|---|---|
| **Pixel snapping** | A smoothly moving camera makes the pixels crawl. Render to a low-res target and upscale | ⚠ **Not done.** `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` are on, but those are the 2D canvas layer — **the bodies are `Sprite3D` and no 3D render-target downscale is configured** |
| **One VFX style** | Pixel characters with 3D particle effects break at exactly that seam. Make the effects sprite sheets too | ⚠ **The effects are `ImmediateMesh` geometry**, not sprite sheets. They are unshaded flat-coloured marks rather than particle systems, so the seam is smaller than the general case — but it is the flagged one |
| **Hold the terrain's detail down** | Too fine a background makes the 2D look poor beside it | ✅ **Low poly, flat/vertex colour, no texture.** This one the game already obeys by construction |

## What the audit says in one line

**Filtering, alpha, ground contact, perspective and terrain restraint are already right.** **The three
that are not are the billboard axis, the bodies taking no light, and the camera pitch being free** — and
the facings gap is already ticket 25.
