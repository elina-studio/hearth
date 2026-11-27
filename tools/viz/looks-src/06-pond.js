// Rain on the pond: looking out across still water at night toward a lit round window on the far bank.
// Its gold reflection lies down the water and every ripple breaks it up. A soft drizzle keeps the surface
// alive, and each beat lands one big drop whose rings roll out toward you.
HL.mk('Hearth - Rain on the pond', {
  frame: `
if (!s.drops) { s.drops = []; for (var i = 0; i < 6; i++) s.drops.push({ x: 0, z: 1, t: -99 }); }
if (s.hit) { var d = s.drops[s.nb % 6]; d.z = 0.7 + 2.2 * Math.random() * Math.random(); d.x = (Math.random() - 0.5) * 1.3; d.t = a.time; }
for (var i = 0; i < 6; i++) { a['q' + (9 + 3 * i)] = s.drops[i].x; a['q' + (10 + 3 * i)] = s.drops[i].z; a['q' + (11 + 3 * i)] = Math.min(99, a.time - s.drops[i].t); }
`,
  fn: `
const float HZ = 0.17;                    // where the far bank meets the water
const vec2 LAMP = vec2(0.26, 0.215);      // the lit window
float bank(float x) { return 0.02 + 0.05 * nz(vec2(x * 1.3, 3.0)) + 0.05 * trees(x, 4.3, 2.0) + 0.03 * trees(x, 11.0, 5.0) + 0.01 * nz(vec2(x * 55.0, 5.0)); }
// everything above the waterline: sky, far trees, the window and its glow
vec3 env(vec2 s) {
  vec3 c = mix(vec3(0.050, 0.075, 0.075), vec3(0.012, 0.022, 0.032), sat((s.y - HZ) * 2.6));
  c += vec3(0.06, 0.07, 0.05) * exp(-(s.y - HZ) * 9.0);
  float tl = HZ + bank(s.x);
  // the hill the window sits in
  float hill = HZ + 0.115 * exp(-pow((s.x - LAMP.x) / 0.16, 2.0));
  float land = smoothstep(max(tl, hill) + 0.003, max(tl, hill) - 0.003, s.y);
  c = mix(c, vec3(0.008, 0.015, 0.012), land);
  vec2 d = s - LAMP;
  float r = length(d);
  float win = smoothstep(0.021, 0.018, r);
  float bars = max(smoothstep(0.0035, 0.0015, abs(d.x)), smoothstep(0.0035, 0.0015, abs(d.y)));
  float fl = 0.8 + 0.5 * q8;
  c += vec3(1.0, 0.62, 0.20) * win * (1.0 - 0.75 * bars) * 1.25 * fl;
  c += vec3(1.0, 0.55, 0.16) * (0.22 * exp(-r * r / 0.0035) + 0.07 * exp(-r * 7.0)) * fl;
  // a second, smaller light further along the bank
  float r2 = length(s - vec2(-0.52, HZ + 0.02));
  c += vec3(1.0, 0.6, 0.2) * (smoothstep(0.006, 0.004, r2) * 0.9 + 0.08 * exp(-r2 * r2 / 0.0012));
  return c;
}
// slope of one ring of ripples at world point w, from a drop at d0 that fell 'age' seconds ago
vec2 ring(vec2 w, vec2 d0, float age, float amp, float kk) {
  if (age > 8.0 || age < 0.0) return vec2(0.0);
  vec2 dv = w - d0; float r = length(dv) + 1e-4;
  float u = r - 0.30 * age;
  float sg = 0.03 + 0.04 * age;
  if (abs(u) > sg * 2.6) return vec2(0.0);
  float en = amp * exp(-age * 0.5) * smoothstep(0.0, 0.12, age) / (0.5 + r * 2.0);
  float ga = exp(-u * u / (sg * sg));
  float dh = en * ga * (kk * cos(kk * u) - 2.0 * u / (sg * sg) * sin(kk * u));
  return dv / r * dh;
}
`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec3 c;
  if (p.y >= HZ) {
    c = env(p);
  } else {
    // where this pixel lands on the water
    float zc = 0.22 / (HZ - p.y);
    vec2 w = vec2(p.x * zc, zc);
    // ripples too fine to draw far away are faded out
    float fine = zc * zc * px / 0.22;       // size of one pixel in world z
    vec2 g = vec2(0.0);
    for (int i = 0; i < 6; i++) {
      vec3 d = i == 0 ? vec3(q9, q10, q11) : i == 1 ? vec3(q12, q13, q14) : i == 2 ? vec3(q15, q16, q17) : i == 3 ? vec3(q18, q19, q20) : i == 4 ? vec3(q21, q22, q23) : vec3(q24, q25, q26);
      float kk = 210.0 / (0.45 + 0.55 * d.y);
      g += ring(w, vec2(d.x * d.y, d.y), d.z, 0.0055, kk) * smoothstep(1.2, 0.35, kk * fine);
    }
    for (int i = 0; i < 12; i++) {
      float fi = float(i);
      float per = 3.5 + 4.0 * h1(fi);
      float tt = time + h1(fi + 1.0) * per;
      float age = mod(tt, per), cyc = floor(tt / per);
      float dz = 0.45 + 3.2 * h1(fi + cyc * 3.1) * h1(fi + cyc * 1.3 + 4.0);
      float kk = 260.0 / (0.45 + 0.55 * dz);
      g += ring(w, vec2((h1(fi + cyc * 5.7 + 2.0) - 0.5) * 1.6 * dz, dz), age, 0.0019, kk) * smoothstep(1.2, 0.35, kk * fine);
    }
    // a light breeze on the surface
    vec2 wv = w * vec2(11.0, 26.0) + vec2(q1 * 0.3, q1 * 0.6);
    float n0 = fbm2(wv);
    vec2 gw = vec2(fbm2(wv + vec2(0.15, 0.0)) - n0, fbm2(wv + vec2(0.0, 0.15)) - n0) * 0.16 * smoothstep(3.0, 0.5, fine * 150.0);
    vec2 gr = g;
    g += gw;
    // mirror the far bank in the water, bent by the slope of the surface
    vec2 rp = vec2(p.x + g.x * 0.25 + gw.x * 0.6, HZ + (HZ - p.y) * 0.96 + gr.y * 0.3 + gw.y * 1.2 + 0.006 * sin(p.y * 520.0 + time * 2.5) * smoothstep(0.0, 0.05, HZ - p.y));
    rp.y = max(rp.y, HZ + 0.001);
    vec3 refl = env(rp);
    float fres = mix(0.45, 0.96, pow(sat(1.0 - (HZ - p.y) * 1.5), 2.0));
    c = refl * fres + vec3(0.006, 0.014, 0.014) * (1.0 - fres);
    // crests facing the window pick up its gold, the others a little sky
    vec2 toL = normalize(vec2(LAMP.x * 3.0 - w.x, 3.2 - w.y));
    float sl = dot(gr + gw * 0.25, toL);
    c += vec3(1.0, 0.60, 0.20) * max(sl, 0.0) * 0.9 * exp(-abs(p.x - LAMP.x) * 1.0) + vec3(0.10, 0.16, 0.15) * (max(-sl, 0.0) * 0.8 + abs(g.x) * 0.25);
    // the window's light lies down the water as a broken gold path
    float bandw = 0.016 + 0.11 * (HZ - p.y);
    float band = exp(-pow((p.x - LAMP.x + g.x * 0.5 + gw.x * 2.0) / bandw, 2.0));
    float glit = smoothstep(0.5, 0.95, nz(w * vec2(26.0, 70.0) + vec2(0.0, q1 * 1.3)) + gw.y * 9.0 + g.y * 1.5);
    c += vec3(1.0, 0.62, 0.22) * band * (0.05 + 0.75 * glit) * smoothstep(0.75, 0.05, HZ - p.y) * (0.8 + 0.4 * q4);
    // lily pads riding the ripples
    for (int i = 0; i < 6; i++) {
      float fi = float(i);
      vec2 pc = vec2((h1(fi + 31.0) - 0.5) * 1.5, 0.0) ; pc.y = 0.42 + 0.9 * h1(fi + 33.0); pc.x *= pc.y;
      pc += 0.02 * vec2(sin(q1 * 0.13 + fi), cos(q1 * 0.11 + fi * 2.0));
      float pr = 0.045 + 0.035 * h1(fi + 35.0);
      vec2 dv = w - pc + g * 0.02; float dr = length(dv);
      if (dr > pr) continue;
      float an = atan(dv.y, dv.x) + fi * 2.0;
      float pad = smoothstep(pr, pr - fine * 1.5, dr) * smoothstep(0.10, 0.16, abs(an - 6.2832 * floor(an / 6.2832 + 0.5)) + 0.25 * (1.0 - dr / pr));
      vec3 pcx = vec3(0.020, 0.045, 0.022) * (0.8 + 0.4 * sin(an * 9.0) * 0.3) + vec3(0.5, 0.3, 0.1) * smoothstep(0.6, 1.0, dr / pr) * 0.12 * exp(-abs(p.x - LAMP.x) * 2.0);
      c = mix(c, pcx, pad);
    }
    c *= 1.0 - 0.25 * sat(length(g) * 2.0) * (1.0 - fres);
  }
  // rain in the air, barely there
  float rn = nz(vec2(p.x * 120.0 + p.y * 9.0, p.y * 2.5 + time * 9.0));
  c += vec3(0.25, 0.3, 0.28) * smoothstep(0.86, 1.0, rn) * 0.06;
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.35, 0.26, 0.14) + texture(sampler_blur2, uv).rgb * vec3(0.22, 0.14, 0.06);
  ret = finish(c * 1.15, p, 0.55);
`,
});
