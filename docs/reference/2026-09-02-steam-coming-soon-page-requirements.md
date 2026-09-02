# What must exist before a Steam "Coming Soon" store page can go live?

**Four capsules, five 1080p gameplay screenshots, a description, five tags, the content survey, an
internal release date, a $100 app fee paid 30+ days earlier — and 7 business days of Valve review.**

All rows read 2026-09-02. Steamworks partner docs are the primary source; where Valve states no number,
the row says so.

## Graphical assets — required

| Asset | Size | Used for | Source |
|---|---|---|---|
| Header capsule | 920 x 430 | Top of store page, Recommended For You, Big Picture, Daily Deals | https://partner.steamgames.com/doc/store/assets/standard |
| Small capsule | 462 x 174 | Search results, top sellers, new releases. 120x45 and 184x69 are auto-generated | same |
| Main capsule | 1232 x 706 | Store home page carousel | same |
| Vertical capsule | 748 x 896 | Front page during seasonal sales | same |
| Library capsule | 600 x 900 | Client library overview and collections | https://partner.steamgames.com/doc/store/assets/libraryassets |
| Library header | 920 x 430 | Client library, Recent Games | same |
| Library hero | 3840 x 1240 | Top of library details page. Safe area 860 x 380 | same |
| Library logo | 1280 wide and/or 720 tall, PNG with transparency | Overlay on the hero | same |
| Shortcut icon | 256 x 256, .ico or .png | Desktop shortcut | https://partner.steamgames.com/doc/store/assets |
| App icon | 184 x 184, .jpg | Client chrome | same |

**Optional**: page background 1438 x 810 (auto-generated from the last screenshot if omitted);
bundle header 707 x 232. Source: https://partner.steamgames.com/doc/store/assets/standard

## Graphical asset rules Valve enforces

From https://partner.steamgames.com/doc/store/assets/rules (in force since Sept 1 2022):

- "Content on base graphical asset capsules on Steam is limited to game artwork, the game name, and any
  official subtitle."
- "Capsule images must contain a readable product logo/name" — and the small capsule's logo must be
  legible at the smallest generated size, so the logo should nearly fill it
  (https://partner.steamgames.com/doc/store/assets/standard)
- No review scores. No award names, symbols or logos. No discount marketing copy. No text promoting a
  different product. "No other miscellaneous text."
- Library hero: "should only contain artwork. There should be no words at all."
- All capsules must be PG-13 appropriate.
- Temporary promotional text is allowed only through Artwork Overrides, capped at one month, localized.

## Screenshots

- **Minimum five.** 1920 x 1080 minimum, 16:9.
- Gameplay only — "no concept art, cinematics, awards, marketing copy, or descriptions".
- **At least four must be marked suitable for all ages.**
- Under 5MB each; Valve asks the whole screenshot + GIF set stay under 15MB.
- Source: https://partner.steamgames.com/doc/store/assets/standard and
  https://partner.steamgames.com/doc/store/page/description

## Trailer — Valve's own pages disagree

| Page | What it says |
|---|---|
| Coming Soon | needs "a set of branding images, written description, and ideally a gameplay trailer" — https://partner.steamgames.com/doc/store/coming_soon |
| Trailers | "As part of the release process on Steam, you will be required to upload a trailer for your product." — https://partner.steamgames.com/doc/store/trailer |

Chris Zukowski (How To Market A Game, 2025-03-10) states flatly: "Valve removed the requirement to upload
a trailer to get your Steam page approved." —
https://howtomarketagame.com/2025/03/10/when-should-i-post-my-steam-coming-soon-page/

⚠ **Nobody found publishes a controlled measurement of what launching without a trailer costs.** Zukowski
argues from credibility, not from numbers, and says so.

Spec when you do upload one: up to 1920 x 1080, 30/29.97 or 60/59.94 fps, 5,000+ Kbps, .mov/.wmv/.mp4,
H.264 video + AAC audio preferred, audio at 44kHz or 48kHz, 16:9 preferred (4:3 accepted). No length
requirement is stated. https://partner.steamgames.com/doc/store/trailer

## Text

| Field | Limit | Source |
|---|---|---|
| Short description | Valve says only "limited to a few hundred characters", plain text, no formatting | https://partner.steamgames.com/doc/store/page/description |
| Short description, in practice | ~300 characters / 6 lines, truncated beyond | secondary only — https://steamdatasuite.com/steam-best-practices-short-description/ |
| About This Game | **no character limit stated anywhere found** | — |

Both fields forbid: outbound links, images that mimic Steam UI, and advertising other products on Steam.
Valve's review criterion is that the description be "detailed, coherent, and free of external links"
(https://partner.steamgames.com/doc/store/review_process).

## Tags

**At least 5 required before launch**, up to 20 recommended; only the top 20 count for visibility.
"We began requiring at least 5 tags be applied to a title before its launch on Steam."
https://partner.steamgames.com/doc/store/tags

## The rest of the gate

| Thing | Rule | Source |
|---|---|---|
| App fee | $100 USD per product | https://partner.steamgames.com/doc/gettingstarted/onboarding |
| Waiting period | "A 30-day waiting period between when you paid the app fee and when you can release your game" | same |
| Bank, tax, identity | must be complete | same |
| Content survey | must be completed before submitting store page and build for review; generates the regional age ratings shown at release | https://partner.steamgames.com/doc/gettingstarted/contentsurvey |
| Release date | an exact internal date is mandatory; the store shows one of five forms — exact date, month+year, quarter, year, or "Coming Soon" | https://partner.steamgames.com/doc/store/release_dates |
| Date changes | "You can change the release date of your game up to two weeks prior to your specified date... Once this visibility starts, you can no longer adjust your release date" | same |
| Weekends | the date picker hides weekends | same |
| Coming Soon duration | "For new products, you must have a Coming Soon page up for at least two weeks before releasing" | https://partner.steamgames.com/doc/store/coming_soon |
| Store page editor | "You will need to complete the sections marked with a (*) in each tab"; the required list is the checklist on the product landing page | https://partner.steamgames.com/doc/store/page |

## Review

- "Our review of your store presence typically takes 3-5 business days to complete, but you'll want to
  submit your page for review at least 7 business days before you want it live."
- The four things Valve checks: only launch-available features on the page; capsules carry a readable
  title or logo; screenshots are gameplay only; description detailed, coherent, no external links.
- "We'll send you any feedback if necessary."
- Source: https://partner.steamgames.com/doc/store/review_process

Flow: complete the checklist → **Mark As Ready For Review** → Valve approves → **Post as Coming Soon**.
https://partner.steamgames.com/doc/store/coming_soon

## Who did the opposite

**Valve itself, on trailers.** The trailers page still says a trailer is required as part of release;
the Coming Soon page says "ideally". A third party who works with the dashboard daily says the approval
requirement was removed. The dashboard checklist is the only authority that settles it, and it is behind
a login.

## What this does not settle

- **Exact short-description limit** — Valve publishes no number. 300 is secondary.
- **About This Game limit** — no number found in any source.
- **Whether library assets block Coming Soon approval.** The asset index marks them Required, but the
  library asset page notes they "only display once the store page is published". Whether Valve blocks
  review on a missing library hero is not documented.
- **Whether the content survey blocks the Coming Soon post specifically**, or only the release review.
  Valve's wording ties it to "the Review Process", which is the same review.
- **Rejection rate and the most common rejection reasons.** Valve publishes neither, and no dataset was
  found.
- **System requirements** are a store page field but no page found states them as a required field with
  a spec.
