// Fiddleheads: young ferns still rolled up tight, seen close and backlit, with soft ones out of focus behind.
// They unroll and roll back with the song, each beat nods the heads, the bass warms the light behind them
// and the treble glints on the fine russet hairs.
HL.mk('Hearth - Fiddleheads', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  ret = texture(sampler_main, uv).rgb * 0.9;
`,
  cfn: `
// one crozier: foot x, top height y1, lean, head radius R0, which way it rolls, softness, turns still rolled
vec4 crozier(vec2 p, float x0, float y1, float lean, float R0, float dir, float px, float turns, float sd, float dim) {
  vec3 col = vec3(0.0); float A = 0.0;
  vec3 g0 = vec3(0.16, 0.25, 0.10) * dim, g1 = vec3(0.50, 0.62, 0.28) * dim, hair = vec3(0.90, 0.62, 0.28) * dim;
  vec2 T = vec2(x0 + lean, y1);
  if (abs(p.x - x0 - lean * 0.5) > R0 * 2.6 + abs(lean) + 0.05 || p.y > y1 + R0 * 1.6) return vec4(0.0);
  float ws = R0 * 0.20;
  // the stalk, bowing a little
  float ty = sat((p.y + 0.62) / (y1 + 0.62));
  float sx = x0 + lean * ty * ty;
  float dx = p.x - sx;
  if (p.y < y1) {
    float w = ws * (1.25 - 0.25 * ty);
    float a = smoothstep(px, -px, abs(dx) - w);
    vec3 cc = mix(g0, g1, sat(0.5 - dir * dx / w * 0.5)) ;
    float hh = h1(floor(p.y * 260.0) + sd * 7.0);
    float br = step(0.62, hh) * smoothstep(0.22, 0.08, abs(fract(p.y * 260.0) - 0.5)) * step(abs(dx), w + R0 * (0.05 + 0.16 * (hh - 0.62) / 0.38)) * (1.0 - a) * 0.7;
    col = mix(col, hair * (0.6 + 1.2 * q4 * hh), br); A = max(A, br * 0.85);
    col = mix(col, cc, a); A = max(A, a);
  }
  // the rolled head
  vec2 C = T + vec2(dir * R0, 0.0);
  vec2 d = p - C;
  float r = length(d), ph = atan(d.y, -dir * d.x);
  if (ph < 0.0) ph += TAU;
  float b = 0.20, tmax = turns * TAU;
  for (int n = 0; n < 4; n++) {
    float th = ph + TAU * float(n);
    if (th > tmax) break;
    float rs = R0 * exp(-b * th);
    float fade = 1.0 - 0.5 * th / tmax;
    float w = ws * exp(-b * th * 0.75) * (th > tmax - 0.5 ? (tmax - th) / 0.5 * 0.6 + 0.4 : 1.0);
    float e = r - rs;
    float bud = max(0.0, sin(th * 9.0 + sd)) * w * 1.3;                      // folded leaflets tucked inside the roll
    float a = smoothstep(px, -px, e > 0.0 ? e - w : -e - w - bud);
    vec3 cc = mix(g1, g0, sat(0.5 - e / w * 0.5));
    cc = mix(cc, g1 * 1.1, step(e, -w) * 0.6);
    float hh = h1(floor(th * 22.0) + sd * 3.0 + float(n));
    float brs = step(0.45, hh) * smoothstep(0.24, 0.08, abs(fract(th * 22.0) - 0.5)) * step(w, e) * step(e, w + R0 * (0.05 + 0.15 * hh) * fade) * step(float(n), 0.5);
    col = mix(col, hair * (0.6 + 1.2 * q4 * hh), brs * (1.0 - A)); A = max(A, brs * 0.85);
    col = mix(col, cc, a); A = max(A, a);
  }
  return vec4(col, A);
}
`,
  comp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  vec3 c = mix(vec3(0.014, 0.022, 0.012), vec3(0.070, 0.085, 0.040), exp(-length(p - vec2(0.30, 0.22)) * 1.8));
  // soft blobs of light far behind
  for (int i = 0; i < 8; i++) {
    float fi = float(i);
    vec2 bp = vec2(-0.8 + 1.6 * h1(fi + 61.0), -0.4 + 0.8 * h1(fi + 63.0)) + 0.04 * vec2(sin(q7 * 0.10 + fi), cos(q7 * 0.13 + fi * 2.0));
    float rr = 0.10 + 0.14 * h1(fi + 65.0);
    c += mix(vec3(0.20, 0.30, 0.12), vec3(0.50, 0.38, 0.14), h1(fi + 67.0)) * smoothstep(rr, rr * 0.5, length(p - bp)) * (0.05 + 0.05 * q2 + 0.03 * q3 * h1(fi));
  }
  c += vec3(0.60, 0.45, 0.16) * (0.08 + 0.12 * q2) * exp(-dot(p - vec2(0.30, 0.22), p - vec2(0.30, 0.22)) / 0.12);
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float x0, y1, R0, dir, soft, dim;
    if (i == 0) { x0 = -0.62; y1 = -0.02; R0 = 0.060; dir = 1.0; soft = 7.0; dim = 0.55; }
    else if (i == 1) { x0 = 0.66; y1 = -0.14; R0 = 0.055; dir = -1.0; soft = 8.0; dim = 0.50; }
    else if (i == 2) { x0 = 0.42; y1 = -0.30; R0 = 0.040; dir = 1.0; soft = 3.0; dim = 0.75; }
    else if (i == 3) { x0 = -0.22; y1 = 0.00; R0 = 0.125; dir = 1.0; soft = 1.0; dim = 1.0; }
    else if (i == 4) { x0 = 0.24; y1 = 0.13; R0 = 0.095; dir = -1.0; soft = 1.0; dim = 1.0; }
    else { x0 = 0.02; y1 = -0.27; R0 = 0.055; dir = 1.0; soft = 1.0; dim = 0.95; }
    float un = 0.5 + 0.5 * sin(q27 * 0.30 + fi * 1.7);                      // 1 = most unrolled
    float turns = 2.7 - 1.3 * un;
    y1 += 0.05 * un + 0.010 * q3;
    R0 *= 1.0 + 0.22 * un;
    float lean = dir * (0.03 + 0.02 * sin(q7 * 0.5 + fi * 2.0) * (1.0 + q8) + 0.012 * q3);
    vec4 f = crozier(p, x0, y1, lean, R0, dir, px * soft, turns, fi + 1.0, dim * (0.85 + 0.35 * q2));
    c = mix(c, f.rgb, f.a);
  }
  // pollen motes
  vec2 mg = p * 8.0 + vec2(q7 * 0.04, q7 * 0.03), mi = floor(mg), mf = fract(mg) - 0.5 - 0.6 * (h22(mi) - 0.5);
  c += vec3(1.0, 0.92, 0.65) * exp(-dot(mf, mf) / 0.003) * step(0.6, h2(mi + 3.0)) * (0.10 + 0.25 * q4 + 0.10 * q3) * (0.5 + 0.5 * sin(q7 * 0.8 + h2(mi) * TAU));
  ret = finish(c, p, 0.8);
`,
});
