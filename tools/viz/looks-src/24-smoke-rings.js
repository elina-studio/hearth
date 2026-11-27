// Pipe-smoke rings: every beat blows a new ring that floats toward you, widening and curling apart. The bass
// pushes the rings faster, the mids feed a thin plume between puffs, and the treble makes the pipe's ember wink.
HL.mk('Hearth - Smoke rings', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  fn: `const vec2 CE = vec2(0.0, -0.05);`,
  cfn: `const vec2 CE = vec2(0.0, -0.05);`,
  warp: `
  vec2 p = P(uv);
  vec2 d = p - CE;
  float zr = 0.006 + 0.004 * q2 + 0.003 * q3;
  float dl = length(d) + 1e-4;
  vec2 sp = CE + rot2(d, 0.004 * sin(q1 * 0.3)) * (1.0 - zr) - d / dl * min(dl, 0.0030 + 0.002 * q2);
  vec2 tur = vec2(fbm(p * 4.0 + vec2(0.0, q7 * 0.15)) - 0.5, fbm(p * 4.0 + vec2(5.2, q7 * 0.15)) - 0.5);
  sp -= tur * 0.0045 * smoothstep(0.03, 0.5, length(d)) * 2.0;
  sp.y -= 0.0005;
  float s = mix(texture(sampler_main, UV(sp)).r, texture(sampler_blur1, UV(sp)).r, 0.03) * 0.986;
  float r = length(d * vec2(1.0, 1.10));
  float ring = exp(-pow((r - 0.030) / 0.0075, 2.0)) * (0.70 + 0.6 * nz(vec2(atan(d.y, d.x) * 3.0, q5)));
  s += ring * smoothstep(0.10, 0.02, q28) * 0.75;
  s += 0.012 * q8 * exp(-pow(r / 0.012, 2.0));
  ret = vec3(min(s, 1.5));
`,
  comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  float s = texture(sampler_main, uv).r, b = texture(sampler_blur1, uv).r, b2 = texture(sampler_blur2, uv).r;
  vec3 c = mix(vec3(0.010, 0.017, 0.012), vec3(0.028, 0.042, 0.028), fbm(p * 1.6 + 2.0));
  float em = 0.7 + 0.5 * q3 + 0.5 * q4;
  c += vec3(0.75, 0.38, 0.10) * 0.12 * em * exp(-length((p - vec2(0.0, -0.56)) * vec2(0.8, 1.5)) * 3.0);
  float warm = sat(0.35 - p.y * 0.9);
  vec3 smoke = mix(vec3(0.62, 0.64, 0.56), vec3(1.0, 0.80, 0.52), warm);
  float fine = 0.75 + 0.5 * fbm(p * 9.0 + vec2(0.0, q7 * 0.05));
  c += smoke * (pow(s, 0.9) * 0.95 * fine + b * 0.12 + b2 * 0.03);
  ret = finish(c, p, 0.65);
`,
});
