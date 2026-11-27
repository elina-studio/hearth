// Dew on the web: a spider's web hung with dew. Every beat plucks the web so a shiver and a ring of sparkle run
// out along the threads, the bass breathes the light behind it, the mids sway it in the air, and the treble
// sets single drops twinkling.
HL.mk('Hearth - Dew on the web', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  // soft lights far behind the web
  vec3 c = vec3(0.008, 0.017, 0.012) + vec3(0.018, 0.030, 0.016) * fbm(p * 1.5 + 2.0);
  for (int l = 0; l < 2; l++) {
    float fl = float(l);
    vec2 g = p * (2.6 + 1.7 * fl) + vec2(q1 * 0.02, fl * 3.0 + 0.02 * sin(q1 * 0.2)), id = floor(g), jf = h22(id + fl * 5.0);
    float rb = 0.20 + 0.20 * jf.x;
    float disc = smoothstep(rb, rb * 0.82, length(fract(g) - 0.3 - 0.4 * jf)) * step(0.35, h2(id + 1.0));
    vec3 bc = mix(vec3(0.75, 0.45, 0.12), vec3(0.25, 0.42, 0.16), step(0.5, jf.y));
    c += bc * disc * (0.045 + 0.05 * q2) * (1.0 - 0.3 * fl);
  }
  vec2 CW = vec2(0.10, 0.03);
  vec2 d0 = p - CW;
  float r0 = length(d0);
  // the web hangs in moving air; a pluck on the beat runs outward as a shiver
  float shiver = q3 * sin(r0 * 40.0 - q28 * 26.0) * exp(-q28 * 1.6);
  vec2 d = d0 + 0.006 * (1.0 + 1.6 * q8) * vec2(sin(q7 * 0.9 + p.y * 4.0), cos(q7 * 0.7 + p.x * 3.0)) + normalize(d0 + 1e-4) * 0.014 * shiver;
  d *= vec2(0.90, 1.04);
  float r = length(d), a = atan(d.y, d.x);
  float n = 23.0;
  float aw = a + 0.07 * sin(a * 3.0 + 1.0) + 0.03 * sin(a * 7.0);
  float sv = aw * n / TAU, si = floor(sv), f = fract(sv) - 0.5;
  float spoke = smoothstep(px * 1.3, px * 0.2, abs(f) * TAU / n * r) * smoothstep(0.012, 0.03, r);
  // sticky spiral: each span sags toward the hub between its two spokes
  float sag = 1.0 - (0.04 + 0.03 * h1(si)) * (4.0 * f * f);            // threads bow outward between spokes, pinned low at each spoke
  float u = pow(r / sag, 0.88);
  float dr = 0.036;
  float tv = u / dr - (si + 0.5) / n, ti = floor(tv), tf = fract(tv) - 0.5;
  float span = h2(vec2(ti, si));
  float there = step(0.07, span) * smoothstep(0.035, 0.06, r) * smoothstep(0.80, 0.70, r + 0.1 * h1(si + 7.0));
  float thread = smoothstep(px * 1.2, px * 0.2, abs(tf) * dr * 1.1) * there;
  float wave = exp(-pow((r - q28 * 0.60) / 0.06, 2.0)) * exp(-q28 * 1.1);
  vec3 silk = vec3(0.70, 0.74, 0.62);
  c += silk * (spoke * 0.20 + thread * 0.16) * (1.0 + 2.5 * wave + 0.5 * q2);
  // dew: beads strung along every thread, bigger ones here and there
  float m = floor(2.0 + r * 9.0);
  float bv = (f + 0.5) * m + (mod(ti, 2.0) < 0.5 ? 1.0 : -1.0) * (q27 * 0.22 + 0.25 * shiver), bi = floor(bv), bf = fract(bv) - 0.5;
  float bh = h2(vec2(ti * 7.0 + bi, si * 3.0 + 1.0)), bh2 = h1(bh * 91.0);
  vec2 bq = vec2(bf / m * TAU / n * r, tf * dr * 1.1);
  float big = step(0.93, bh);
  float brad = (0.0030 + 0.0030 * bh2 + 0.0050 * big) * step(0.2, bh2) * (1.0 + 0.25 * q2);
  float bd = length(bq);
  float bead = smoothstep(brad, brad * 0.75, bd) * there * step(0.0005, brad);
  // each drop is a tiny lens: dark at the top, a bright crescent at the bottom, one sharp glint
  vec2 bn = bq / max(brad, 1e-4);
  float lens = 0.20 + 0.9 * smoothstep(-0.3, 1.0, -bn.y) * smoothstep(1.0, 0.55, length(bn)) + 1.6 * smoothstep(0.30, 0.10, length(bn - vec2(-0.35, 0.35)));
  float tw = step(0.86, h2(vec2(bh * 50.0, floor(q7 * 7.0)))) * q4;
  float lit = 0.30 + 2.2 * wave + 1.4 * tw + 0.25 * q2;
  vec3 dew = mix(vec3(0.92, 0.95, 0.85), vec3(1.0, 0.80, 0.40), big * 0.8 + 0.3 * bh2);
  c += dew * bead * lit * lens;
  c += dew * big * there * step(0.0005, brad) * exp(-bd * bd / 0.00012) * 0.5 * lit;            // halo round the big drops
  float flare = big * there * step(0.0005, brad) * (smoothstep(0.0012, 0.0, abs(bq.y)) * exp(-abs(bq.x) / 0.012) + smoothstep(0.0012, 0.0, abs(bq.x)) * exp(-abs(bq.y) / 0.012));
  c += vec3(1.0, 0.92, 0.7) * flare * (0.15 + 1.2 * wave + 0.8 * tw);
  // on every beat a few fat drops let go and fall
  for (int i = 0; i < 7; i++) {
    float fi = float(i);
    vec2 st = CW + (h22(vec2(q5, fi)) - 0.5) * vec2(1.2, 0.7);
    float tt = q28 * (0.8 + 0.4 * h1(fi + q5));
    vec2 dq = p - (st - vec2(0.0, 0.75 * tt * tt + 0.02 * tt));
    float drop = smoothstep(0.0065, 0.0035, length(dq * vec2(1.0, 0.75)));
    float tail = smoothstep(0.0022, 0.0, abs(dq.x)) * step(0.0, dq.y) * exp(-dq.y / (0.02 + 0.12 * tt));
    float fade = smoothstep(1.3, 0.6, tt) * smoothstep(0.0, 0.05, tt);
    c += vec3(1.0, 0.86, 0.50) * (drop * 1.3 + tail * 0.5) * fade;
  }
  // the hub
  c += silk * 0.25 * smoothstep(px * 1.5, 0.0, abs(fract(r / 0.006) - 0.5) * 0.006) * smoothstep(0.036, 0.03, r) * smoothstep(0.004, 0.01, r);
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.55, 0.50, 0.32) + texture(sampler_blur2, uv).rgb * 0.25;
  ret = finish(c, p, 0.7);
`,
});
