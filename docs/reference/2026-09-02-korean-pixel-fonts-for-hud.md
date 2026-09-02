# Which free pixel font can draw Hangul names on a pixel HUD, and can PixelLab generate one?

**Answer in one line: Galmuri, Neo둥근모, 물마루 and DOSGothic each carry all 11,172 syllables under a free
licence (measured, not claimed); PixelLab's font generator makes an 80-glyph Latin atlas only and cannot
make Hangul.**

## Cases

| Font | Licence | Pixel size | Hangul syllables | Source |
|---|---|---|---|---|
| **Galmuri** (갈무리) | SIL OFL 1.1 | 14=15px · 11=12px · 9=10px · 7=8px, plus Mono and 11 Bold/Condensed | **11,172 — measured** in every face of release v2.40.4 with fontTools | [repo](https://github.com/quiple/galmuri) · [README table](https://raw.githubusercontent.com/quiple/galmuri/main/README.md) · [v2.40.4 release](https://github.com/quiple/galmuri/releases/tag/v2.40.4) |
| **Neo둥근모** (NeoDunggeunmo) | SIL OFL 1.1 | TTF converted from the 16x16 DOS bitmap 둥근모꼴 (김중태, public domain) | **11,172 — measured** in neodgm.ttf v1.601 | [repo](https://github.com/neodgm/neodgm) · [English README](https://github.com/neodgm/neodgm/blob/main/README.en.md) |
| **물마루 / Mulmaru** | SIL OFL 1.1 | 12px (same size as Galmuri11); proportional + Mono | 11,172 (README: 11,937 glyphs total, of which 11,172 Hangul syllables) | [repo](https://github.com/mushsooni/mulmaru) |
| **DOSGothic** (도스고딕) | MIT, attribution requested by the author | 16x16 BDF; TTF/OTF/woff2 mirror | **11,172 — measured** by counting `ENCODING` in DOSGothic-16.bdf (24,869 glyphs total) | [source repo](https://github.com/hurss/fonts) · [BDF](https://github.com/hurss/fonts/blob/master/bdf/DOSGothic-16.bdf) · [web mirror](https://github.com/fonts-archive/DOSGothic) |
| **Silver** (Poppy Works) | CC BY 4.0; a direct licence is required if production budget > $100,000 USD | not stated on the page | **Partial** — the author's own block list says "Hangul Syllables (partial)"; Hangul was still being added glyph-by-glyph in the CJK devlogs | [itch page](https://poppyworks.itch.io/silver) · [supported blocks thread](https://itch.io/t/488011/currently-supported-unicode-blocks) · [CJK Update #8](https://poppyworks.itch.io/silver/devlog/220940/cjk-update-8) |
| **Ark Pixel Font** (方舟像素字体) | OFL 1.1 / MIT | 10 · 12 · 16px | **0** — jamo only; the project's own stats say Hangul syllables 0 / 2350 at both 12px and 16px | [repo](https://github.com/TakWolf/ark-pixel-font) · [12px stats](https://github.com/TakWolf/ark-pixel-font/blob/master/docs/info-12px-proportional.md) |

### Shipped games

| Game | Font | Source | Strength |
|---|---|---|---|
| WORLD OF HORROR | Silver | [devlog by the font's own author](https://poppyworks.itch.io/silver/devlog/119863/world-of-horror-using-silver) | primary |
| SIGNALIS · Gunbrella · Infernax · Crypt of the NecroDancer · Slave Zero X · BLUE REVOLVER | Silver | [font's own itch page](https://poppyworks.itch.io/silver) | author's claim |
| Stardew Valley, mobile (iOS/Android) Korean build | 둥근모꼴 | [namu.wiki](https://namu.wiki/w/Stardew%20Valley) | wiki, secondary |
| Homunculus · BatteryNote | Galmuri | [note.com article by Masa Kei](https://note.com/masa_kei/n/neadfac5b9d10?hl=en) | secondary — **not confirmed**: [BatteryNote's Steam page](https://store.steampowered.com/app/3005930/BatteryNote/) carries no font credit |
| Hotel Sowls | DOSGothic | [same note.com article](https://note.com/masa_kei/n/neadfac5b9d10?hl=en) | secondary, unconfirmed |

### PixelLab's font generator — Latin only

The live v2 OpenAPI spec (`https://api.pixellab.ai/v2/openapi.json`, `POST /generate-font-pro`) states:
*"Produces an 80-glyph atlas plus a ready-to-use TrueType (.ttf) font with A-Z, a-z, digits 0-9, and common
game-UI punctuation."* Its `GenerateFontProRequest` schema is `additionalProperties: false` with exactly
five fields — `description`, `weight`, `glyph_px` (8/16/32/64), `seed`, `font_name` — and no charset or
language field; the description adds that the glyph layout comes from *"a bundled per-weight reference
atlas"*. The v1 spec has no font endpoint at all. **80 glyphs cannot hold 11,172 syllables.**
No statement about Hangul was found in PixelLab's own changelog or Discord either way.

## Who did the opposite

**Stardew Valley** ships Korean on PC and Switch in **산돌 미생체**, a smooth non-pixel face, over pixel art.
Recorded reaction ([namu.wiki](https://namu.wiki/w/Stardew%20Valley)): the build wires up only ~1,368
syllables of the 11,172, so text visibly breaks — 무지갯빛 파편 renders as 무지*빛 파편 — and players kept
using the fan patch, then shipped font-fix patches ([Nexus mod](https://www.nexusmods.com/stardewvalley/mods/11708),
[noonnu writeup](https://noonnu.cc/en/posts/3774)). The same game's **mobile** build used the pixel font
둥근모꼴 instead, which the same page records as 「가독성은 호불호가 갈리지만 게임 특유의 도트 그래픽과의
조화는 뛰어난 편」 — readability is divisive, but it matches the dot graphics well.

## What this does not settle

- **Galmuri in a shipped game is unconfirmed.** No primary source (game credits, dev post) was found; the
  only evidence is one Japanese blog article. Same for DOSGothic / Hotel Sowls.
- **Silver's exact Hangul count was not measured** — itch downloads need a session, so the "partial" label
  is the author's word, not a measurement.
- **Nothing here measures rendering in Godot 4** — hinting off, integer scaling and `FontFile` MSDF settings
  were not tested.
