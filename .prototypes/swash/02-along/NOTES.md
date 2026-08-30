# 02-along — The phase travels along the coast

Pictures: `../out/02-along_*.png`

**Buys** — the smallest change that makes the shore go somewhere. Two extra samples give the direction
the land is in; turned ninety degrees it is the direction the water runs, and the pattern is read at a
point sliding down it. **The foam crawls around the island** instead of blinking in place.

**Costs** — two extra texture reads per pixel, and one number (`run`) that has to be tuned against the
swing rate or the crawl fights the breathing.

**Cannot** — ⚠⚠ **hold its shape at a corner.** The offset grows without bound, so the pattern is
dragged further every second along a direction that itself turns — and it turns hardest at the points,
which is where the eye is. Left running it does not drift, it **shears**. 08 is this idea with that
fixed.
