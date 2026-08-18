# Findings already refuted — do not raise these again

**What this was**: a six-axis audit of the GDD and the first slice plan, run on 2026-08-17 **before `src/`
existed.** Its blockers, majors and open questions are **superseded** — the slice was built, the boat round
and the main loop shipped on top of it, and the user has played all three. Re-reading a pre-build audit as a
constraint is exactly the failure `CLAUDE.md` names about stale docs.

**What survives is this list**, and only this list: findings that were raised during that audit and **shown
to be wrong.** It is here so the next session does not spend a round re-deriving them.

⚠ **Being on this list means the finding was refuted at the time it was raised.** It does not mean the
subject is closed forever — if new measurement contradicts an entry, that is a new finding, and **the entry
gets edited here rather than argued elsewhere.**

---

- **"The plan does not know about the ranged-range asymmetry"** — it did, in its own adversarial section.
  The only real problem was **the refutation never propagating to the GDD**
- **"Sending only ranged soldiers is a pure dominant strategy"** — you get wiped on island 1 (bison detect
  radius 6). It is free **only when melee is there to shield**
- **"Take the plan out of `1.ready`"** — the six files and the probe are all buildable regardless. What was
  blocked was not starting but **calling it finished**
- **"Pin the dead-air pass line at 40% (or 50%)"** — **a line with no source.** The 61% / 25% figures were
  measured on **directly-controlled action games**, and the GDD had already written that the ratio is
  structurally higher in an autobattler
- **"Loading order is a constant"** — that does not follow from the disembark BFS rule (whoever boarded
  first stands nearer the dock)
- **"The entry-HP sweep reading WON everywhere is an artefact of the lion's area geometry"** — that sweep
  varied the **entry HP pool**, not the committed headcount `k`. `k` was never swept on island 3
- **"There are eight values the builder will have to ask back about"** — five already had answers
  (projectiles are instant · dock occupancy · detection drop-out · where constants live · what distance
  range is measured from). **Three remained**
- **"The Korean/English split in the disembark BFS is an implementation risk"** — the plan pinned
  `passable`, so the builder could not get it wrong. **Only the Korean GDD's wording needed fixing**
- **"Despot's Game's 100k is a SteamSpy owner estimate"** — it is a **sales figure** backed by the
  publisher's own announcement. Only the link needed changing
- **"The Warcraft III high-ground miss chance was also ranged-only"** — **not confirmed first-hand.**
  It has to be recorded as unverified, not corrected
- **"The GDD's «boats also disturb enemy detection» dies under the plan's rules"** — the firing targets are
  unchanged, so **the original reason (ranged enemies shoot the boats) still holds**
- **"The GDD uses «the Bad North structure where winning still hurts» as grounds"** — that paragraph had
  already been voided by a refutation box below it, and the multiplication itself was deleted. **It was
  already a dead sentence**
- **"The Mechabellum row's conclusion collapses"** — demoted to a statement of fact, **the conclusion
  (fixed placement is not pure) survives intact**
- **"The Brood War numbers were wrong, so «do not put numbers on the layer» collapses"** — that section's
  real grounds are **StarCraft II removing random miss outright**, and the first round has no layer at all
- **"Having no dead-air pass line is a blocker"** — the blocker was that **the instrument measures a
  different quantity.** What the line's value should be is the user's call, made looking at the screen
