// Ladybug swarm: ladybirds on the wing, wing cases open and hind wings a blur, wheeling in one slow swirl round
// a drifting centre through soft-focus night foliage. Near ones are big and sharp, far ones small and dim.
// Nothing jumps: the song's energy smoothly speeds the swirl up and opens it wider, and the lights behind
// breathe with the bass, mids and treble.
HL.mk('Hearth - Ladybug swarm', {
  frame: `
if (s.T === undefined) { s.T = 0; s.spd = 0.6; s.wide = 0; }
s.spd += (0.45 + 0.6 * Math.min(1.5, s.vol) + 0.5 * Math.min(1.2, s.bs) - s.spd) * k(1.0);
s.T += dt * s.spd;
s.wide += (Math.min(1.2, s.bs) - s.wide) * k(0.9);
a.q7 = s.T; a.q29 = s.wide;
`,
  fn: `
// where ladybird fi is at swirl-time T: an oval orbit round the drifting centre, inner ones going round faster
vec2 bpos(float fi, float T) {
  vec2 C = vec2(0.40 * sin(0.21 * T) + 0.14 * sin(0.47 * T + 1.0), 0.15 * sin(0.29 * T + 0.5));
  float rad = (0.14 + 0.34 * fract(fi * 0.618 + 0.3)) * (1.0 + 0.45 * q29) * (1.0 + 0.18 * sin(T * 0.6 + fi * 2.0));
  float th = T * (0.75 + 0.5 * h1(fi + 3.0)) / (0.6 + rad * 2.0) + fi * 2.399;
  return C + rad * vec2(1.4 * cos(th), 0.85 * sin(th)) + 0.03 * vec2(sin(T * 1.3 + fi * 5.0), cos(T * 1.1 + fi * 3.0));
}
float ell(vec2 q, vec2 c, vec2 r, float e) { vec2 d = (q - c) / r; float l = length(d); return smoothstep(e, -e, (l - 1.0) * min(r.x, r.y)); }
// one ladybird in body space: x forward, body one unit long. open 0 = walking, 1 = flying. Returns rgb + alpha
vec4 bug(vec2 q, float open, float flap, float e) {
  if (dot(q, q) > 1.7) return vec4(0.0);
  vec3 col = vec3(0.0); float A = 0.0;
  float th = open * 1.08;
  // hind wings: long, smoky and see-through, beating fast
  if (open > 0.05) {
    for (int sI = 0; sI < 2; sI++) {
      float sg = sI == 0 ? 1.0 : -1.0;
      vec2 l = rot2(vec2(q.x, q.y * sg) - vec2(0.12, 0.06), th * 0.72 + 0.22 * flap);
      float wv = ell(l, vec2(-0.56, 0.02), vec2(0.58, 0.19), e + 0.03) * open;
      float vein = smoothstep(0.02, 0.0, abs(l.y - 0.08 - 0.12 * l.x * l.x)) * 0.5;
      vec3 wc = vec3(0.85, 0.72, 0.5) * (0.6 + vein);
      float wa = wv * 0.5;
      col = mix(col, wc, wa / max(A + wa * (1.0 - A), 0.001) * (1.0 - A) + 0.0); A = A + wa * (1.0 - A);
    }
  }
  // abdomen under the wing cases
  float ab = ell(q, vec2(-0.12, 0.0), vec2(0.33, 0.23), e);
  vec3 abc = vec3(0.07, 0.05, 0.04) * (0.7 + 0.5 * smoothstep(0.1, 0.0, abs(fract(q.x * 9.0) - 0.5) - 0.3));
  col = mix(col, abc, ab); A = max(A, ab);
  // the two red wing cases, each half of the dome, swung out about its shoulder
  for (int sI = 0; sI < 2; sI++) {
    float sg = sI == 0 ? 1.0 : -1.0;
    vec2 l = rot2(vec2(q.x, q.y * sg) - vec2(0.24, 0.03), th) + vec2(0.24, 0.03);
    float el = ell(l, vec2(-0.08, 0.0), vec2(0.43, 0.37), e) * smoothstep(-e, e, l.y);
    if (el > 0.001) {
      vec2 d = (l - vec2(-0.08, 0.0)) / vec2(0.43, 0.37);
      float rr = dot(d, d);
      vec3 red = mix(vec3(0.86, 0.15, 0.06), vec3(0.42, 0.03, 0.02), rr * rr);
      red *= 0.75 + 0.45 * sat(0.6 - d.y * 0.6 + d.x * 0.3);
      float sp = ell(l, vec2(-0.02, 0.17), vec2(0.075, 0.07), e) + ell(l, vec2(-0.28, 0.11), vec2(0.07, 0.065), e)
        + ell(l, vec2(-0.25, 0.27), vec2(0.055, 0.05), e) + ell(l, vec2(0.21, 0.02), vec2(0.06, 0.055), e);
      red = mix(red, vec3(0.03, 0.02, 0.02), sat(sp));
      // wet shine
      red += vec3(1.0, 0.9, 0.8) * 0.4 * ell(l, vec2(0.08, 0.21), vec2(0.08, 0.025), 0.025);
      red *= 1.0 - 0.5 * smoothstep(0.03, 0.0, l.y) * (1.0 - open);
      col = mix(col, red, el); A = max(A, el);
    }
  }
  // pronotum with its two pale patches, and the head
  float pr = ell(q, vec2(0.33, 0.0), vec2(0.14, 0.26), e);
  vec3 pc = vec3(0.035, 0.03, 0.03) + vec3(0.2) * ell(q, vec2(0.36, 0.0), vec2(0.03, 0.12), 0.05);
  pc = mix(pc, vec3(0.92, 0.88, 0.78), ell(vec2(q.x, abs(q.y)), vec2(0.37, 0.17), vec2(0.05, 0.065), e));
  col = mix(col, pc, pr); A = max(A, pr);
  float hd = ell(q, vec2(0.47, 0.0), vec2(0.07, 0.11), e);
  col = mix(col, vec3(0.03), hd); A = max(A, hd);
  // feelers
  vec2 fq = vec2(q.x - 0.5, abs(q.y) - 0.06);
  float fe = smoothstep(0.012 + e, 0.012 - e, abs(fq.y - fq.x * 0.9)) * step(0.0, fq.x) * step(fq.x, 0.11);
  col = mix(col, vec3(0.03), fe); A = max(A, fe);
  return vec4(col, A);
}
// soft discs of light, the way lamps and gaps in leaves blur behind a close subject
vec3 bokeh(vec2 p) {
  vec3 c = vec3(0.0);
  for (int i = 0; i < 9; i++) {
    float fi = float(i);
    vec2 pos = vec2((h1(fi + 0.5) - 0.5) * 1.9, (h1(fi + 9.5) - 0.5) * 1.0) + 0.05 * vec2(sin(q1 * 0.11 + fi * 2.0), cos(q1 * 0.09 + fi * 3.0));
    float rad = 0.06 + 0.11 * h1(fi + 4.0);
    float d = length(p - pos) / rad;
    float disc = smoothstep(1.0, 0.86, d) * (0.65 + 0.35 * smoothstep(0.6, 1.0, d));
    vec3 tint = mix(vec3(0.10, 0.17, 0.07), vec3(0.34, 0.22, 0.07), step(0.62, h1(fi + 7.0)));
    c += tint * disc * (0.30 + 0.15 * sin(q1 * 0.3 + fi * 1.9)) * (0.55 + 1.3 * (mod(fi, 3.0) < 0.5 ? q2 : (mod(fi, 3.0) < 1.5 ? q8 : q4)));
    rad *= 1.0;
  }
  return c;
}
`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  // background: deep foliage out of focus
  float bg = fbm(p * 1.6 + vec2(q1 * 0.02, 0.0));
  vec3 c = mix(vec3(0.012, 0.022, 0.014), vec3(0.05, 0.085, 0.04), bg * bg * 1.6);
  c += vec3(0.07, 0.05, 0.02) * smoothstep(0.9, 0.0, length(p - vec2(0.45, 0.3)));
  // big leaves hanging in the dark behind, far out of focus and swaying a little
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    vec2 lp = vec2(-0.75 + 0.42 * fi + 0.1 * sin(fi * 5.0), (mod(fi, 2.0) < 0.5 ? 0.38 : -0.42) + 0.08 * sin(fi * 3.0));
    float la = (mod(fi, 2.0) < 0.5 ? -1.5708 : 1.5708) + 0.5 * sin(fi * 2.3) + 0.06 * sin(q1 * 0.4 + fi * 2.0);
    float ll = 0.5 + 0.2 * h1(fi + 60.0);
    vec2 lq = rot2(p - lp, -la) / ll;
    float m = leafA(lq, 0.3, fi + 40.0, 0.07);
    float ribb = smoothstep(0.03, 0.0, abs(lq.y - (h1(fi + 41.0) - 0.5) * 0.45 * lq.x * (1.0 - lq.x)));
    c = mix(c, vec3(0.035, 0.07, 0.03) * (0.8 + 0.5 * bg) + vec3(0.03, 0.035, 0.012) * ribb, m * 0.75);
  }
  c += bokeh(p) * 0.85;
  // the swarm
  const int N = 20;
  for (int i = 0; i < N; i++) {
    float fi = float(i);
    float z = (fi + 0.5) / float(N);
    float size = mix(0.045, 0.14, z * z);
    vec2 pos = bpos(fi, q7);
    vec2 d = p - pos;
    if (dot(d, d) > size * size * 1.7) continue;
    vec2 vel = bpos(fi, q7 + 0.03) - pos;
    float ang = atan(vel.y, vel.x);
    float flap = sin(time * 43.0 + fi * 2.1);
    vec4 b = bug(rot2(d, -ang) / size, 0.84 + 0.10 * q2, flap, px / size * (1.0 + 2.0 * (1.0 - z)));
    b.rgb *= mix(0.5, 1.05, z);
    c = mix(c, b.rgb, b.a * mix(0.8, 1.0, z));
  }
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.22, 0.2, 0.14);
  ret = finish(c * 1.1, p, 0.6);
`,
});
