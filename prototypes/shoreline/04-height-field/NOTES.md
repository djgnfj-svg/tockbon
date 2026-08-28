# 04-height-field — A baked seabed height

Picture: `../out/04-height-field.png`

**Buys** — the same width-follows-the-slope as the depth buffer, **without the screen**. It knows the ground off the edge of the frame and behind the camera, it never swims, and the CPU can read the same field. This is what Crest bakes and what Unity's own Boat Attack water bakes for its shore foam.

**Costs** — a bake per island, memory for the field, and the same texel-size limit as 01.

**Cannot** — react to anything that moves. A boat, a body, a block placed mid-fight: none of them are in the field until it is baked again. ⚠ It is also **one word away from 01** — same bake, same read, and the only difference is that the texel holds a HEIGHT rather than a DISTANCE.
