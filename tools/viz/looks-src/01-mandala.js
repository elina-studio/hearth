// Leaf mandala: a rosette that never stops opening. Rings of real leaves are born at the gold heart, grow
// outward and pass the edge of the screen. It is built to dance: every beat opens the rosette a notch and turns
// the rings against each other, the inner rings swell with the bass, the middle with the mids, the outer with the
// treble, and a gold ring round the heart is the song's own wave.
HL.mk('Hearth - Leaf mandala', {
  fn: `
const float G = 0.30;                     // ring spacing, in log radius
const float R0 = 0.05;
// where a pixel sits in one ring's leaf: xy = leaf space, z = leaf length, w = half width. Each ring has its own
// kind of leaf: elm, willow, oak, ginkgo, heart, fern, round and round
vec4 ringQ(float j, float r, float th, float z, out float sd, out float kind) {
  kind = mod(j, 6.0);
  float n = mod(j, 2.0) < 0.5 ? 8.0 : 16.0;
  float w = kind < 0.5 ? 0.36 : (kind < 1.5 ? 0.15 : (kind < 2.5 ? 0.36 : (kind < 3.5 ? 0.40 : (kind < 4.5 ? 0.44 : 0.23))));
  float lenr = kind < 0.5 ? 2.9 : (kind < 1.5 ? 2.5 : (kind < 2.5 ? 2.7 : (kind < 3.5 ? 2.0 : (kind < 4.5 ? 2.4 : 2.5))));
  float R = R0 * exp((j + z) * G);
  float wb = smoothstep(0.30, 0.09, R), wt = smoothstep(0.22, 0.55, R);
  float swell = 1.0 + 0.03 * sin(q1 * 0.9 - j * 1.1) + 0.20 * (wb * q2 + (1.0 - wb - wt) * q8 + wt * q4 * 0.8);
  float L = R * (exp(G * lenr) - 1.0) * swell;
  float cell = TAU / n;
  float dir = mod(j, 2.0) < 0.5 ? 1.0 : -1.0;
  // every third ring is a fast one that keeps spinning; the rest sway and turn a notch on each beat
  float fast = mod(j, 3.0) < 0.5 ? 1.0 : 0.0;
  float off = (dir > 0.0 ? 0.0 : cell * 0.5) + dir * (0.2 * sin(q1 * 0.17 + j * 1.7) + q1 * (0.015 + 0.16 * fast) + q27 * 0.09);
  float da = mod(th - off + cell * 0.5, cell) - cell * 0.5;
  sd = kind * 7.0 + 1.0;
  return vec4(vec2(r * cos(da) - R * 0.85, r * sin(da)) / L, L, w);
}
`,
  warp: `
  vec2 p = P(uv);
  float px = 1.0 / texsize.y;
  float r = length(p) + 1e-5, th = atan(p.y, p.x) + q1 * 0.02;
  float z = q1 * 0.045 + q27 * 0.085;
  float u = log(r / R0) / G - z;
  float j0 = floor(u);
  vec3 c = vec3(0.0); float A = 0.0;
  // innermost ring is on top: walk outward until the pixel is covered
  for (int k = 3; k >= -1; k--) {
    float j = j0 - float(k), sd, kind, rim;
    vec4 g = ringQ(j, r, th, z, sd, kind);
    if (g.x < 0.0 || g.x > 1.0 || abs(g.y) > g.w * 1.3) continue;
    vec3 ca, cb; leafPal(fract(j * 0.19 + 0.05), ca, cb);
    vec4 l = leafK(g.xy, g.w, sd, px / g.z, ca, cb, 0.07, kind, rim);
    l.a *= step(0.0, g.x);
    if (l.a < 0.01) continue;
    // gold along the edge
    l.rgb += vec3(0.95, 0.70, 0.28) * smoothstep(0.80, 1.0, rim) * 0.22;
    // shade from the rings lying over this one, thrown a little outward, and darker toward its own base
    float sh = 0.0, sd2, k2;
    for (int m = 1; m <= 2; m++) {
      vec4 gs = ringQ(j - float(m), r * (1.0 - 0.035 * float(m)), th + 0.01, z, sd2, k2);
      sh = max(sh, leafAK(gs.xy, gs.w * 1.06, sd2, 0.06, k2));
    }
    l.rgb *= (1.0 - 0.6 * sh) * (0.55 + 0.45 * smoothstep(0.0, 0.5, g.x));
    c += (1.0 - A) * l.a * l.rgb; A += (1.0 - A) * l.a;
    if (A > 0.99) break;
  }
  c += (1.0 - A) * vec3(0.012, 0.02, 0.014);
  // a pulse of warm light that leaves the heart on each beat
  float wave = exp(-pow((r - (1.0 - q3) * 0.75) / 0.12, 2.0)) * q3;
  c *= 0.80 + 0.45 * wave + 0.12 * q2;
  // the gold heart: a seed head with its own slow spiral
  float hr = 0.058 * (1.0 + 0.22 * q2);
  float heart = smoothstep(hr, hr - 0.006, r);
  vec2 sp = vec2(log(r / hr) * 5.0 - q1 * 0.35, (th - q1 * 0.02) * 13.0 / TAU);
  float seeds = 0.5 + 0.5 * cos(TAU * (sp.x + sp.y)) * cos(TAU * (sp.x * 0.618 - sp.y));
  vec3 hc = mix(vec3(0.30, 0.16, 0.04), vec3(1.0, 0.72, 0.26), seeds * smoothstep(0.0, hr, r) + 0.25);
  hc *= 0.8 + 0.5 * q3;
  c = mix(c, hc, heart);
  c += vec3(1.0, 0.7, 0.3) * 0.25 * exp(-r * r / (hr * hr * 5.0)) * (0.5 + 0.6 * q2);
  ret = c;
`,
  // gold rays round the heart: the song's own wave, mirrored left and right
  waves: [{
    baseVals: { enabled: 1, samples: 144, sep: 0, scaling: 1, smoothing: 0.5, spectrum: 0, usedots: 0, thick: 1, additive: 0, r: 1, g: 0.78, b: 0.35, a: 1 },
    init_eqs_str: '', frame_eqs_str: '',
    point_eqs_str: `
var i = Math.round(a.sample * 143), ray = Math.floor(i / 3), tip = (i % 3) == 1 ? 1 : 0;
var th = 1.5707963 + (ray + 0.5) / 48 * 3.14159265;
var len = Math.min(0.075, Math.abs(a.value1) * 0.22);
var r = 0.066 * (1 + 0.22 * a.q2) + tip * (0.006 + len);
a.x = 0.5 + r * 0.5625 * Math.cos(th); a.y = 0.5 + r * 0.5625 * Math.sin(th);
a.r = 1; a.g = 0.74; a.b = 0.30; a.a = 0.9;
`,
  }, {
    baseVals: { enabled: 1, samples: 144, sep: 0, scaling: 1, smoothing: 0.5, spectrum: 0, usedots: 0, thick: 1, additive: 0, r: 1, g: 0.78, b: 0.35, a: 1 },
    init_eqs_str: '', frame_eqs_str: '',
    point_eqs_str: `
var i = Math.round(a.sample * 143), ray = Math.floor(i / 3), tip = (i % 3) == 1 ? 1 : 0;
var th = 1.5707963 - (ray + 0.5) / 48 * 3.14159265;
var len = Math.min(0.075, Math.abs(a.value1) * 0.22);
var r = 0.066 * (1 + 0.22 * a.q2) + tip * (0.006 + len);
a.x = 0.5 + r * 0.5625 * Math.cos(th); a.y = 0.5 + r * 0.5625 * Math.sin(th);
a.r = 1; a.g = 0.74; a.b = 0.30; a.a = 0.9;
`,
  }],
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.26, 0.20, 0.12);
  ret = finish(c * 1.05, p, 0.75);
`,
});
