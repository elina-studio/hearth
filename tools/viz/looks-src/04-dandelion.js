// Dandelion drift: a dandelion clock at dusk, backlit, letting its seeds go. Each seed is a real one - a
// parachute of fine hairs over a thin stalk and a brown seed - tumbling off on the wind and leaving a faint
// wisp of light. The wind gusts with the bass, and each beat makes the clock shimmer.
HL.mk('Hearth - Dandelion drift', {
  frame: `
s.gust = (s.gust || 0) + dt * (0.25 + 0.4 * Math.min(1.2, s.bs) + 1.6 * s.pulse);
a.q7 = s.gust;
`,
  fn: `
// hairs radiating from a point: v = offset from the hub, n hairs, lw = line width. Constant-width lines.
float hairs(vec2 v, float n, float turn, float lw) {
  float d = length(v), ang = atan(v.y, v.x) + turn, st = TAU / n;
  float a0 = floor(ang / st + 0.5) * st;
  return smoothstep(lw, lw * 0.25, d * abs(sin(ang - a0)));
}
// one flying seed, in its own space: hub of the parachute at the origin, stalk hanging down -y. Unit = hair length
float seed(vec2 q, float sd, float e, out float body) {
  body = 0.0;
  if (dot(q, q) > 9.0) return 0.0;
  float d = length(q), ang = atan(q.y, q.x);
  // the parachute: a shallow cup of hairs seen from the side, so the fan covers a bit more than the top half
  float fan = smoothstep(-0.55, -0.2, sin(ang)) ;
  float st = TAU / 22.0;
  float id = floor(ang / st + 0.5);
  float len = 0.78 + 0.22 * h1(id + sd);
  float a0 = id * st;
  float hair = smoothstep(0.02 + e, 0.006, d * abs(sin(ang - a0))) * smoothstep(len, len * 0.85, d) * fan;
  // each hair ends in a bright speck, and the whole cup has a soft glow
  float tip = smoothstep(0.07, 0.0, length(q - len * 0.97 * vec2(cos(a0), sin(a0)))) * fan;
  float glow = exp(-d * d * 1.6) * 0.20 * smoothstep(-0.9, 0.3, sin(ang));
  float hub = smoothstep(0.07, 0.02, d);
  // stalk and seed
  float bend = 0.10 * q.y * q.y * (h1(sd + 3.0) - 0.5);
  float stalk = smoothstep(0.016 + e, 0.008, abs(q.x - bend)) * step(q.y, 0.0) * step(-1.9, q.y);
  vec2 sq = (q - vec2(bend, -2.08)) / vec2(0.055, 0.22);
  body = smoothstep(1.0 + e * 8.0, 0.8, length(sq));
  return hair * 0.75 + tip * 0.8 + glow + hub * 0.6 + stalk * 0.55;
}
// the clock itself: a ball of seeds still holding on
float clock(vec2 d, float R, float px) {
  float r = length(d) / R, a = atan(d.y, d.x);
  if (r > 1.3) return 0.0;
  float I = 0.0;
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float K = 15.0 + 8.0 * fk, shell = 0.60 + 0.16 * fk;
    float aa = a + (fk - 1.0) * 0.035 * sin(q1 * 0.25 + fk) + fk * 0.7;
    float cell = TAU / K;
    float id = floor(aa / cell);
    float jit = h1(id + fk * 37.0);
    float ca = (id + 0.5 + 0.3 * (jit - 0.5)) * cell;
    float rt = shell * (0.96 + 0.08 * h1(id + fk * 11.0 + 5.0));
    // its stalk back to the centre
    float da = aa - ca;
    I += smoothstep(1.6 * px, 0.4 * px, r * R * abs(sin(da))) * smoothstep(0.05, 0.12, r) * step(r, rt) * 0.30;
    // its parachute, seen from all sorts of angles
    vec2 v = vec2(r * cos(da) - rt, r * sin(da));
    float dd = length(v);
    float tr = 0.20 - 0.03 * fk;
    I += hairs(v, 11.0, jit * 6.0 + q1 * 0.05, 1.3 * px / R) * smoothstep(tr, tr * 0.5, dd) * (0.42 + 0.3 * jit) * (1.0 + 0.9 * q3 * jit);
    I += exp(-dd * dd / (tr * tr * 0.3)) * 0.09;
  }
  // more seeds overlap toward the edge of the ball, so it glows there
  I += 0.16 * smoothstep(1.02, 0.86, r) * smoothstep(0.2, 0.95, r);
  I *= smoothstep(1.12, 0.98, r);
  return I;
}
`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  // dusk: dark green above, a low amber glow behind the clock
  vec3 bg = mix(vec3(0.012, 0.022, 0.016), vec3(0.035, 0.055, 0.035), sat(0.5 - p.y));
  bg += vec3(0.42, 0.22, 0.06) * exp(-length((p - vec2(-0.62, -0.42)) * vec2(0.9, 1.5)) * 2.6) * (0.5 + 0.6 * q2);
  bg += vec3(0.10, 0.09, 0.04) * fbm(p * 2.0 + vec2(q7 * 0.02, 0.0)) * 0.25;
  // wisps: last frame carried along by the wind, fading
  vec3 prev = texture(sampler_main, uv - vec2(0.0016, -0.0007) * (1.0 + q2)).rgb;
  vec3 c = bg;
  // the clock on its stem
  vec2 cc = vec2(-0.52, -0.10 + 0.006 * sin(q7 * 0.9));
  float R = 0.19 * (1.0 + 0.05 * q3);
  float sx = cc.x + 0.10 * pow(sat((cc.y - p.y) / 0.5), 1.8);
  float stem = smoothstep(0.007 + px, 0.007 - px, abs(p.x - sx)) * step(p.y, cc.y);
  c = mix(c, vec3(0.10, 0.12, 0.05) + vec3(0.2, 0.14, 0.05) * smoothstep(0.0, 0.007, p.x - sx), stem);
  c = mix(c, vec3(0.16, 0.13, 0.06), smoothstep(0.024, 0.018, length(p - cc)));
  float ck = clock(p - cc, R, px);
  c += vec3(1.0, 0.93, 0.76) * ck * (0.42 + 0.3 * q8 + 0.25 * q3);
  // seeds on the wind
  for (int i = 0; i < 20; i++) {
    float fi = float(i);
    float z = h1(fi + 2.0);
    float u = fract(q7 * (0.035 + 0.03 * h1(fi + 4.0)) + h1(fi + 6.0));
    float fromClock = step(h1(fi + 8.0), 0.7);
    vec2 start = mix(vec2(-1.05, (h1(fi + 10.0) - 0.5) * 0.9), cc + R * 0.8 * vec2(cos(fi * 2.4), sin(fi * 2.4)), fromClock);
    float rise = (h1(fi + 12.0) - 0.35) * 0.75;
    vec2 pos = start + vec2(u * 2.3, rise * u * (0.4 + 0.6 * u) + 0.05 * sin(u * 9.0 + fi * 3.0) * smoothstep(0.0, 0.2, u));
    float sc = mix(0.022, 0.058, z * z) * (0.75 + 0.5 * u);
    vec2 d = p - pos;
    if (dot(d, d) > sc * sc * 9.0) continue;
    float tilt = -0.35 + 0.45 * sin(q7 * (0.5 + 0.4 * h1(fi + 14.0)) + fi * 2.0) - 0.2 * q2;
    float body;
    float sI = seed(rot2(d, -tilt) / sc, fi, px / sc, body);
    float fade = smoothstep(0.0, 0.05, u) * smoothstep(1.0, 0.92, u) * mix(0.55, 1.0, z);
    c = mix(c, vec3(0.20, 0.13, 0.06), body * fade);
    c += vec3(1.0, 0.92, 0.74) * sI * fade * (0.5 + 0.5 * q4);
  }
  // wisps: what the seeds drew a moment ago, fading
  c = max(c, prev * 0.86 - 0.006);
  // the near bank: dark grass against the glow
  float gy = -0.43 + 0.04 * sin(p.x * 2.0 + 1.0) + 0.012 * sin(p.x * 9.0);
  float gx = p.x * 64.0 + 3.0 * nz(vec2(p.x * 9.0, 2.0)), gid = floor(gx);
  float gh = 0.02 + 0.13 * h1(gid) * h1(gid + 3.0);
  float tt = sat((p.y - gy) / gh);
  float blade = step(p.y, gy + gh) * smoothstep(0.34 * pow(1.0 - tt, 0.7), 0.22 * pow(1.0 - tt, 0.7), abs(fract(gx) - 0.5 - ((h1(gid + 5.0) - 0.5) * 0.7 + 0.25 * sin(q7 * 0.7 + gid * 0.3)) * tt * tt));
  c = mix(c, vec3(0.008, 0.014, 0.009), max(blade, smoothstep(gy + 0.004, gy - 0.004, p.y)));
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.30, 0.26, 0.18);
  ret = finish(c * 1.05, p, 0.6);
`,
});
