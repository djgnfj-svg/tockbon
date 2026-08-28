# 06-real-waves — The surface itself moves

Pictures: `../out/06-real-waves_0.png` .. `_3.png`

**Buys** — the swash is not a drawing of one. The sea's height really rises and falls against the slope, so the waterline advances and retreats **because the water level did**, and the band's width follows the ground for free. The same rise lifts a boat, wets a tile, and reads the same from any camera. It is the only version here whose water has a surface at all.

**Costs** — the plane must be subdivided (160x160 in this lab) and every vertex is moved every frame. ⚠ It also needs the seabed height, so it carries 04's bake as well as its own geometry.

**Cannot** — be seen from this camera. ⚠⚠ **The game looks almost straight down**, so a surface that moves up and down moves along the view direction and barely changes on screen: what you see in the picture is the shoreline shifting, not the waves. **The cost is paid where the payoff is invisible.**
