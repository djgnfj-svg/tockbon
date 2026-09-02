# 04-ground-decal — the box projected onto the terrain, following its height

- buys — reads as 「this ground」: the outline climbs the 2층 tongue where the top edge crosses it and turns with the board at yaw 90, so the box names a place on the island and not a patch of glass
- costs — a terrain projection per sample per frame while dragging (about 80 ray walks for this rect); jagged on cliffs, where the ribbon stands up the face and the corners stop being square
- cannot — cannot stay a rectangle once the camera turns: it becomes the shape the ground was under the glass at drag time, and it cannot be a pulled picture — it is geometry, so the frame_01 ink has nowhere to go

How it is made: every 8 screen px along the rect's four edges is thrown through the field's own
`screen_to_terrain_px` (the ray walk a press uses), the hit's height is `_ground_h` on that 조각 plus
`Look.FX_GROUND_LIFT_TILES`, and a ribbon of thin quads (half-width 0.045 조각) runs hit to hit in an
`ImmediateMesh` with the ground layer's material — unshaded, vertex colour, alpha, no depth write,
`render_priority` 2 so the 판 cannot sort over it. One faint quad (alpha 0.10) across the four corner
hits is the fill; the terrain hides it wherever the ground rises inside the rect.
