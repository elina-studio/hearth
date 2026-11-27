// Murmuration: a flock of thousands of specks pours across a dusk sky. Every beat throws a new bend down the
// flock and makes it swell, the bass lifts the glow on the horizon, the mids stretch the flock wider, and the
// treble flickers the wings.
HL.mk('Hearth - Murmuration', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  vec2 p = P(uv);
  vec3 prev = texture(sampler_main, uv).rgb;
  float hy = p.y + 0.5;
  vec3 sky = mix(vec3(0.40, 0.24, 0.06), vec3(0.012, 0.022, 0.016), smoothstep(0.0, 0.72, hy));
  sky = mix(sky, vec3(0.09, 0.11, 0.055), 0.55 * exp(-pow((hy - 0.34) / 0.2, 2.0)));
  sky += vec3(0.55, 0.32, 0.08) * exp(-length((p - vec2(0.22, -0.52)) * vec2(0.7, 1.7)) * 3.2) * (0.55 + 0.45 * q2);
  // a few early stars
  vec2 sg = p * 30.0, sid = floor(sg);
  sky += vec3(0.9, 0.85, 0.6) * smoothstep(0.06, 0.0, length(fract(sg) - 0.2 - 0.6 * h22(sid))) * step(0.86, h2(sid)) * smoothstep(0.45, 0.9, hy) * (0.3 + 0.5 * q4);
  float birds = 0.0;
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float A = q1 * (0.30 + 0.07 * fk) + q27 * 0.55 + fk * 2.1;
    float f = 0.11 + 0.15 * sin(1.6 * p.x + A) + 0.08 * sin(3.3 * p.x - A * 0.7 + fk) + 0.03 * sin(7.0 * p.x + A * 1.3);
    float xc = 0.30 * sin(q1 * 0.09 + fk * 1.3);
    float env = exp(-pow((p.x - xc) / (0.36 + 0.14 * q8), 2.0));
    float w = (0.022 + 0.085 * (0.5 + 0.5 * sin(2.6 * p.x + A * 0.9 + fk * 2.0))) * (1.0 + 0.8 * q3);
    float d = (p.y - f) / w;
    float D = env * exp(-d * d); D = D * D * 1.15;
    vec2 g = vec2(p.x, p.y - f * 0.6) * (100.0 - 20.0 * fk) + vec2(-(q1 * 2.2 + q27 * 1.5) * (1.0 + 0.3 * fk), fk * 13.0);
    vec2 id = floor(g), jf = h22(id + fk * 31.0);
    vec2 o = fract(g) - 0.25 - 0.5 * jf; o.x *= 0.55;
    float dt_ = smoothstep(0.17, 0.06, length(o));
    birds = max(birds, dt_ * step(h2(id + 7.0), D * 0.95) * (0.55 + 0.45 * jf.x + 0.6 * q4 * jf.y));
  }
  vec3 c = max(prev * 0.62, sky);
  c = mix(c, vec3(0.97, 0.90, 0.70), sat(birds));
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.16, 0.13, 0.08);
  float px = 1.0 / texsize.y;
  float r1 = -0.385 + 0.07 * fbm2(vec2(p.x * 1.6 + 2.0, 0.0)) + 0.012 * trees(p.x, 26.0, 3.0);
  c = mix(c, vec3(0.030, 0.034, 0.016), smoothstep(px, -px, p.y - r1));
  float r2 = -0.44 + 0.05 * fbm2(vec2(p.x * 2.4 + 9.0, 1.0)) + 0.018 * trees(p.x, 15.0, 8.0);
  c = mix(c, vec3(0.010, 0.014, 0.008), smoothstep(px, -px, p.y - r2));
  ret = finish(c, p, 0.5);
`,
});
