# How does RimWorld name and structure positive vs negative pawn traits?

**It does not name them. RimWorld has no positive/negative flag anywhere — one def holds both ends of a
spectrum as signed integer `degree`s, the generator draws purely by `commonality`, and the Character tab
shows one flat list whose tooltip prints signed numbers.**

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| Ludeon / `TraitDef` | Fields are `degreeDatas`, `conflictingTraits`, `exclusionTags`, `conflictingPassions`, `forcedPassions`, `required/disabledWorkTypes`, `required/disabledWorkTags`, `commonality`, `commonalityFemale`, `allowOnHostileSpawn`, `canBeSuppressed`. **No `isGood`, no `isPositive`, no goodness field** | A trait's "good or bad" is never data — it is only the sign of the numbers it carries | https://github.com/Chillu1/RimWorldDecompiled/blob/master/RimWorld/TraitDef.cs |
| Ludeon / `TraitDegreeData` | One degree carries `label`, `degree` (int), `commonality` (float), `statOffsets`, `statFactors`, `skillGains`, `socialFightChanceFactor`, `hungerRateFactor`, `painOffset`/`painFactor`, `aptitudes`, `abilities`, mental-state and thought lists. Again **no positive/negative field** | The whole effect surface is signed offsets and factors. A negative `statOffset` IS the negativity | https://github.com/Chillu1/RimWorldDecompiled/blob/master/RimWorld/TraitDegreeData.cs |
| Ludeon / spectrum defs | The core file is literally named **`Traits_Spectrum.xml`**. Ludeon's own translation repo shows `Industriousness` holding `industrious`, `hard worker`, `lazy`, `slothful` under ONE def; the same file holds `Nerves` (iron-willed / steadfast / nervous / volatile), `Neurotic`, `Prettiness` (beautiful / pretty / ugly / staggeringly ugly), `SpeedOffset`, `NaturalMood`, `DrugDesire`, `PsychicSensitivity`, `TemperaturePreference`, `ShootingAccuracy` | One def = one axis. Both ends are degrees of the same def, so they can never be rolled together and conflict-checking is free | https://github.com/Ludeon/RimWorld-Portuguese/blob/master/DefInjected/TraitDef/Traits_Spectrum.xml |
| Ludeon / `Trait` | `Trait` stores only `def` + `degree`; `CurrentData => def.DataAtDegree(degree)`. `TipString` prints `skillGain.amount.ToString("+##;-##")`, stat offsets via `ValueToStringAsOffset`, factors via `ToStringAsFactor` | **The + / - in the tooltip is number formatting, not a category.** The UI never says "this is a bad trait" | https://github.com/Chillu1/RimWorldDecompiled/blob/master/RimWorld/Trait.cs |
| Ludeon / `PawnGenerator` | `private static readonly IntRange TraitsCountRange = new IntRange(1, 3);` then `GenerateTraitsFor` loops `RandomElementByWeight(tr => tr.GetGenderSpecificCommonality(pawn.gender))`, and `RandomTraitDegree` picks the degree by `dd.commonality` | **1–3 traits, drawn purely by commonality. No good/bad balancing.** The only quality-ish guard rejects a trait that would push the mental-break threshold above 0.5; everything else rejected is conflicts, exclusion tags, work tags, kind/backstory disallows | https://github.com/Chillu1/RimWorldDecompiled/blob/master/Verse/PawnGenerator.cs |
| Ludeon / `CharacterCardUtility` | Traits draw as one `GenUI.DrawElementStack` of `pawn.story.traits.TraitsSorted` under a single "Traits" heading; hover tooltip is `trLocal.TipString(pawn)`. `TraitsSorted` sorts by `sourceGene != null` then `Suppressed` — **never by goodness** | One chip row, no grouping, no colour by good/bad (colour is only grey-for-suppressed and gene-colour) | https://github.com/Chillu1/RimWorldDecompiled/blob/master/RimWorld/CharacterCardUtility.cs |
| RimWorld wiki | Prose says "some are beneficial, some are harmful", and "most humans have 1-3 traits" plus a possible sexuality trait; children gain one per growth moment (ages 7, 10, 13) | **The good/bad split is community prose, not a game label** | https://rimworldwiki.com/wiki/Traits — ⚠ direct fetch blocked (Cloudflare 403); wording read via a search excerpt of that page, not the page itself |

## Who did the opposite

**Darkest Dungeon labels them in-game and gives each side its own slots.** A hero holds "a maximum of ten
quirks — five positive and five negative"; the Sanitarium removes one negative or reinforces one positive
per week, and positive treatment costs more. Stage Coach recruits arrive with at least one positive and
one negative. https://darkestdungeon.wiki.gg/wiki/Quirks_(Darkest_Dungeon)

**Project Zomboid goes further — the split IS the character-creation economy.** Positive traits cost
points, negative traits refund them, and you cannot start until the budget (default 8) is covered.
https://projectzomboid.fandom.com/wiki/Traits — ⚠ the official pzwiki.net refused a fetch (403); this is
the Fandom mirror.

## What this does not settle

- **The exact core `degree` integers** (Industriousness = Slothful −2 / Lazy −1 / Hard Worker +1 /
  Industrious +2) are NOT confirmed here. Core `Defs/TraitDefs/*.xml` is not published online, and the
  translation repos key by list index (`degreeDatas.0..3`), not by degree value. The code proves the field
  is a signed int and that both ends live in one def — the specific numbers stay unverified.
- **Whether any tooltip value is ever coloured red/green** — `TipString` builds a plain string; colouring
  would come from `ColoredText` elsewhere and was not traced.
- **Oxygen Not Included** was not checked; Darkest Dungeon and Project Zomboid carry the opposite case.
