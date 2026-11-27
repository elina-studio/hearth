// Honeycomb glow: warm light wanders from cell to cell through a honeycomb. Every beat the light hops on a
// cell and a fresh cluster lights up, the bass warms the whole comb, the mids make the honey swell in its
// cells, and the treble sparks on the wet surface.
HL.mk('Hearth - Honeycomb glow', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  fn: `
const vec2 HS = vec2(1.0, 1.7320508);
// xy = position inside the cell, zw = the cell's id
vec4 hexc(vec2 p) {
  vec4 hC = floor(vec4(p, p - vec2(0.5, 1.0)) / HS.xyxy) + 0.5;
  vec4 h = vec4(p - hC.xy * HS, p - (hC.zw + 0.5) * HS);
  return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hC.xy) : vec4(h.zw, hC.zw + 0.5);
}
float hexd(vec2 q) { q = abs(q); return max(dot(q, HS * 0.5), q.x); }
`,
  warp: `
  vec2 p = P(uv);
  vec2 w = rot2(p, 0.06 * sin(q1 * 0.04)) * (6.4 - 0.25 * q2) + vec2(q1 * 0.035, q1 * 0.012);
  vec4 h = hexc(w);
  vec2 id = h.zw, q = h.xy;
  float d = hexd(q);                                        // 0 in the middle, 0.5 at the wall
  float rnd = h2(id), rnd2 = h2(id + 11.0);
  // the wandering light: a slow field that steps a cell on every beat, plus a cluster lit by each beat
  float fld = nz(id * 0.33 + vec2(q1 * 0.07 + q27 * 0.33, q27 * 0.21)) * 0.65 + nz(id * 0.9 + vec2(-q27 * 0.5, q1 * 0.05)) * 0.35;
  float L = smoothstep(0.50, 0.78, fld);
  vec2 cb = (h22(vec2(q5, 3.0)) - 0.5) * vec2(10.0, 5.5) + vec2(q1 * 0.035, q1 * 0.012);
  float cl = q3 * smoothstep(3.2, 0.5, length(id * HS - cb)) * (0.4 + 0.6 * rnd2);
  L = sat(L * (0.75 + 0.35 * rnd) + cl);
  // what is in the cell: honey (most), a pale wax cap (some), or empty and dark (a few)
  float kind = rnd2;
  float fill = 0.80 + 0.12 * sin(q1 * 0.6 + rnd * 20.0) * (0.3 + q8);
  vec3 honeyD = vec3(0.20, 0.09, 0.02), honeyL = vec3(1.0, 0.68, 0.20);
  vec3 honey = mix(honeyD, honeyL, 0.12 + 0.88 * L);
  // the honey is deeper in the middle and its skin bows, so light pools round the rim
  // each cell breathes with the bass: some swell while their neighbours shrink
  float sz = 1.0 + 0.17 * (0.25 + q2) * sin(rnd * TAU + q27 * 0.7) - 0.06;
  d = d / sz;
  q = q / sz;
  float bowl = smoothstep(0.0, 0.42, d);
  honey *= 0.62 + 0.55 * bowl * bowl;
  honey += vec3(1.0, 0.85, 0.5) * (0.10 + 0.9 * L) * smoothstep(0.30, 0.40, d) * smoothstep(0.455, 0.40, d) * sat(0.5 - q.y * 2.0 - q.x) * 0.5;
  // wet glint, top left of every cell
  vec2 gq = q - vec2(-0.13, 0.15);
  float gl = smoothstep(0.075, 0.02, length(gq * vec2(1.0, 1.7)));
  honey += vec3(1.0, 0.95, 0.8) * gl * (0.10 + 0.55 * L + 0.9 * q4 * step(0.6, rnd));
  vec3 cap = mix(vec3(0.34, 0.25, 0.10), vec3(0.80, 0.66, 0.36), 0.25 + 0.75 * L) * (0.75 + 0.3 * nz(w * 9.0)) * (1.05 - 0.5 * bowl * bowl);
  vec3 empty = vec3(0.05, 0.028, 0.008) * (0.6 + 1.6 * bowl * bowl) + honeyL * 0.25 * L * bowl;
  vec3 inside = kind < 0.10 ? empty : (kind < 0.24 ? cap : honey);
  // wax walls, bevelled: lit on the upper left, in shade on the lower right
  float wall = smoothstep(0.415, 0.445, d);
  float gap = smoothstep(0.50, 0.53, d);
  float bev = sat(0.5 + dot(normalize(q + 1e-4), normalize(vec2(-0.6, 0.8))) * 0.9);
  float nb = 0.12 + 0.88 * L;
  vec3 wax = mix(vec3(0.22, 0.13, 0.04), vec3(0.92, 0.68, 0.26), bev * (0.25 + 0.75 * smoothstep(0.445, 0.5, min(d, 0.5)))) * (0.35 + 0.65 * nb);
  wax *= 0.85 + 0.3 * nz(w * 14.0);
  vec3 c = mix(inside, wax, wall);
  c = mix(c, vec3(0.07, 0.04, 0.012) * (0.5 + nb), gap);
  c *= 1.0 - 0.35 * smoothstep(0.40, 0.42, d) * (1.0 - wall);        // the wall's shadow on the honey
  c *= 0.70 + 0.30 * q2 + 0.12 * q3;
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.30, 0.20, 0.08) + texture(sampler_blur2, uv).rgb * vec3(0.20, 0.12, 0.04);
  ret = finish(c * 0.95, p, 0.9);
`,
});
