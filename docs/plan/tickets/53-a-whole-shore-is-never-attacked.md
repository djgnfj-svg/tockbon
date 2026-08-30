Type: grilling
Status: open

# 섬 한쪽에 배가 영영 안 온다

## Measured 2026-08-30

**86 shore 조각. 61 in the beach ring. 25 are never visited by any boat** — and they are not scattered:

- **The whole southern spit** — both long edges of that bar, plus the block at (8–9, 16–17)
- **The satellite island** at (20–21, 22–23)

**The beasts come to the main rectangle's north, west, east and south-west corner, and to nothing else.**

## Why they are excluded — three reasons, and only one is a defect

1. **The satellite** has no 4-way link to the mainland. A wolf landing there could never walk to the keep.
   ⚠ **Correctly excluded, and it stays excluded whatever is decided.**
2. **Six 조각 where `seaward_at` points ALONG the coast** rather than out to sea, so a hull's width has
   nowhere to stand. ⚠ **That is the bearing rule, not the island's shape.**
3. **The rest** cannot be reached from 24 조각 out without crossing land.

## The fork

- **Leave it** — the southern spit is a quiet flank by design. ⚠ **Then say so out loud**, because it
  changes where a defender ever needs to stand.
- **Reshape the spit** so a hull can stand off it. ⚠ **A Blender round on the island**, whose shape the
  user approved by eye on 2026-08-29 — 「지금 이대로 괜찮은 거 같고」.
- **Change the bearing rule** so a beach whose seaward direction runs along the coast still admits a boat.
  ⚠ **Six 조각 bought with a rule change that touches every landing.**

## ⚠⚠ The count moves with a constant nobody thinks of as a map value

**The ring is computed at `Rules.BOAT_START_DIST_TILES` = 24.** At 10 it was 74 조각; at 24 it is 61.
**Changing how far out boats are born silently changes which shores are ever attacked.**
