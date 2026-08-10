# Boss room floors are bedrock

**Dropped**: letting the bull room and the rooster room keep their stone floors.

The user, watching a fight: "황소랑 새 보스방 바닥을 고정블록으로 해줄래? 이제 땅이 파이니까 이상하네."
Terrain is destructible now, so a boss fight dug its own arena out from under itself.

Room ① `x130–159` and room ③ `x164–183`, rows `ty32–ty37`, are `Mat.BEDROCK` — six rows deep,
not one, because a single bedrock row only moves the digging one row down.
`cell_grid` refuses to destroy bedrock, so nothing else had to change.

**The edit is in `terrain_map_generated.gd`, which says "do not edit by hand" at the top.**
It is baked from `stage.tscn`'s `Terrain(TileMapLayer)` — **the next bake reverts these 300 cells**
unless the two floors are redrawn with the bedrock brush in the editor first. That redraw has not
been done; it needs an editor session. Whoever bakes next: paint them, or lose them and not notice,
because a reverted floor raises nothing — it just digs again.
