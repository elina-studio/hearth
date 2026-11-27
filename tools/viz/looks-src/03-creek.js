// Leaf down a creek: looking straight down into a shallow stream. Sunlit ripples net over a pebble bed,
// autumn leaves ride the current with their shadows on the stones below. The current lunges on every beat and
// each leaf sends out a ring, the net of light flares with the bass, and the treble scatters sparkles.
HL.mk('Hearth - Leaf down a creek', {
  fn: `
float caust(vec2 p, float t) {
  vec2 i = p; float c = 1.0;
  for (int n = 0; n < 4; n++) {
    float tt = t * (1.0 - 3.5 / float(n + 1));
    i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
    c += 1.0 / length(vec2(p.x / (sin(i.x + tt) * 200.0), p.y / (cos(i.y + tt) * 200.0)));
  }
  c = 1.17 - pow(c / 4.0, 1.4);
  return pow(abs(c), 8.0);
}
// the stream bed: rounded pebbles in earth colours, dark in the gaps
vec3 bed(vec2 p) {
  vec2 g = floor(p), f = fract(p); float d1 = 9.0, d2 = 9.0; vec2 id = g;
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 o = vec2(float(i), float(j)); vec2 r = o + h22(g + o) - f; float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; id = g + o; } else if (d < d2) d2 = d;
  }
  float edge = sqrt(d2) - sqrt(d1);
  float k = h2(id + 3.3), k2 = h2(id + 7.1);
  vec3 c = mix(vec3(0.17, 0.14, 0.11), vec3(0.34, 0.30, 0.25), k);
  c = mix(c, vec3(0.17, 0.19, 0.13), step(0.78, k2));
  c = mix(c, vec3(0.36, 0.25, 0.15), step(k2, 0.14));
  c *= 0.75 + 0.5 * nz(p * 7.0);
  c *= (0.38 + 0.62 * smoothstep(0.0, 0.3, edge)) * (1.25 - 1.0 * sqrt(d1));
  c += vec3(0.10, 0.09, 0.07) * smoothstep(0.25, 0.0, length(sqrt(d1) - 0.12)) * k;
  return c;
}
float meander(float x) { return 0.05 * sin(x * 2.1 + 0.7) + 0.025 * sin(x * 4.3 - 1.0); }
float surf(vec2 f) { return fbm2(f * vec2(2.2, 5.5)) + 0.5 * nz(f * vec2(5.0, 11.0) + 4.0); }
`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  float flow = q1 * 0.16;
  // water runs left to right along a lazy bend, quicker in the middle than at the sides
  vec2 s = vec2(p.x, p.y - meander(p.x));
  float lane = 1.0 - 0.5 * s.y * s.y * 4.0;
  vec2 f = vec2(s.x - flow * lane, s.y);
  float h0 = surf(f), hx = surf(f + vec2(0.012, 0.0)), hy = surf(f + vec2(0.0, 0.012));
  vec2 n = vec2(hx - h0, hy - h0) / 0.012;
  // what lies under the water, bent by the ripples
  vec2 bp = p + n * 0.005;
  float deep = fbm2(bp * 1.3 + 5.0);
  vec3 c = bed(bp * 13.0 + vec2(3.0, 1.0));
  c = mix(c, vec3(0.2, 0.19, 0.14) * (0.6 + 0.8 * nz(bp * 5.0)), 0.25);
  c = mix(c, c * vec3(0.45, 0.62, 0.50), 0.4 + 0.6 * deep) * (1.15 - 0.7 * deep);
  // the bright net the sun throws through the ripples
  float ca = caust((f + n * 0.008) * vec2(11.0, 19.0) - 250.0, q1 * 0.8);
  float cb = caust((f + n * 0.012) * vec2(6.3, 10.3) - 251.7, q1 * 0.55 + 2.0);
  float light = ca * 1.0 + cb * 0.9;
  c *= 0.5 + 0.3 * h0;
  c += c * vec3(1.8, 1.3, 0.6) * light * (1.6 + 1.8 * q2) + vec3(0.9, 0.62, 0.25) * light * 0.09;

  // leaves on the current, with their shadows on the bed
  float span = 2.9;
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float sp = 0.75 + 0.5 * h1(fi + 0.3);
    float x = mod(flow * sp + h1(fi + 1.0) * span + fi * 0.47, span) - span * 0.5;
    float y0 = (h1(fi + 4.0) - 0.5) * 0.62;
    float y = y0 + meander(x) + 0.018 * sin(q1 * 0.8 + fi * 2.0);
    float len = 0.20 + 0.20 * h1(fi + 6.0) * h1(fi + 6.0);
    float ang = fi * 2.4 + (mod(fi, 2.0) < 0.5 ? 0.35 : -0.35) * q27 + 0.9 * sin(q1 * 0.21 + fi * 3.0) + q1 * 0.07 * (h1(fi + 8.0) - 0.5) + 0.12 * sin(q1 * 1.1 + fi);
    vec2 d = p - vec2(x, y);
    if (dot(d, d) > len * len * 1.0) continue;
    vec3 la, lb; leafPal(h1(fi + 9.0) * 0.8 + 0.2, la, lb);
    float w = 0.25 + 0.06 * h1(fi + 11.0);
    // shadow: lower and to the right, soft, wobbling with the water
    vec2 qs = rot2(d - vec2(0.03, -0.04) + n * 0.006, -ang) / len + vec2(0.5, 0.0);
    float sh = leaf(qs, w, fi * 3.7, 0.05, la, lb, 0.0).a;
    c *= 1.0 - 0.7 * sh;
    vec2 q = rot2(d, -ang) / len + vec2(0.5, 0.0);
    // a thin bright line where the water clings to the edge
    float halo = leaf(q, w + 0.02, fi * 3.7, 0.035, la, lb, 0.0).a;
    c += vec3(0.5, 0.45, 0.3) * halo * 0.10;
    // a ring spreads from the leaf on each beat
    float rr = length(d) - (len * 0.30 + q28 * 0.16);
    c += vec3(1.0, 0.85, 0.55) * exp(-rr * rr / 0.00012) * exp(-q28 * 3.5) * 0.16 * smoothstep(len, len * 0.7, length(d));
    float rim; vec4 l = leafK(q, w, fi * 3.7, px / len, la, lb, 0.09, mod(fi, 3.0) < 0.5 ? 0.0 : (mod(fi, 3.0) < 1.5 ? 2.0 : 4.0), rim);
    l.rgb *= 0.85 + 0.5 * light + 0.12 * h0;
    c = mix(c, l.rgb, l.a);
  }
  // sparkles riding the surface, more of them when the treble is busy
  float gl = smoothstep(0.55 - 0.3 * q4, 1.3, ca * cb * 3.0 + ca * ca * 0.6);
  c += vec3(1.0, 0.88, 0.62) * gl * 0.5;
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.30, 0.24, 0.14);
  ret = finish(c * 0.85, p, 0.7);
`,
});
