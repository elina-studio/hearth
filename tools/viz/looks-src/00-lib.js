// Hearth's own visualizer looks, written for this house (not from the MilkDrop packs).
// Each is a butterchurn preset. The warp shader paints the scene into the feedback buffer (so light can leave
// trails and the blur passes give a soft bloom), the comp shader grades it for the screen, and a little plain
// JS per frame (frame_eqs_str) turns the song into smooth motion: q1 music clock, q2 bass, q3 beat pulse,
// q4 treble, q5 beat count, q6 loudness, q8 mids, q27 beat count eased (so a beat can turn or push things one notch). page.html merges these over the packs; looks.json names them.
window.hearthLooks = {};
window.HL = (function () {
  const off = { enabled: 0 };
  const quiet = () => [0, 1, 2, 3].map(() => ({ baseVals: off, init_eqs_str: '', frame_eqs_str: '', point_eqs_str: '' }));
  const base = {
    decay: 1, gammaadj: 1, echo_zoom: 1, echo_alpha: 0, wave_a: 0, wave_mode: 0, additivewave: 0,
    zoom: 1, rot: 0, warp: 0, warpscale: 1, zoomexp: 1, cx: 0.5, cy: 0.5, dx: 0, dy: 0, sx: 1, sy: 1,
    ob_size: 0, ob_a: 0, ib_size: 0, ib_a: 0, mv_a: 0, brighten: 0, darken: 0, solarize: 0, invert: 0,
    darken_center: 0, wrap: 0, b1n: 0, b1x: 1, b2n: 0, b2x: 1, b3n: 0, b3x: 1, b1ed: 0,
  };
  // GLSL shared by every shader
  const lib = `
#define PI 3.14159265
#define TAU 6.2831853
float h1(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
vec2 rot2(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
float nz(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * nz(p); p = p * 2.03 + 17.1; a *= 0.5; } return v; }
float fbm2(vec2 p) { return 0.65 * nz(p) + 0.35 * nz(p * 2.1 + 9.3); }
// screen position: x across (about -0.89..0.89), y up (-0.5..0.5)
vec2 P(vec2 uv) { return vec2((uv.x - 0.5) * texsize.x / texsize.y, 0.5 - uv.y); }
vec2 UV(vec2 p) { return vec2(p.x * texsize.y / texsize.x + 0.5, 0.5 - p.y); }
float sat(float x) { return clamp(x, 0.0, 1.0); }

// Real-looking leaves of six kinds: 0 elm (toothed), 1 willow, 2 oak (lobed), 3 ginkgo (fan), 4 heart-shaped, 5 fern.
// lprof = the outline: half width (as a share of w) at t along the midrib.
float lprof(float t, float kind) {
  if (kind < 0.5) return pow(t, 0.55) * pow(1.0 - t, 0.72) * 1.86;
  if (kind < 1.5) return pow(sin(PI * pow(t, 0.75)), 0.85);
  if (kind < 2.5) return pow(t, 0.6) * pow(1.0 - t, 0.42) * 1.55 * (0.48 + 0.52 * pow(0.5 + 0.5 * cos(TAU * (t * 4.2 - 0.62)), 0.55));
  if (kind < 3.5) return 1.0;
  if (kind < 4.5) return pow(t, 0.33) * pow(1.0 - t, 0.62) * 1.52;
  return pow(t, 0.4) * pow(1.0 - t, 0.75) * 1.7 * (0.10 + 0.90 * pow(abs(sin(PI * t * 11.0)), 0.45));
}
// q is leaf space: x runs 0..1 from stem to tip, y across. w = half width (for the ginkgo, the half angle of
// its fan), sd = seed, e = size of one pixel in leaf space. ca = body colour, cb = the colour it mottles and
// edges toward. Returns rgb and alpha; rim comes back 1 at the edge. The stalk pokes out below x = 0.
vec4 leafK(vec2 q, float w, float sd, float e, vec3 ca, vec3 cb, float serr, float kind, out float rim) {
  rim = 0.0;
  if (q.x < -0.22 || q.x > 1.03 || abs(q.y) > w * 1.25 + 0.05) return vec4(0.0);
  bool fan = kind > 2.5 && kind < 3.5;
  // the midrib bows a little, a different way for each leaf
  float bow = fan ? 0.0 : (h1(sd + 1.0) - 0.5) * 0.45;
  float stalkY = q.y - bow * q.x + 0.9 * bow * q.x * q.x * step(q.x, 0.0);
  q.y -= bow * q.x * (1.0 - q.x);
  float t = sat(q.x);
  float ay = abs(q.y), sgn = q.y > 0.0 ? 1.0 : 0.0;
  float a, vf, side, mid, hw;
  if (fan) {
    // ginkgo: a fan with a wavy rim, a notch in the middle and fine veins spreading from the stalk
    float rr = length(q), an = atan(q.y, q.x);
    float lim = 0.97 - 0.03 * cos(an * 24.0 + sd) - 0.17 * exp(-an * an / 0.003);
    float d = max((abs(an) - w) * rr, rr - lim);
    a = smoothstep(e, -e, d) * step(0.0, q.x);
    rim = sat(1.0 + d / 0.10);
    float nvf = 30.0;
    vf = fract(an * nvf / (2.0 * w) + 0.5);
    float dv = min(vf, 1.0 - vf) * (2.0 * w) / nvf * rr;
    side = smoothstep(0.003 + e, 0.003 - e * 0.3, dv) * smoothstep(0.08, 0.3, rr) * 0.7;
    mid = 0.0; hw = w * rr + 0.001; t = rr;
  } else {
    // side veins sweep forward as they leave the midrib; teeth or lobes sit where they end
    float nv = kind < 0.5 ? 9.0 : (kind < 1.5 ? 15.0 : (kind < 2.5 ? 4.2 : (kind < 4.5 ? 6.0 : 11.0)));
    float sweep = kind < 1.5 ? 0.7 : (kind < 2.5 ? 0.35 : (kind < 4.5 ? 0.9 : 0.12));
    float ph = kind < 0.5 ? sgn * 0.5 + h1(sd + 2.0) : (kind < 2.5 && kind > 1.5 ? -0.62 + 0.5 : (kind > 4.5 ? 0.5 : sgn * 0.5));
    float prof = lprof(t, kind);
    float vc = (t - ay * (sweep + 1.1 * ay / w * step(kind, 0.5))) * nv + ph;
    vf = fract(vc);
    float tz = fract((t - w * prof * 1.8) * nv * 2.0 + ph * 2.0);
    float tooth = serr * tz * tz * smoothstep(0.05, 0.3, t) * step(kind, 0.5);
    hw = w * prof * (1.0 - tooth) + (nz(vec2(t * 6.0, sd)) - 0.5) * 0.08 * w * prof;
    float d = ay - hw;
    a = smoothstep(e, -e, d) * step(0.0, q.x) * step(q.x, 1.0);
    rim = sat(1.0 + d / (0.4 * w + 0.001));
    float dv = min(vf, 1.0 - vf) / nv;
    float vw = 0.0042 * (1.0 - 0.75 * rim);
    side = smoothstep(vw + e, vw - e * 0.3, dv) * (1.0 - rim * rim * rim) * smoothstep(0.02, 0.08, t);
    float mw = 0.0085 * (1.0 - 0.8 * t) + 0.002;
    mid = smoothstep(mw + e, mw - e * 0.3, ay) * step(q.x, 0.98);
  }
  // fine net of veinlets (only when the leaf is big enough on screen to show it)
  float net = nz(q * 85.0 + sd * 9.0);
  net = smoothstep(0.44, 0.5, net) * smoothstep(0.56, 0.5, net) * 0.3 * smoothstep(0.012, 0.003, e);
  // the blade puffs up between veins, and folds along the midrib so one half catches more light
  float puff = sin(PI * vf);
  float lightv = cos(TAU * vf + 0.6);
  float fold = fan ? 1.0 - 0.25 * abs(q.y) / (hw + 0.01) + 0.12 : mix(0.80, 1.16, smoothstep(-0.03, 0.03, q.y));
  // colour: mottled, browner toward tip and edge, darker along the midrib
  float mot = fbm2(q * vec2(4.0, 6.0) + sd * 31.0);
  float spots = smoothstep(0.74, 0.8, nz(q * 26.0 + sd * 5.0));
  vec3 c = mix(ca, cb, sat(mot * 1.5 - 0.45 + 0.6 * rim * rim + 0.3 * t * t));
  c *= (0.74 + (fan ? 0.12 : 0.30) * puff + (fan ? 0.05 : 0.13) * lightv + (fan ? 0.16 : 0.0)) * fold;
  c *= 1.0 - 0.28 * smoothstep(0.3 * w, 0.0, ay) * (1.0 - t) * (fan ? 0.0 : 1.0);
  c = mix(c, cb * 0.4, spots * (0.15 + 0.6 * rim));
  c *= 1.0 - 0.35 * rim * rim * rim;
  c += vec3(1.0, 0.92, 0.7) * 0.09 * smoothstep(0.0, 1.0, 1.0 - abs(q.y / (hw + 0.001) - 0.5) * 2.4) * (0.4 + 0.6 * mot);
  vec3 vcol = mix(c * 1.5 + vec3(0.06, 0.05, 0.02), mix(ca, cb, 0.5) * 1.5, 0.3);
  c = mix(c, vcol, sat(side * 0.7 + net));
  c = mix(c, vcol * 1.05, mid * 0.9);
  // stalk
  float sw = 0.0095;
  float st = smoothstep(sw + e, sw - e, abs(stalkY)) * step(-0.2, q.x) * step(q.x, 0.03);
  vec3 outc = mix(mix(ca, cb, 0.6) * 0.9, c, a);
  return vec4(outc, max(a, st));
}
vec4 leaf(vec2 q, float w, float sd, float e, vec3 ca, vec3 cb, float serr) { float rim; return leafK(q, w, sd, e, ca, cb, serr, 0.0, rim); }
// just the outline of a leaf (no stalk), for shadows: cheap
float leafAK(vec2 q, float w, float sd, float e, float kind) {
  if (q.x < 0.0 || q.x > 1.0) return 0.0;
  if (kind > 2.5 && kind < 3.5) { float rr = length(q); return smoothstep(e, -e, max((abs(atan(q.y, q.x)) - w) * rr, rr - 0.95)); }
  q.y -= (h1(sd + 1.0) - 0.5) * 0.45 * q.x * (1.0 - q.x);
  return smoothstep(e, -e, abs(q.y) - w * lprof(q.x, kind));
}
float leafA(vec2 q, float w, float sd, float e) { return leafAK(q, w, sd, e, 0.0); }
// autumn palette by seed: moss green, olive, gold, amber, russet
void leafPal(float s, out vec3 ca, out vec3 cb) {
  s = fract(s) * 5.0;
  if (s < 1.0) { ca = vec3(0.16, 0.30, 0.09); cb = vec3(0.34, 0.36, 0.10); }
  else if (s < 2.0) { ca = vec3(0.33, 0.36, 0.10); cb = vec3(0.56, 0.40, 0.10); }
  else if (s < 3.0) { ca = vec3(0.74, 0.52, 0.12); cb = vec3(0.58, 0.28, 0.07); }
  else if (s < 4.0) { ca = vec3(0.72, 0.36, 0.08); cb = vec3(0.42, 0.14, 0.05); }
  else { ca = vec3(0.50, 0.17, 0.06); cb = vec3(0.26, 0.10, 0.05); }
}
// rounded tree tops side by side, for a far bank against the sky
float trees(float x, float sc, float sd) {
  float v = x * sc + sd, id = floor(v), f = fract(v);
  float a = (0.45 + 0.55 * h1(id + sd)) * sqrt(max(0.0, 1.0 - pow(2.0 * f - 1.0, 2.0)));
  float v2 = v + 0.5, id2 = floor(v2), f2 = fract(v2);
  float b = (0.45 + 0.55 * h1(id2 + sd + 50.0)) * sqrt(max(0.0, 1.0 - pow(2.0 * f2 - 1.0, 2.0)));
  return max(a, b);
}
// the finish every look gets: soft shoulder, dark corners, a breath of grain so dark gradients do not band
vec3 finish(vec3 c, vec2 p, float vig) {
  c = c / (1.0 + 0.35 * c) * 1.3;
  c *= 1.0 - vig * smoothstep(0.3, 1.0, length(p * vec2(0.82, 1.0)));
  c += (h2(p * 913.0 + fract(time) * 7.0) - 0.5) * 0.012;
  return max(c, 0.0);
}
`;
  // JS run every frame: turns the song into smooth numbers (kept in a closure-free global so it survives frames)
  const music = (key) => `
var G = globalThis.__hl || (globalThis.__hl = {});
var s = G['${key}'];
if (!s || a.time < s.last) { s = G['${key}'] = { last: a.time, mt: 0, bs: 0, md: 0, tr: 0, vol: 0, pt: 0, pulse: 0, nb: 0, step: 0, cool: 0, av: 1, age: 9 }; }
var dt = Math.min(0.1, Math.max(0, a.time - s.last)); s.last = a.time; s.dt = dt;
var k = function (rate) { return 1 - Math.exp(-dt * rate); };
var b = Math.max(0, a.bass - 0.75), m = Math.max(0, a.mid - 0.75), t = Math.max(0, a.treb - 0.75), v = (a.bass + a.mid + a.treb) / 3;
s.bs += (b - s.bs) * k(b > s.bs ? 18 : 3);
s.md += (m - s.md) * k(m > s.md ? 14 : 3);
s.tr += (t - s.tr) * k(t > s.tr ? 20 : 4);
s.vol += (v - s.vol) * k(1.5);
s.av += (a.bass - s.av) * k(0.8);
s.cool -= dt; s.hit = 0; s.age += dt;
if (a.bass > 1.3 * s.av && a.bass > 1.15 && s.cool <= 0) { s.pt = 1; s.nb += 1; s.cool = 0.3; s.hit = 1; s.age = 0; }
s.pt *= Math.exp(-dt * 4.5);
s.pulse += (s.pt - s.pulse) * k(28);
s.step += (s.nb - s.step) * k(6);
s.mt += dt * (0.4 + 0.6 * Math.min(1.5, s.vol) + 1.5 * s.pulse);
a.q1 = s.mt; a.q2 = Math.min(1.6, s.bs); a.q3 = s.pulse; a.q4 = Math.min(1.6, s.tr); a.q5 = s.nb; a.q6 = s.vol;
a.q8 = Math.min(1.6, s.md); a.q27 = s.step; a.q28 = s.age;
s.raw = [a.bass, a.mid, a.treb];
`;
  const mk = (name, o) => {
    const key = name.replace(/[^a-z]/gi, '');
    window.hearthLooks[name] = {
      baseVals: Object.assign({}, base, o.base || {}), shapes: quiet(), waves: quiet().map((w, i) => (o.waves && o.waves[i]) || w),
      init_eqs_str: `if (globalThis.__hl) globalThis.__hl['${key}'] = null;`,
      frame_eqs_str: music(key) + (o.frame || ''), pixel_eqs_str: '', pixel_eqs: '',
      warp: `${lib}\n${o.fn || ''}\nshader_body {\n${o.warp}\n}`,
      comp: `${lib}\n${o.cfn || ''}\nshader_body {\n${o.comp || 'vec2 p = P(uv); vec3 c = texture(sampler_main, uv).rgb; ret = finish(c, p, 0.5);'}\n}`,
    };
  };
  return { mk, lib };
})();
