// **03-stamps draws nothing in the water.** Its wake is a run of separate quads laid on top of the
// sea, so the sea underneath has to be the untouched one.
vec3 wake(vec3 base, vec2 p, float t) { return base; }
