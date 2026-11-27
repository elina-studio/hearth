// Aurora over the hills: green and gold curtains ripple above dark sleeping hills. Every beat
// sends a fold running along the curtains and makes them leap, the bass brightens them, the mids make them
// taller, and the treble sets the stars twinkling.
HL.mk('Hearth - Aurora over the hills', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  vec2 p = P(uv);
  vec3 prev = texture(sampler_main, uv).rgb;
  vec3 c = vec3(0.006, 0.014, 0.014) + vec3(0.010, 0.022, 0.018) * (0.5 - p.y);
  for (int l = 0; l < 2; l++) {
    float fl = float(l);
    vec2 g = p * (28.0 + 24.0 * fl), id = floor(g), jf = h22(id + fl * 7.0);
    float tw = 0.5 + 0.5 * sin(q7 * (1.0 + 3.0 * jf.x) + jf.y * 40.0);
    c += vec3(0.95, 0.92, 0.75) * smoothstep(0.10, 0.0, length(fract(g) - 0.2 - 0.6 * jf)) * step(0.5, h2(id + 2.0)) * (0.10 + 0.22 * tw + 0.9 * q4 * step(0.75, jf.x) * tw);
  }
  vec3 au = vec3(0.0);
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float xx = p.x + 0.10 * sin(p.y * 3.0 + q1 * 0.2 + fk * 2.0);
    float fold = q1 * (0.22 + 0.05 * fk) + q27 * 0.45;
    float yb = -0.10 + 0.11 * fk + 0.09 * sin(xx * 2.3 + fold + fk * 2.1) + 0.05 * sin(xx * 5.1 - fold * 1.3 + fk);
    float h = p.y - yb;
    float rays = 0.35 + 0.65 * fbm2(vec2(xx * 13.0 + fk * 5.0 + 0.6 * sin(fold), q1 * 0.05 + fk));
    rays *= 0.78 + 0.22 * sin(xx * 31.0 + 9.0 * nz(vec2(xx * 5.0, fk + q1 * 0.03)) + fold * 2.0);
    float tall = 0.14 + 0.16 * q8 + 0.10 * q3 + 0.05 * fk;
    float prof = smoothstep(-0.004, 0.022, h) * exp(-max(h, 0.0) / tall);
    float run = 0.65 + 0.35 * sin(xx * 7.0 - fold * 3.0);
    float inten = rays * prof * run * (0.28 + 0.42 * q2 + 0.40 * q3) * (1.0 - 0.22 * fk);
    vec3 col = mix(vec3(0.95, 0.82, 0.38), vec3(0.36, 0.66, 0.30), smoothstep(0.0, 0.07, h));
    col = mix(col, vec3(0.14, 0.30, 0.20), smoothstep(0.08, 0.36, h));
    au += col * inten;
  }
  c += au;
  ret = max(c, prev * 0.80);
`,
  comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec3 c = texture(sampler_main, uv).rgb;
  vec3 bl = texture(sampler_blur1, uv).rgb, b2 = texture(sampler_blur2, uv).rgb;
  c += bl * 0.35 + b2 * 0.25;
  vec3 sheen = texture(sampler_blur2, vec2(uv.x, 0.45)).rgb;                   // the sky's light falling on the hills
  float r0 = -0.27 + 0.10 * fbm2(vec2(p.x * 1.1 + 1.0, 0.0)) + 0.010 * trees(p.x, 30.0, 1.0);
  c = mix(c, vec3(0.012, 0.030, 0.022) + sheen * 0.10, smoothstep(px, -px, p.y - r0));
  float r1 = -0.34 + 0.09 * fbm2(vec2(p.x * 1.5 + 7.0, 0.0)) + 0.016 * trees(p.x, 20.0, 5.0);
  c = mix(c, vec3(0.012, 0.028, 0.019) + sheen * 0.11 * sat((p.y - r1 + 0.08) * 12.0), smoothstep(px, -px, p.y - r1));
  float r2 = -0.41 + 0.07 * fbm2(vec2(p.x * 2.2 + 3.0, 0.0)) + 0.022 * trees(p.x, 12.0, 9.0);
  c = mix(c, vec3(0.010, 0.020, 0.013) + sheen * 0.09 * sat((p.y - r2 + 0.06) * 14.0), smoothstep(px, -px, p.y - r2));
  ret = finish(c, p, 0.55);
`,
});
