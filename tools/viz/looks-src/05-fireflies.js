// Firefly meadow: a summer night. Stars over a far line of trees, mist lying in the grass, and fireflies
// drawing short strokes of light as they rise. Their glow lights the grass and mist around them. Some flash
// on the beat, the rest keep their own slow time, and the grass leans when the bass blows through.
HL.mk('Hearth - Firefly meadow', {
  // the feedback buffer holds only the light: fresh sparks over the fading strokes of the last moments
  warp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb * 0.90 - 0.004;
  for (int i = 0; i < 30; i++) {
    float fi = float(i);
    float z = h1(fi + 1.0);
    vec2 base = vec2((h1(fi + 2.0) - 0.5) * 1.9, -0.36 + 0.5 * h1(fi + 3.0) * (0.4 + 0.6 * z));
    float w1 = 0.13 + 0.15 * h1(fi + 4.0), w2 = 0.11 + 0.14 * h1(fi + 5.0);
    vec2 pos = base + vec2(0.13 * sin(q1 * w1 + fi * 2.0), 0.07 * sin(q1 * w2 + fi * 3.0))
      + 0.018 * vec2(cos(q1 * (0.6 + w1 * 2.0) + fi), sin(q1 * (0.75 + w2 * 2.0) + fi * 1.7));
    // flash: every other one answers the beat, the rest keep their own rhythm
    float per = 3.2 + 3.0 * h1(fi + 6.0);
    float ph = fract(time / per + h1(fi + 7.0));
    float own = smoothstep(0.0, 0.03, ph) * smoothstep(0.34, 0.06, ph);
    float turn = step(mod(q5 + fi, 3.0), 0.5);
    float onbeat = turn * sqrt(q3);
    float lit = mod(fi, 3.0) < 1.5 ? max(onbeat, own * 0.4) : own;
    if (lit < 0.01) continue;
    float rad = mix(0.004, 0.0095, z);
    float d = length(p - pos);
    float g = min(1.0, 1.6 * exp(-d * d / (rad * rad)));
    vec3 col = mix(vec3(1.0, 0.80, 0.25), vec3(0.78, 1.0, 0.30), h1(fi + 8.0) * 0.7);
    c = max(c, col * g * lit * mix(0.6, 1.0, z));
  }
  ret = c;
`,
  base: { b1n: 0, b1x: 0.4, b2n: 0, b2x: 0.22, b3n: 0, b3x: 0.14 },
  cfn: `
// one layer of grass. Returns coverage (x) and how far up the blade we are (y). head > 0 adds seed heads
vec2 grass(vec2 p, float dens, float ground, float hmin, float hmax, float sd, float wind, float e, float head) {
  float gx = p.x * dens;
  float cov = 0.0, up = 0.0;
  for (int o = -2; o <= 2; o++) {
    float id = floor(gx) + float(o);
    float x0 = (id + h1(id + sd)) / dens;
    float hgt = hmin + (hmax - hmin) * pow(h1(id + sd + 7.0), 1.6);
    float gy = ground + 0.03 * sin(x0 * 1.7 + sd) + 0.012 * sin(x0 * 5.3 + sd * 2.0);
    float t = (p.y - gy) / hgt;
    if (t > 1.12) continue;
    float tc = clamp(t, 0.0, 1.0);
    float lean = ((h1(id + sd + 11.0) - 0.5) * 1.3 + wind * (0.5 + 0.7 * h1(id + sd + 13.0))) * hgt;
    float xc = x0 + lean * tc * tc;
    float hw = (0.20 + 0.22 * h1(id + sd + 15.0)) / dens * pow(1.0 - tc, 0.75) * step(t, 1.0);
    float b = smoothstep(hw + e, hw - e, abs(p.x - xc)) * step(t, 1.0);
    // a seed head nodding at the top of some stems
    if (head > 0.0 && h1(id + sd + 17.0) > 0.6) {
      vec2 hq = vec2(p.x - (x0 + lean * 0.92), p.y - (gy + hgt * 0.97));
      hq = rot2(hq, -lean / hgt * 1.4);
      b = max(b, smoothstep(1.0 + e * 60.0, 0.75, length(hq / vec2(0.0045 + 0.07 / dens, 0.028 + 0.5 / dens))));
    }
    if (b > cov) { cov = b; up = tc; }
  }
  return vec2(cov, up);
}
`,
  comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec3 spark = texture(sampler_main, uv).rgb;
  vec3 near = texture(sampler_blur1, uv).rgb, wide = texture(sampler_blur2, uv).rgb, far = texture(sampler_blur3, uv).rgb;
  // sky, deepest at the top, a little light left low down
  vec3 c = mix(vec3(0.045, 0.075, 0.075), vec3(0.012, 0.024, 0.034), sat(p.y * 1.7 + 0.2));
  c += vec3(0.07, 0.085, 0.06) * exp(-pow((p.y - 0.06) / 0.14, 2.0)) * (0.8 + 0.7 * q2);
  c += vec3(0.05, 0.06, 0.055) * exp(-length(p - vec2(0.55, 0.42)) * 3.0);
  // stars
  vec2 sg = rot2(p, 0.4) * 31.0; vec2 si = floor(sg);
  vec2 so = h22(si) * 0.7 + 0.15;
  float tw = 0.55 + 0.45 * sin(time * (1.0 + 3.0 * h2(si + 5.0)) + h2(si) * 40.0) + 0.5 * q4 * h2(si + 9.0);
  float star = smoothstep(0.09, 0.0, length(sg - si - so)) * step(0.86, h2(si + 3.0)) * tw * (0.3 + 0.7 * h2(si + 11.0));
  c += vec3(0.75, 0.80, 0.70) * star * smoothstep(0.03, 0.22, p.y) * 0.55;
  // far trees
  float tl = 0.0 + 0.05 * nz(vec2(p.x * 1.6, 1.0)) + 0.085 * trees(p.x, 5.5, 1.0) + 0.05 * trees(p.x, 13.0, 9.0) + 0.012 * nz(vec2(p.x * 60.0, 2.0)) * 1.0;
  c = mix(c, vec3(0.010, 0.019, 0.016), smoothstep(tl + 0.004, tl - 0.004, p.y));
  // mist over the meadow, lit by the fireflies inside it
  float mist = smoothstep(0.10, -0.25, p.y) * (0.55 + 0.45 * fbm(vec2(p.x * 2.0 + q1 * 0.03, p.y * 6.0)));
  c += vec3(0.045, 0.065, 0.050) * mist;
  float wind = 0.22 * sin(q1 * 0.6 + p.x * 2.2) + 0.12 * sin(q1 * 1.3 + p.x * 5.0) + 0.35 * q2;
  vec3 glow = near * 0.5 + wide * 0.8 + far * 0.8;
  // back grass, soft and hazy
  vec2 g1 = grass(p, 70.0, -0.20, 0.04, 0.15, 1.0, wind * 0.6, px * 1.5, 0.0);
  c = mix(c, vec3(0.020, 0.038, 0.024) * (0.6 + 1.2 * g1.y) + glow * 0.40, g1.x * 0.9);
  // middle grass
  vec2 g2 = grass(p, 38.0, -0.33, 0.08, 0.30, 2.0, wind * 0.8, px, 1.0);
  c = mix(c, vec3(0.012, 0.025, 0.014) * (0.6 + 1.3 * g2.y) + glow * 0.34, g2.x);
  // the fireflies and their strokes, with haloes
  c += spark * 1.6 + near * 0.8 + wide * 0.5 * (0.5 + 0.5 * mist) + far * 0.3 * (0.4 + 0.6 * mist);
  // near grass in front of everything: dark blades with light catching their edges
  float g3 = grass(p, 17.0, -0.50, 0.12, 0.52, 3.0, wind, px, 1.0).x;
  float g3in = grass(p, 17.0, -0.50, 0.12, 0.52, 3.0, wind, px * 6.0, 1.0).x;
  vec3 blade = vec3(0.006, 0.012, 0.008) + (wide * 0.8 + near * 0.6 + far * 0.4) * (0.15 + 1.5 * (1.0 - g3in));
  c = mix(c, blade, g3);
  ret = finish(c * 1.15, p, 0.55);
`,
});
