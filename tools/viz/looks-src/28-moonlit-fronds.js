// Moonlit fronds: dark fern fronds arch in front of a misty moon with fireflies drifting between them. The
// fronds sway all the time, the bass bows them, each beat sends a ripple out along the leaflets and brightens
// the fireflies, and the mist slides slowly past.
HL.mk('Hearth - Moonlit fronds', {
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
    vec3 fc = mix(dark * 0.8, lite * 1.1, smoothstep(0.35, 0.75, spiral)) + vec3(0.30, 0.20, 0.08) * smoothstep(0.75, 1.0, r / rc);
    col = mix(col, fc, disc); A = max(A, disc);
  }
  return vec4(col, A);
}
`,
  comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec2 mo = vec2(0.08, 0.17);
  float md = length(p - mo);
  vec3 c = mix(vec3(0.020, 0.040, 0.028), vec3(0.085, 0.130, 0.085), exp(-md * 2.2));
  c += vec3(0.80, 0.78, 0.52) * (0.20 + 0.06 * q2) * exp(-md * md / 0.05);
  c = mix(c, vec3(0.96, 0.93, 0.76) * (0.92 + 0.08 * fbm(p * 14.0)), smoothstep(0.088 + px, 0.088 - px, md));
  // mist sliding past
  float mist = fbm(vec2(p.x * 1.6 + q7 * 0.02, p.y * 6.0 + 3.0)) * smoothstep(0.15, -0.35, p.y);
  c += vec3(0.50, 0.56, 0.40) * mist * (0.10 + 0.04 * q2);
  // far fronds, soft and grey-green
  for (int i = 0; i < 6; i++) {
    float fi = float(i), h = h1(fi + 41.0);
    float x = -0.80 + 0.32 * fi + 0.12 * (h - 0.5);
    float lean = -x * 0.45 + (h1(fi + 43.0) - 0.5) * 0.4;
    float ang = PI * 0.5 + lean + 0.05 * sin(q7 * 0.4 + fi * 1.7) * (1.0 + 1.5 * q2);
    vec4 f = frond(p - vec2(x, -0.56), ang, 0.50 + 0.22 * h, lean * 0.9 * (1.0 + 0.3 * q2), fi + 41.0, px * 5.0, 1.0, vec3(0.085, 0.130, 0.090), vec3(0.060, 0.095, 0.065));
    c = mix(c, f.rgb, f.a * 0.9);
  }
  // fireflies between the layers
  for (int l = 0; l < 2; l++) {
    float fl = float(l);
    vec2 g = p * (4.0 + 2.0 * fl) + vec2(q7 * 0.04 * (fl - 0.5), 0.2 * sin(q7 * 0.13 + fl)), gi = floor(g);
    vec2 gf = fract(g) - 0.5 - 0.30 * vec2(sin(q7 * 0.5 + h2(gi) * TAU), cos(q7 * 0.4 + h2(gi + 2.0) * TAU));
    float on = step(0.55, h2(gi + 7.0 + fl)) * (0.5 + 0.5 * sin(q7 * 1.3 + h2(gi + 9.0) * TAU)) * smoothstep(0.25, 0.0, p.y);
    c += vec3(1.0, 0.86, 0.42) * on * (exp(-dot(gf, gf) / 0.0012) * 0.9 + exp(-dot(gf, gf) / 0.02) * 0.16) * (0.5 + 0.9 * q3 + 0.3 * q4);
  }
  // near fronds, almost black, arching in from the sides and below
  for (int i = 0; i < 9; i++) {
    float fi = float(i);
    vec2 b; float an, bd, L;
    if (i == 0) { b = vec2(-0.93, -0.39); an = 0.75; bd = -0.37; L = 0.72; }
    else if (i == 1) { b = vec2(-0.68, -0.56); an = 1.15; bd = -0.28; L = 0.83; }
    else if (i == 2) { b = vec2(-0.36, -0.57); an = 1.45; bd = 0.22; L = 0.60; }
    else if (i == 3) { b = vec2(0.93, -0.35); an = 2.45; bd = 0.37; L = 0.75; }
    else if (i == 4) { b = vec2(0.67, -0.56); an = 1.95; bd = 0.27; L = 0.85; }
    else if (i == 5) { b = vec2(0.36, -0.58); an = 1.60; bd = -0.24; L = 0.55; }
    else if (i == 6) { b = vec2(0.0, -0.60); an = 1.75; bd = 0.15; L = 0.35; }
    else if (i == 7) { b = vec2(-0.92, 0.04); an = 0.15; bd = -0.28; L = 0.50; }
    else { b = vec2(0.92, 0.08); an = 3.0; bd = 0.27; L = 0.53; }
    float sw = sin(q7 * 0.55 + fi * 2.1) + 0.5 * sin(q7 * 0.23 + fi);
    an += 0.035 * sw * (1.0 + 1.5 * q2);
    bd *= 1.0 + 0.10 * sw + 0.35 * q2;
    vec4 f = frond(p - b, an, L, bd, fi + 51.0, px, 1.0, vec3(0.030, 0.050, 0.034), vec3(0.008, 0.014, 0.010));
    c = mix(c, f.rgb, f.a);
  }
  ret = finish(c, p, 0.7);
`,
});
