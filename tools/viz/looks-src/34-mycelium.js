// Mycelium, deep: you sink slowly down through layer after layer of web, each one swelling toward you and
// passing by as the next rises out of the dark. Every beat pushes you a notch deeper and steps gold sparks
// along the cords, the bass brightens the nearest layer and the treble shimmers in the fine hairs.
HL.mk('Hearth - Mycelium', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  fn: `
// nearest and second-nearest cell point: x = F1, y = F2, z = a hash of the pair of cells the edge lies between
vec3 vor(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  float f1 = 9.0, f2 = 9.0; float i1 = 0.0, i2 = 0.0;
  for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
    vec2 g = vec2(float(x), float(y));
    vec2 o = h22(i + g) * 0.8 + 0.1;
    float d = length(g + o - f);
    float hid = h2(i + g + 3.3);
    if (d < f1) { f2 = f1; i2 = i1; f1 = d; i1 = hid; } else if (d < f2) { f2 = d; i2 = hid; }
  }
  return vec3(f1, f2, fract(i1 * 7.0 + i2 * 7.0));
}
`,
  warp: `
  vec2 p = P(uv);
  vec3 prev = texture(sampler_main, uv).rgb;
  vec3 c = mix(vec3(0.016, 0.012, 0.007), vec3(0.050, 0.036, 0.018), fbm(p * 5.0)) * (0.7 + 0.5 * nz(p * 70.0));
  vec3 pale = vec3(0.80, 0.82, 0.66);
  c *= 0.6;
  float z = q7 * 0.035 + q27 * 0.045;
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float t = fract(z + fk / 3.0), lay = floor(z + fk / 3.0) * 3.0 + fk;
    float sc = 6.0 * exp(-t * 1.6);                                 // far and fine at first, wide and close at the end
    float al = smoothstep(0.0, 0.25, t) * smoothstep(1.0, 0.75, t);
    vec2 pp = rot2(p - vec2(0.05 * sin(q7 * 0.1), 0.0), lay * 1.3 + t * 0.5) * sc + lay * 7.7;
    vec2 wp = pp + 0.35 * vec2(fbm(pp * 0.9) - 0.5, fbm(pp * 0.9 + 7.0) - 0.5);
    vec3 v1 = vor(wp);
    float e1 = v1.y - v1.x;
    float w1 = (0.0035 + 0.0035 * v1.z) * sc * (1.0 + 0.4 * q8) * (0.5 + 1.3 * t);
    float cord = smoothstep(w1, w1 * 0.25, e1);
    vec3 v2 = vor(wp * 2.6 + 3.0);
    float hair = smoothstep(0.05, 0.01, v2.y - v2.x) * step(0.4, v2.z) * (1.0 - t);
    vec3 tint = mix(vec3(0.50, 0.58, 0.44), pale, t);
    c += tint * (cord * (0.30 + 0.12 * v1.z) + hair * (0.06 + 0.10 * q4)) * al * (0.25 + 0.5 * t + 0.5 * q2 * t);
    float band = fract((wp.x + wp.y * 0.7) * 0.6 - q27 * 0.5 - q7 * 0.10 + v1.z * 3.0);
    c += vec3(1.0, 0.78, 0.30) * smoothstep(0.06, 0.0, abs(band - 0.5)) * cord * step(0.5, v1.z) * al * t * (0.7 + 1.0 * q3);
    float knot = smoothstep(0.20, 0.0, e1) * smoothstep(0.62, 0.5, v1.x) * smoothstep(0.42, 0.5, v1.x);
    c += vec3(1.0, 0.70, 0.28) * knot * al * t * (0.06 + 0.5 * q2 + 0.3 * q3);
  }
  ret = max(c, prev * 0.55);
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.28, 0.22, 0.11) + texture(sampler_blur2, uv).rgb * vec3(0.10, 0.07, 0.03);
  ret = finish(c, p, 0.75);
`,
});
