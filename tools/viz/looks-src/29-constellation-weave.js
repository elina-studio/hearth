// Constellation weave: stars drift and gold threads join the ones that pass close, so the constellations keep
// re-forming. Every beat steps each star along its path and sends a spark down every thread, the bass swells
// the stars, the mids stretch how far a thread can reach, and the treble makes the small stars twinkle.
HL.mk('Hearth - Constellation weave', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  fn: `
vec2 starPos(float fi) {
  vec2 b = (h22(vec2(fi, 3.0)) - 0.5) * vec2(1.62, 0.86);
  float w = 0.5 + h1(fi + 9.0);
  float ph = q1 * 0.12 * w + q27 * 0.16 * w + fi * 1.7;
  return b + vec2(0.13 * sin(ph), 0.10 * cos(ph * 0.8 + fi)) + 0.04 * vec2(sin(ph * 2.3 + fi), cos(ph * 1.9));
}
float seg(vec2 p, vec2 a, vec2 b, out float t) { vec2 pa = p - a, ba = b - a; t = sat(dot(pa, ba) / dot(ba, ba)); return length(pa - ba * t); }
`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec3 prev = texture(sampler_main, uv).rgb;
  vec3 bg = vec3(0.007, 0.015, 0.014) + vec3(0.020, 0.030, 0.018) * fbm(p * 1.6 + 4.0) + vec3(0.030, 0.018, 0.004) * fbm(p * 1.1 + 9.0 + q1 * 0.01);
  // the far field of small stars
  for (int l = 0; l < 2; l++) {
    float fl = float(l);
    vec2 g = (p + vec2(q1 * 0.002 * (1.0 + fl), 0.0)) * (26.0 + 22.0 * fl), id = floor(g), jf = h22(id + fl * 7.0);
    float tw = 0.45 + 0.55 * sin(q7 * (1.0 + 3.0 * jf.x) + jf.y * 40.0);
    bg += vec3(0.95, 0.90, 0.70) * smoothstep(0.10, 0.0, length(fract(g) - 0.2 - 0.6 * jf)) * step(0.55, h2(id + 2.0)) * (0.10 + 0.25 * tw + 0.8 * q4 * step(0.8, jf.x) * tw);
  }
  vec3 c = max(prev * 0.70, bg);
  const int N = 11;
  vec2 S[N];
  for (int i = 0; i < N; i++) S[i] = starPos(float(i));
  float reach = 0.34 + 0.08 * q8;
  vec3 gold = vec3(1.0, 0.76, 0.32);
  for (int i = 0; i < N; i++) {
    for (int j = i + 1; j < N; j++) {
      float dd = distance(S[i], S[j]);
      if (dd > reach) continue;
      float t; float d = seg(p, S[i], S[j], t);
      if (d > 0.03) continue;
      float a = smoothstep(reach, reach * 0.55, dd);
      float line = smoothstep(px * 1.6, px * 0.3, d);
      float fij = float(i * 13 + j);
      // a spark runs down the thread, one hop for every beat
      float sp = fract(q27 * 0.5 + h1(fij));
      float spark = exp(-pow((t - sp) / 0.06, 2.0)) * smoothstep(0.006, 0.0, d);
      c += gold * a * (line * (0.22 + 0.18 * q3) + spark * (0.35 + 0.6 * q3));
    }
  }
  for (int i = 0; i < N; i++) {
    float fi = float(i);
    vec2 q = p - S[i];
    float r = length(q);
    float sz = (0.5 + 0.8 * h1(fi + 5.0)) * (1.0 + 0.35 * q2 + 0.35 * q3);
    float core = exp(-pow(r / (0.0045 * sz), 2.0));
    float halo = 0.004 * sz / (r + 0.006) * smoothstep(0.07, 0.0, r);
    float fl = (exp(-abs(q.x) / (0.022 * sz)) * smoothstep(0.0025, 0.0, abs(q.y)) + exp(-abs(q.y) / (0.022 * sz)) * smoothstep(0.0025, 0.0, abs(q.x)));
    c += vec3(1.0, 0.95, 0.78) * core + gold * halo * 0.45 + vec3(1.0, 0.9, 0.65) * fl * (0.25 + 0.5 * q3);
  }
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.16, 0.13, 0.07);
  // dark hill line so the sky has a floor
  float px = 1.0 / texsize.y;
  float r1 = -0.44 + 0.05 * fbm2(vec2(p.x * 1.8 + 5.0, 0.0)) + 0.014 * trees(p.x, 22.0, 4.0);
  c = mix(c, vec3(0.006, 0.010, 0.007), smoothstep(px, -px, p.y - r1));
  ret = finish(c, p, 0.6);
`,
});
