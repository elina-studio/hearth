// Fern crown: looking straight down on one fern. The crown turns slowly, the fronds sway and their leaflets
// ripple outward on each beat, the bass makes the whole plant breathe, and the young fronds in the middle
// unroll and roll back with the song. Nothing is even: every frond and leaflet has its own length and lean.
HL.mk('Hearth - Fern crown', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  ret = texture(sampler_main, uv).rgb * 0.9;
`,
  cfn: `
// one frond seen from above. ang = direction, L = length, bend = sideways curve, tc = how far it has unrolled (1 = fully)
vec4 frond(vec2 p, float ang, float L, float bend, float sd, float px, float tc, vec3 lite, vec3 dark) {
  vec2 q = rot2(p, -ang);
  if (q.x < -0.02 || q.x > L * 1.08 || abs(q.y) > L * 0.75) return vec4(0.0);
  q.y -= bend * q.x * q.x / L;
  float t = q.x / L;
  vec3 col = vec3(0.0); float A = 0.0;
  float sp = L / 24.0, k0 = floor(q.x / sp), sgn = q.y < 0.0 ? -1.0 : 1.0;
  for (int j = -4; j <= 0; j++) {
    float k = k0 + float(j), tk = (k + 0.5) * sp / L;
    if (tk < 0.07 || tk > tc) continue;
    float hk = h1(k * 1.7 + sd * 13.0 + sgn * 3.1);
    if (hk < 0.04) continue;
    float prof = pow(sin(PI * pow(tk / tc, 0.62)), 0.8) * (1.0 - 0.3 * tk);
    float len = 0.30 * L * prof * (0.75 + 0.45 * hk);
    float an = 1.12 - 0.35 * tk + (hk - 0.5) * 0.26 + (0.05 + 0.10 * q3) * sin(tk * 9.0 - q7 * 2.0 - q27 * PI + sd);
    vec2 u = rot2(vec2(q.x - (k + 0.5) * sp, abs(q.y)), -an);
    float uu = u.x / max(len, 1e-4);
    if (uu < 0.0 || uu > 1.0) continue;
    float w = max(0.0022, len * 0.17) * pow(sin(PI * pow(uu, 0.55)), 0.9) * (1.0 - 0.25 * uu) * (0.72 + 0.28 * fract(uu * 9.0 + hk));
    float a = smoothstep(px, -px, abs(u.y) - w);
    vec3 cc = mix(dark, lite, 0.25 + 0.75 * uu) * (0.75 + 0.5 * hk);
    cc *= 1.0 - 0.35 * smoothstep(px * 1.6, 0.0, abs(u.y));                  // midvein
    cc *= 0.80 + 0.20 * sat(u.y / max(w, 1e-4) + 0.5) + 0.0;                  // one side of each leaflet catches more light
    col = mix(col, cc, a); A = max(A, a);
  }
  float rw = 0.0045 * L / 0.4 * (1.15 - t);
  float ra = smoothstep(px, -px, abs(q.y) - rw) * step(0.0, q.x) * step(t, tc);
  col = mix(col, mix(dark, vec3(0.22, 0.16, 0.08), 0.6 * step(0.2, lite.g)), ra); A = max(A, ra);
  // a still-rolled tip on young fronds
  float rc = 0.085 * L * (1.0 - tc) * 2.2;
  if (rc > 0.002) {
    vec2 cq = q - vec2(L * tc, rc * 0.9);
    float r = length(cq), th = atan(cq.y, cq.x);
    float disc = smoothstep(px, -px, r - rc);
    float spiral = 0.5 + 0.5 * sin(log(r / rc + 0.02) * 7.0 + th + q27 * 0.6);
    vec3 fc = mix(dark, lite * 0.85, smoothstep(0.3, 0.8, spiral)) + vec3(0.30, 0.20, 0.08) * smoothstep(0.75, 1.0, r / rc);
    col = mix(col, fc, disc); A = max(A, disc);
  }
  return vec4(col, A);
}
`,
  comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  // forest floor: soft dark litter, a warm pool of light under the plant
  vec3 c = mix(vec3(0.010, 0.018, 0.012), vec3(0.040, 0.050, 0.030), fbm(p * 4.0 + 2.0)) * (0.7 + 0.5 * fbm(p * 13.0));
  c += vec3(0.30, 0.22, 0.08) * (0.10 + 0.10 * q2) * exp(-dot(p, p) / 0.10);
  float br = 1.0 + 0.045 * q2 + 0.02 * q3;
  vec2 pc = rot2(p - vec2(0.0, -0.01), -(q1 * 0.020 + q27 * 0.030)) / (br * 1.18);
  float pxs = px / (br * 1.18);
  // old outer fronds, darker and lower
  for (int i = 0; i < 9; i++) {
    float fi = float(i), h = h1(fi + 1.0), hb = h1(fi + 5.0);
    float ang = fi / 9.0 * TAU + (h - 0.5) * 0.45 + 0.05 * sin(q7 * 0.5 + fi * 2.0) * (1.0 + 1.2 * q8);
    float L = 0.36 + 0.17 * hb;
    float bend = (h1(fi + 9.0) - 0.5) * 0.55 + 0.06 * sin(q7 * 0.4 + fi);
    vec4 f = frond(pc, ang, L, bend, fi + 1.0, pxs, 1.0, vec3(0.30, 0.44, 0.22), vec3(0.06, 0.12, 0.06));
    c = mix(c, c * 0.45, f.a * 0.0 + exp(-dot(pc, pc) / 0.03) * 0.04);
    c = mix(c, f.rgb * (0.80 + 0.30 * q2), f.a);
  }
  // young inner fronds, brighter, unrolling and rolling back
  for (int i = 0; i < 6; i++) {
    float fi = float(i), h = h1(fi + 21.0), hb = h1(fi + 25.0);
    float ang = fi / 6.0 * TAU + 0.5 + (h - 0.5) * 0.6 + 0.07 * sin(q7 * 0.6 + fi * 2.3) * (1.0 + 1.2 * q8);
    float L = 0.20 + 0.11 * hb;
    float bend = (h1(fi + 29.0) - 0.5) * 0.7 + 0.08 * sin(q7 * 0.45 + fi * 1.7);
    float tc = 0.62 + 0.38 * (0.5 + 0.5 * sin(q27 * 0.35 + fi * 1.9)) ;
    vec2 sh = pc - vec2(0.006, -0.010);
    vec4 fs = frond(sh, ang, L, bend, fi + 31.0, pxs * 4.0, tc, vec3(0.0), vec3(0.0));
    c *= 1.0 - 0.45 * fs.a;                                                    // its shadow on the fronds below
    vec4 f = frond(pc, ang, L, bend, fi + 31.0, pxs, tc, vec3(0.50, 0.64, 0.30), vec3(0.12, 0.22, 0.09));
    c = mix(c, f.rgb * (0.85 + 0.35 * q2 + 0.15 * q3), f.a);
  }
  // the heart of the plant
  float rr = length(pc);
  c = mix(c, vec3(0.09, 0.06, 0.03) * (0.6 + 0.8 * nz(pc * 200.0)), smoothstep(0.022, 0.016, rr));
  c += vec3(1.0, 0.7, 0.3) * 0.10 * (0.3 + q2) * exp(-rr * rr / 0.004);
  // slow motes of pollen in the air above
  vec2 mg = p * 7.0 + vec2(q7 * 0.05, 0.3 * sin(q7 * 0.1)), mi = floor(mg), mf = fract(mg) - 0.5 - 0.6 * (h22(mi) - 0.5);
  c += vec3(1.0, 0.92, 0.65) * exp(-dot(mf, mf) / 0.004) * step(0.6, h2(mi + 3.0)) * (0.10 + 0.25 * q4 + 0.10 * q3) * (0.5 + 0.5 * sin(q7 * 0.8 + h2(mi) * TAU));
  ret = finish(c, p, 0.8);
`,
});
