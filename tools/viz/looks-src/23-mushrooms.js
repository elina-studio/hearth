// Mushrooms: mushrooms of several kinds on the forest floor breathe out glowing spores that rise and curl on
// the air, while a millipede and a couple of beetles go about their business in the moss. Every beat makes the
// caps dip and puff out a fresh cloud and nudges the bugs along, the bass lights the gills, the mids stir the
// air sideways, and the treble sets stray spores twinkling.
(function () {
  const shared = `
const float G0 = -0.385;
// the mushrooms: x of the foot, cap half width, stem height, kind (0 dome, 1 tall bell, 2 wide flat, 3 funnel, 4 button)
vec4 M(int i) {
  if (i == 0) return vec4(-0.62, 0.150, 0.190, 0.0);
  if (i == 1) return vec4(-0.36, 0.060, 0.330, 1.0);
  if (i == 2) return vec4(-0.29, 0.045, 0.210, 1.0);
  if (i == 3) return vec4(0.02, 0.250, 0.250, 2.0);
  if (i == 4) return vec4(0.36, 0.105, 0.150, 3.0);
  if (i == 5) return vec4(0.56, 0.060, 0.050, 4.0);
  if (i == 6) return vec4(0.71, 0.125, 0.240, 0.0);
  return vec4(-0.14, 0.050, 0.040, 4.0);
}
const int NM = 8;
float lean(float sd, float R) { return (h1(sd) - 0.5) * 0.5 * R; }
`;
  HL.mk('Hearth - Mushrooms', {
    frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
    fn: shared,
    warp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb * 0.80;                  // a short afterglow behind each spore
  float acc = 0.0, tw = 0.0;
  for (int i = 0; i < NM; i++) {
    vec4 m = M(i);
    float fi = float(i);
    float y0 = G0 + m.z - 0.04 * m.y;
    float h = p.y - y0;
    if (h < -0.02) continue;
    float cx = m.x + lean(fi + 1.0, m.y);
    float wav = (0.035 * sin(h * 8.0 - q7 * 0.7 + fi * 2.0) + 0.02 * sin(h * 19.0 - q7 * 1.1 + fi)) * (1.0 + 1.3 * q8) * sat(h * 4.0) + 0.10 * h * sin(q7 * 0.13 + fi * 1.7);
    float sprd = m.y * (0.80 + 1.7 * h) + 0.01;
    float xr = (p.x - cx - wav) / sprd;
    float D = exp(-xr * xr * 1.8) * exp(-h * 3.6) * smoothstep(-0.02, 0.02, h);
    float band = 0.5 + 0.5 * cos(TAU * (h * 3.2 - q27 - q7 * 0.10));
    D *= 0.30 + 0.95 * band * band + 0.8 * q3 * smoothstep(0.25, 0.0, h);
    float S = 80.0;
    vec2 g = vec2((p.x - cx - wav) * S + fi * 7.3, p.y * S - (q7 * 2.6 + q27 * 1.6));
    vec2 id = floor(g), jf = h22(id + fi * 3.0);
    float rr = 0.10 + 0.14 * jf.x * jf.x;
    float dot_ = smoothstep(rr, rr * 0.25, length(fract(g) - 0.22 - 0.56 * jf));
    float on = step(h2(id + 7.0 + fi), D * 0.30);
    acc += dot_ * on * (0.55 + 0.6 * jf.y);
    tw += dot_ * on * step(0.80, jf.y);
  }
  vec3 spore = vec3(1.0, 0.78, 0.36) * acc * (0.75 + 0.35 * q2) + vec3(1.0, 0.95, 0.75) * tw * q4 * 1.2;
  ret = max(c, min(spore, vec3(1.6)));
`,
    cfn: shared + `
// one mushroom, seen from a little below so the gills show under the cap. Returns colour and cover.
vec4 mush(vec2 p, vec4 m, float sd, float px, float puff, float glow) {
  float R = m.y, sh = m.z * (1.0 - 0.05 * puff), kind = m.w;
  vec2 q = p - vec2(m.x, G0);
  if (abs(q.x) > R * 1.6 || q.y < -0.03 || q.y > sh + R * 2.4) return vec4(0.0);
  float ln = lean(sd, R);
  float t = sat(q.y / sh);
  // cap proportions by kind: height of the dome, how much underside shows, stem thickness
  float capK = kind < 0.5 ? 0.72 : (kind < 1.5 ? 2.1 : (kind < 2.5 ? 0.30 : (kind < 3.5 ? 0.42 : 0.95)));
  float uh0 = kind < 0.5 ? 0.24 : (kind < 1.5 ? 0.10 : (kind < 2.5 ? 0.22 : (kind < 3.5 ? 0.0 : 0.10)));
  float stemK = kind < 0.5 ? 1.0 : (kind < 1.5 ? 0.55 : (kind < 2.5 ? 0.60 : (kind < 3.5 ? 1.1 : 1.9)));
  float capH = R * capK * (1.0 - 0.12 * puff);
  float Rr = R * (1.0 + 0.07 * puff);
  vec2 u = vec2((q.x - ln) / Rr, (q.y - sh) / capH);
  vec3 col = vec3(0.0); float A = 0.0;
  // underside with gills
  float uh = max(0.02, uh0 * Rr / capH);
  float rho = length(vec2(u.x, min(u.y, 0.0) / uh));
  float underA = smoothstep(px / Rr * 1.5, -px / Rr * 1.5, rho - 1.0) * step(u.y, 0.02) * step(0.01, uh0);
  float ga = atan(u.y / uh, u.x);
  float gill = 0.5 + 0.5 * sin(ga * 56.0 + 2.0 * sin(ga * 9.0 + sd));
  vec3 gc = mix(vec3(0.30, 0.22, 0.13), vec3(0.80, 0.68, 0.46), gill * (0.35 + 0.65 * rho));
  gc *= (0.22 + 0.55 * rho) * (0.55 + 1.5 * glow);
  gc += vec3(1.0, 0.62, 0.22) * glow * 0.30 * (1.0 - rho);
  col = gc; A = underA;
  // stem (the funnel kind widens all the way up into its cap)
  float flare = kind > 2.5 && kind < 3.5 ? 0.75 * pow(t, 2.2) : 0.0;
  float ws = R * stemK * (0.150 + 0.085 * exp(-t * 5.0) - 0.035 * t + flare) * (1.0 + 0.06 * (nz(vec2(q.y / R * 3.0, sd)) - 0.5));
  float ds = (q.x - ln * t * t) / ws;
  float stemA = smoothstep(px / ws, -px / ws, abs(ds) - 1.0) * step(-0.01, q.y) * step(q.y, sh + (flare > 0.0 ? 0.0 : -0.02 * R));
  float cyl = sqrt(sat(1.0 - ds * ds));
  float fib = nz(vec2(ds * 9.0 + sd, q.y / R * 2.5)) * 0.6 + nz(vec2(ds * 30.0, q.y / R * 4.0 + sd)) * 0.4;
  vec3 pale = kind > 2.5 && kind < 3.5 ? vec3(0.80, 0.56, 0.22) : vec3(0.78, 0.72, 0.56);
  vec3 sc = mix(pale * 0.65, pale, fib) * (0.12 + 0.55 * cyl * (0.8 - 0.35 * ds));
  if (flare > 0.0) sc *= 0.75 + 0.35 * sin(ds * 26.0 + 2.0 * nz(vec2(ds * 4.0, sd)));                // ridges running up the funnel
  sc *= 0.55 + 0.45 * smoothstep(sh, sh * 0.55, q.y) + (flare > 0.0 ? 0.3 : 0.0);
  sc += vec3(1.0, 0.62, 0.22) * glow * 0.35 * smoothstep(sh * 0.35, sh, q.y) * cyl;
  // the skirt left by the veil, on the dome kind only
  float sky = sh * 0.66 - 0.10 * R * ds * ds;
  float skirt = kind < 0.5 ? smoothstep(0.022 * R + px, 0.022 * R - px, abs(q.y - sky)) * step(abs(ds), 1.3) : 0.0;
  sc = mix(sc, vec3(0.66, 0.60, 0.45) * (0.25 + 0.5 * cyl), skirt * step(abs(ds), 1.0));
  sc = mix(sc, vec3(0.06, 0.11, 0.04), smoothstep(0.03, 0.0, q.y + 0.02 * nz(vec2(q.x * 60.0, sd))));
  col = mix(col, sc, stemA); A = max(A, stemA);
  A = max(A, skirt * smoothstep(1.3 + px / ws, 1.3 - px / ws, abs(ds)));
  col = mix(col, vec3(0.60, 0.54, 0.40) * 0.45, skirt * step(1.0, abs(ds)));
  // the cap: a dome, a tall bell, a wide flat plate, a wavy funnel rim or a round button
  float topShape = kind > 0.5 && kind < 1.5 ? pow(abs(u.x), 1.5) + pow(max(u.y, 0.0), 2.4)          // bell: pointed
                 : (kind > 1.5 && kind < 2.5 ? pow(abs(u.x), 2.6) + u.y * u.y                      // flat: broad shoulders
                 : u.x * u.x + u.y * u.y);
  if (kind > 2.5 && kind < 3.5) {
    // funnel: no dome, just a rolled, wavy lip
    float lip = 0.10 * sin(u.x * 9.0 + sd) * (1.0 - u.x * u.x);
    float dl = length(vec2(max(abs(u.x) - 0.95, 0.0), (u.y - lip) * 1.0 / 0.30));
    float lipA = smoothstep(px / Rr * 2.5, -px / Rr * 2.5, dl - 0.30) * step(abs(u.x), 1.3);
    vec3 lc = vec3(0.86, 0.60, 0.22) * (0.30 + 0.5 * sat(0.6 - (u.y - lip) * 1.6)) * (0.8 + 0.3 * nz(u * 14.0));
    lc += vec3(1.0, 0.7, 0.3) * 0.25 * glow;
    col = mix(col, lc, lipA); A = max(A, lipA);
    return vec4(col, A);
  }
  float capA = smoothstep(px / Rr * 2.5, -px / Rr * 2.5, topShape - 1.0) * smoothstep(-px / capH, px / capH, u.y + 0.02 * (1.0 - u.x * u.x));
  float nzv = sqrt(sat(1.0 - topShape));
  vec3 n = normalize(vec3(u.x, u.y * 0.9 + 0.15, nzv + 0.25));
  float moon = sat(dot(n, normalize(vec3(-0.45, 0.75, 0.5))));
  vec3 base = kind < 0.5 ? mix(vec3(0.34, 0.17, 0.07), vec3(0.54, 0.30, 0.11), fbm(u * 3.0 + sd * 5.0))            // chestnut dome
            : (kind < 1.5 ? mix(vec3(0.46, 0.40, 0.28), vec3(0.72, 0.64, 0.46), fbm(u * vec2(3.0, 1.2) + sd * 5.0))  // pale bell
            : (kind < 2.5 ? mix(vec3(0.24, 0.16, 0.09), vec3(0.46, 0.32, 0.16), fbm(u * 3.0 + sd * 5.0))            // dark flat
            : mix(vec3(0.60, 0.50, 0.34), vec3(0.80, 0.72, 0.54), fbm(u * 3.0 + sd * 5.0))));                       // pale button
  float mer = u.x / max(0.12, sqrt(sat(1.0 - u.y * u.y)));
  float lines = 0.5 + 0.5 * sin(mer * 46.0 + sd);
  float lineAmt = kind > 0.5 && kind < 1.5 ? 0.75 : 0.35;                                                           // the bell is pleated all the way up
  base = mix(base, base * 1.35 + vec3(0.05, 0.035, 0.0), smoothstep(kind > 0.5 && kind < 1.5 ? 1.0 : 0.55, 0.0, u.y) * (0.35 * (1.0 - lineAmt) + lineAmt * lines));
  // pale scales on the dome, a dark middle on the flat one
  vec2 wg = vec2(asin(clamp(mer, -1.0, 1.0)) * 4.6, asin(sat(u.y)) * 4.2) + sd * 3.0;
  vec2 wi = floor(wg), wf = fract(wg) - 0.5 - 0.3 * (h22(wi + sd) - 0.5);
  float wart = smoothstep(0.26, 0.14, length(wf) + 0.14 * nz(wg * 4.0)) * step(0.45, h2(wi + sd)) * (kind < 0.5 ? 1.0 : 0.0);
  base = mix(base, vec3(0.78, 0.70, 0.52), wart * 0.85);
  if (kind > 1.5 && kind < 2.5) base *= 0.65 + 0.35 * smoothstep(0.0, 0.7, abs(u.x)) + 0.25 * sin(length(u * vec2(1.0, 2.0)) * 26.0) * 0.3;
  vec3 cc = base * (0.10 + 0.70 * moon * vec3(0.92, 0.96, 0.84));
  cc += base * vec3(1.0, 0.62, 0.25) * (0.35 + 1.0 * glow) * sat(0.45 - u.y) * (0.5 + 0.5 * nzv);
  cc += vec3(0.9, 1.0, 0.85) * 0.10 * pow(moon, 6.0);
  cc *= 0.60 + 0.40 * smoothstep(1.0, 0.75, topShape);
  col = mix(col, cc, capA); A = max(A, capA);
  return vec4(col, A);
}
// a millipede walking along the ground line gy(x): returns colour and cover
vec4 millipede(vec2 p, float head, float dir, float len, float px) {
  vec3 col = vec3(0.0); float A = 0.0;
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float x = head - dir * fi * len / 16.0;
    float y = G0 + 0.028 + 0.025 * fbm2(vec2(x * 3.0, 1.0)) + 0.005 * sin(fi * 0.9 - q7 * 7.0);       // a ripple runs down its back
    vec2 q = p - vec2(x, y);
    float rs = len / 16.0 * (i == 0 ? 0.85 : 0.72) * (1.0 - 0.02 * fi);
    float seg = smoothstep(px, -px, length(q * vec2(1.0, 1.25)) - rs);
    float sh = 0.5 + 0.5 * sat(q.y / rs + 0.3);
    vec3 sc = mix(vec3(0.10, 0.045, 0.02), vec3(0.46, 0.22, 0.07), sh) + vec3(0.9, 0.7, 0.4) * 0.25 * smoothstep(rs * 0.5, 0.0, length(q - vec2(-rs * 0.2, rs * 0.35)));
    // legs: a pair under each ring, stepping in a wave
    float sw = sin(fi * 1.4 - q7 * 9.0 - q27 * 2.0);
    vec2 lq = q - vec2(0.0, -rs * 0.6);
    float leg = smoothstep(px * 1.2, 0.0, abs(lq.x - sw * rs * 0.6 * (-lq.y / (rs * 1.3)))) * step(lq.y, 0.0) * step(-rs * 1.3, lq.y);
    col = mix(col, vec3(0.20, 0.10, 0.04), leg * (1.0 - A)); A = max(A, leg * 0.9);
    col = mix(col, sc, seg); A = max(A, seg);
    if (i == 0) {   // feelers
      vec2 aq = q - vec2(dir * rs * 0.7, rs * 0.3);
      float an = smoothstep(px * 1.2, 0.0, abs(aq.y - abs(aq.x) * (0.9 + 0.4 * sin(q7 * 5.0)))) * step(0.0, aq.x * dir) * step(abs(aq.x), rs * 1.6);
      col = mix(col, vec3(0.25, 0.12, 0.05), an * (1.0 - seg)); A = max(A, an);
    }
  }
  return vec4(col, A);
}
vec4 beetle(vec2 p, float x, float dir, float s, float px) {
  float y = G0 + 0.018 + 0.025 * fbm2(vec2(x * 3.0, 1.0)) + s * 0.55;
  vec2 q = (p - vec2(x, y)) / s; q.x *= dir;
  float body = smoothstep(px / s, -px / s, length(q * vec2(0.75, 1.25)) - 1.0) * step(-0.25, q.y);
  float head = smoothstep(px / s, -px / s, length((q - vec2(1.25, -0.10)) * vec2(1.6, 1.8)) - 1.0);
  vec3 bc = mix(vec3(0.03, 0.05, 0.03), vec3(0.16, 0.30, 0.14), pow(sat(0.9 - length(q - vec2(-0.2, 0.45))), 2.0)) + vec3(0.8, 0.9, 0.6) * 0.3 * smoothstep(0.3, 0.0, length(q - vec2(-0.3, 0.5)));
  bc *= 1.0 - 0.5 * smoothstep(0.03, 0.0, abs(q.y - 0.75 + q.x * 0.0)) * 0.0;
  float legs = 0.0;
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float sw = sin(q7 * 10.0 + q27 * 2.0 + fk * 2.1) * 0.25;
    vec2 lq = q - vec2(-0.6 + 0.6 * fk, -0.2);
    legs = max(legs, smoothstep(0.10, 0.03, abs(lq.x - sw * (-lq.y))) * step(lq.y, 0.0) * step(-0.55, lq.y));
  }
  float A = max(max(body, head), legs);
  return vec4(mix(vec3(0.03, 0.03, 0.02), bc, body), A);
}
`,
    comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec3 sp = texture(sampler_main, uv).rgb, bl = texture(sampler_blur1, uv).rgb, b2 = texture(sampler_blur2, uv).rgb;
  vec3 c = mix(vec3(0.008, 0.016, 0.011), vec3(0.028, 0.048, 0.028), fbm(p * 1.8 + 3.0));
  float tr = smoothstep(0.30, 0.0, abs(fract(p.x * 1.7 + 0.2) - 0.5) + 0.08 * nz(vec2(p.x * 9.0, p.y * 3.0)));
  c *= 1.0 - 0.35 * tr;
  c += vec3(0.60, 0.34, 0.10) * (0.10 + 0.10 * q3 + 0.05 * q2) * exp(-(p.y + 0.5) * 5.0);
  c += sp * 1.2 + bl * 0.75 + b2 * 0.45;
  float gy = G0 + 0.012 + 0.025 * fbm2(vec2(p.x * 3.0, 1.0)) + 0.006 * nz(vec2(p.x * 40.0, 2.0));
  float tuft = 0.012 * pow(nz(vec2(p.x * 140.0, 5.0)), 3.0);
  vec3 moss = mix(vec3(0.045, 0.085, 0.034), vec3(0.14, 0.21, 0.075), fbm(p * vec2(26.0, 50.0))) * (0.8 + 2.5 * (b2.r + bl.r));
  moss *= 0.55 + 0.45 * smoothstep(-0.5, G0, p.y);
  for (int i = 0; i < NM; i++) {
    vec4 m = M(i);
    float fi = float(i);
    // each kind answers the beat a little differently, so they do not all bob as one
    float pf = q3 * (0.6 + 0.6 * h1(fi + 9.0));
    m.x += 0.006 * sin(q1 * 0.5 + fi * 2.0) * (1.0 + q8);
    vec4 mu = mush(p, m, fi + 1.0, px, pf, 0.25 + 0.5 * q2 + 0.7 * q3);
    c = mix(c, mu.rgb, mu.a);
    moss += vec3(0.5, 0.3, 0.1) * 0.10 * (0.4 + q3) * exp(-pow((p.x - m.x) / (m.y * 1.1), 2.0)) * smoothstep(-0.5, G0, p.y);
    moss *= 1.0 - 0.5 * exp(-pow((p.x - m.x) / (m.y * 0.35), 2.0)) * smoothstep(G0 - 0.05, G0 + 0.02, p.y);
  }
  c = mix(c, moss, smoothstep(px, -px, p.y - gy - tuft));
  // the walkers: a millipede crossing one way, beetles the other, each stepping on with the beat
  float span = 2.3;
  float mh = mod(q7 * 0.035 + q27 * 0.012 + 1.0, span) - span * 0.5;
  vec4 mp = millipede(p, mh, 1.0, 0.30, px);
  c = mix(c, mp.rgb * (1.1 + 1.5 * (bl.r + b2.r)), mp.a);
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    float bx = span * 0.5 - mod(q7 * (0.022 + 0.012 * fi) + q27 * 0.010 + fi * 1.1, span);
    vec4 bt = beetle(p, bx, -1.0, 0.022 + 0.006 * fi, px);
    c = mix(c, bt.rgb * (0.8 + 1.5 * (bl.r + b2.r)), bt.a);
  }
  ret = finish(c, p, 0.7);
`,
  });
})();
