# The fire rune is used in the room it is won in — the pit's water escape is dropped for a wood door

**Status**: valid

## What was decided

**Room ①'s east wall becomes wood.** Kill the bull, take the fire rune, burn the wall you are standing in
front of, walk through. The user's reason: 「그래야 바로 직관적으로 나갈 수 있어.」

**The price they took knowingly**: the pit fills with water and the player climbs out of it — the scene the
pit's whole shape was built for — **is gone.** Stage 1 keeps **one** water escape (after the rooster) where
it had two.

Design doc: [`plans/2.active/burn-out-of-the-bull-room.md`](../plans/2.active/burn-out-of-the-bull-room.md).

## What wasn't chosen

| Rejected | Why |
|---|---|
| **The pit's water escape** (the ramp removed on purpose, the only exit being rising water) | It puts a flood, a 6-tile climb and a 4-tile walk between winning the rune and using it. **For the one moment that teaches "a rune gets you past terrain", that is three subjects** |
| **The wood wall outside room ①** (`x164-166`, on the plateau above it) | That placement existed to keep the bull's fire off the progression key. **The user chose the beat and left the protection as an open fork** — see "Conditions to reopen" |
| **A temporary ramp out of the pit** | Rejected earlier and still rejected — but its grounds are now void either way. **The pit was never a bedrock bowl**: measured on the baked map, the west boundary is a 2-tile step (64px) against a 102px jump ceiling. **The player has always been able to jump out** |
| **Keeping the flood as the exit and moving the wall anyway** | The flood does not lift the player. Measured (`stage1-bosses.md`, Risk 13-addendum): **300s of pouring lifts them 0px**, and an ordinary jump clears the step in 1.6s |

## What's tied to it

- **`stage.gd`'s `_room1_reward_water`** — the only live `WaterSource` in the game. With no escape to drive,
  it loses its job. `net_render`'s six checks on it, and the three `net_water_rain*` nets that measure a pour
  in the pit's geometry, hang off this.
- **The bull's fire.** `stage1-bosses.md`'s acceptance 5 was protected by **map shape** — the wall sat outside
  the bull's reach. This decision puts wood inside it. **Measured: a bull next to the wood burned all 1,152
  cells from either side.**
- **The runeless-blast hole.** The GDD files it as "not a problem" because *the map's shape* keeps the player
  away from the wall until they hold fire. **This decision deletes that shape.**
- **The GDD's milestone chain**, which loses two links.
- **`stage1-map-layout.md`'s ① section**, whose "기반암 그릇이고 나가는 길이 물뿐" was already false.

## Conditions to reopen

- **The door burns before the player wins it** — from the bull's fire or from a runeless blast. Then either a
  protection fork lands (the door exempt from monster fire; a sill above the floor) **or this reverses.**
- **Stage 1 reads as too short** once ② is gone as well.
- **Room ③'s pour is never built.** Then dropping this one leaves stage 1 with no water at all, and the
  water work has nothing in the game to stand on.
