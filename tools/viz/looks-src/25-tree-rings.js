// Tree rings, old stump: an endless slow fall into the heart of a weathered, mossy stump. The rings keep
// opening outward past you, every beat steps them on a notch and lights every fourth ring gold, the bass
// warms the heart, the mids open the cracks and the treble glints on the moss.
HL.mk('Hearth - Tree rings', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  ret = texture(sampler_main, uv).rgb * 0.9;
`,
  comp: `
  vec2 p = P(uv);
  vec2 d = rot2(p - vec2(0.10 * sin(q1 * 0.05), 0.05 * cos(q1 * 0.04)), q1 * 0.015 + q27 * 0.015);
  float a = atan(d.y, d.x); vec2 n = vec2(cos(a), sin(a));
  float R = length(d * vec2(0.94, 1.05)) * (1.0 + 0.22 * (fbm2(n * 1.3 + 3.0) - 0.5)) + 1e-4;
  float u = log(R) * 6.5 + 0.9 * (fbm2(n * 2.2 + 7.0) - 0.5);
  float uu = u - (q1 * 0.10 + q27 * 0.24);
  uu += 0.06 * nz(vec2(a * 12.0, uu * 2.0));
  float id = floor(uu), f = fract(uu);
  float wv = h1(id + 1.0);
  float late = smoothstep(0.45 - 0.25 * wv, 0.93, f) * smoothstep(1.0, 0.95, f);
  vec3 early = mix(vec3(0.30, 0.23, 0.15), vec3(0.44, 0.35, 0.22), h1(id + 3.0));
  vec3 wood = mix(early, vec3(0.07, 0.05, 0.03), late * (0.6 + 0.4 * wv));
  wood *= 0.80 + 0.35 * nz(vec2(a * 70.0, uu * 1.5));
  // moss settling in the dark of some rings
  float mo = smoothstep(0.48, 0.72, fbm(vec2(n * 2.5 + id * 0.7) + uu * 0.25)) * smoothstep(0.25, 0.75, f);
  vec3 moss = mix(vec3(0.07, 0.13, 0.04), vec3(0.22, 0.32, 0.10), nz(vec2(a * 90.0, uu * 9.0))) * (1.0 + 0.6 * q4);
  wood = mix(wood, moss, mo * 0.85);
  float ck = 0.0;
  for (int i = 0; i < 4; i++) {
    float fi = float(i), ac = fi * 1.7 + 0.4 + 0.20 * nz(vec2(u * 1.5, fi));
    float da = abs(mod(a - ac + PI, TAU) - PI);
    float wd = (0.010 + 0.016 * h1(fi + 4.0)) * (1.0 + 0.9 * q8);
    ck = max(ck, smoothstep(wd, wd * 0.3, da));
  }
  wood = mix(wood, vec3(0.02, 0.012, 0.006), ck);
  vec3 c = wood * (0.62 + 0.25 * q2 + 0.10 * q3);
  float gold = step(mod(id, 4.0), 0.5) * smoothstep(0.30, 0.0, abs(f - 0.5));
  c += vec3(1.0, 0.72, 0.28) * gold * (0.10 + 0.55 * q3 + 0.25 * q2) * (1.0 - ck);
  c *= smoothstep(0.0, 0.16, R);
  c += vec3(1.0, 0.55, 0.18) * exp(-R * R / 0.010) * (0.25 + 0.6 * q2 + 0.3 * q3);
  ret = finish(c, p, 0.8);
`,
});
