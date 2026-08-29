# Where can a solo project legally get free flat-shaded low-poly 3D props?

**Answer in one line.** Kenney, KayKit and Poly Pizza are the three that actually hold flat-shaded
low-poly props and let you download without an account — and **Quaternius stopped being CC0 on
2026-08-28**, one day before this note was written.

⚠ **This search was stopped part-way.** The round moved to 2D pixellab cards for props, so no 3D prop is
being sourced. What is below is the licence reading that was already done; the two open questions at the
bottom were never answered.

## Cases

| Who | Licence, as the site words it | Account to download? | Format | Style | Nature props? | URL |
|---|---|---|---|---|---|---|
| **Kenney** | "all game assets on the asset pages are public domain licensed (CC0)" · "Attribution is not required, but if you choose to give credit you can do so by mentioning 'Kenney'. Do not use our logo" | **No** — a direct zip behind "Continue without donating…" | OBJ + MTL, plus a Unity package (read from search results, not from the page itself) | Flat-shaded low-poly | **Yes** — Nature Kit, 330 files: trees, rocks, stones, terrain, plants | [kenney.nl/support](https://kenney.nl/support) · [kenney.nl/assets/nature-kit](https://kenney.nl/assets/nature-kit) |
| **Quaternius** | ⚠⚠ **No longer CC0.** "Quaternius Asset License (QAL) v1.0 · Last updated: 8/28/2026" — "You can use these assets, free of charge, in personal, educational, and commercial games and other projects, with no credit required. You just can't resell or redistribute the assets themselves as assets." Section 3 forbids reselling or redistributing the Assets as standalone products | No (Google Drive, or one file via Patreon) | Not read | Flat-shaded low-poly | **Yes** — Ultimate Nature Pack, Stylized Nature MegaKit, Simple Nature Pack among ~80 packs | [quaternius.com/license.html](https://quaternius.com/license.html) |
| **KayKit** (Kay Lousberg, itch.io) | "CC0 so you can use them freely. But please don't resell unmodified copies or claim them as your own." ⚠ The second sentence is **not part of CC0** — it is a request, not a term | No | FBX, GLTF, OBJ | Flat-shaded low-poly, one 1024 gradient atlas | Partly — Medieval Hexagon has 200+ tiles/buildings/props free; Resource Bits 75+ | [kaylousberg.itch.io/kaykit-medieval-hexagon](https://kaylousberg.itch.io/kaykit-medieval-hexagon) |
| **Poly Pizza** | **Mixed per model — CC0 1.0 or CC-BY 3.0.** Every model page names its own; bundle "credits" pages auto-generate the attribution list | **No** for the web download; **yes, an API key** (account) for the API | glb | Low-poly — it hosts the Google Poly archive | Yes, scattered — it is a search index, not a coherent kit | [poly.pizza](https://poly.pizza/) · [API docs](https://poly.pizza/docs/api/v1.1) · [example credits page](https://poly.pizza/l/F5iKT4YDl3/credits) |
| **OpenGameArt** | Accepts **CC0, CC-BY 3.0/4.0, CC-BY-SA 3.0/4.0, OGA-BY 3.0/4.0, GPL 2.0/3.0**. On multi-licensed works: "You must follow only one of the licenses." Suggested credit line: `[asset name] by [author name] licensed [license]: [asset url]` | Not stated on the FAQ | Varies per submission | Mixed; Kenney's kits are mirrored here | Yes, unevenly | [opengameart.org/content/faq](https://opengameart.org/content/faq) |
| **Poly Haven** | CC0 — "You can use our assets for any purpose, including commercial work. You do not need to give credit or attribution when using them (although it is appreciated)." | No | Not read | ⚠ **Photoreal PBR, not low-poly.** The licence page does not say so; this row's style claim was not verified against the model catalogue | Yes, but photoreal | [polyhaven.com/license](https://polyhaven.com/license) |
| **ambientCG** | CC0 — "All assets are released under the Creative Commons CC0 license, making them free to use without attribution - even in commercial circumstances." | Not stated (a "Supporter Login" exists for patrons) | Not read | **Photoscanned / photoreal** — the site's own techniques are listed as Photogrammetry and Photometric Stereo. Wrong style | Mostly materials and HDRIs; some scanned objects | [ambientcg.com](https://ambientcg.com/) |
| **Sketchfab** | Creative Commons, per model; 700,000+ downloadable | ⚠ **Yes** — the Download API needs a per-user OAuth bearer token: `-H 'authorization: Bearer {token}'` | Varies | Mixed — everything from photoscans to low-poly | Yes | [sketchfab.com/developers/download-api](https://sketchfab.com/developers/download-api) |
| **Godot Asset Library** | Open-source licences (MIT, GPL, Boost). "The license listed on the asset library must match the license in the repository", and the repo must carry a `LICENSE` file with copyright years | No | Repo zips | ⚠ **Mostly addons, not prop meshes** | Effectively no | [docs.godotengine.org — Submitting to the Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html) |

## Who did the opposite

**Quaternius left CC0.** Every third-party list, the artist's own older itch.io pack pages, and a 2022
tweet still say CC0; the licence page served on 2026-08-29 says QAL v1.0, dated the day before.
⚠ **A copy downloaded earlier may carry a different licence from a copy downloaded now** — record which,
per file, at download time. The QAL's "no credit required" is friendlier than CC-BY, but it is **not**
public domain: it forbids redistributing the assets as assets, which CC0 permits.

**itch.io has no site-wide licence.** Each pack page states its own, and KayKit's adds a plain-English
request on top of CC0. A pack page is the source; the storefront is not.

## What this does not settle

- **The attribution trap.** Where a CC-BY credit must appear in a shipped game, and what happens when one
  pack mixes licences, was searched but not answered. Nothing found beyond forum opinion — **no case of a
  solo dev publicly burned by it was located**, which is not the same as none existing
- **Refitting a stranger's mesh to a hand-built style** — decimation, stripping textures, re-assigning
  flat vertex colours, rescaling to a unit grid, re-origining to the foot. **Not searched at all** before
  the stop
- **Formats and account-gating for Quaternius, Poly Haven and ambientCG** were not read from their own
  pages
