// **02-ribbon draws nothing in the water.** Its wake is a strip of triangles laid on top of the sea,
// so the sea it is laid on has to be the untouched one — which is what this passthrough is for.
vec3 wake(vec3 base, vec2 p, float t) { return base; }
