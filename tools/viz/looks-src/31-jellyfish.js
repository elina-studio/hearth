// Jellyfish: pale jellyfish drift up through dark water over the stream bed. Every beat is one squeeze of
// each bell and one push upward, their tentacles trail and whip behind, the bass brightens the light on the
// bed and the glow inside the bells, and the treble sparkles the plankton.
HL.mk('Hearth - Jellyfish', {
  frame: `a.q7 = (s.tt = (s.tt || 0) + dt);`,
  warp: `
  vec2 p = P(uv);
  vec3 prev = texture(sampler_main, uv).rgb;
  // stream bed: dark pebbles under rippling light
  vec2 pg = p * 7.0 + 0.6 * vec2(nz(p * 3.0), nz(p * 3.0 + 4.0)), pi_ = floor(pg), pf = fract(pg) - 0.5 - 0.5 * (h22(pi_) - 0.5);
  float peb = smoothstep(0.42, 0.22, length(pf * vec2(1.0, 1.25))) * (0.4 + 0.6 * h2(pi_ + 5.0));
  vec3 bed = mix(vec3(0.010, 0.028, 0.022), mix(vec3(0.030, 0.060, 0.045), vec3(0.060, 0.070, 0.040), h2(pi_)), peb * (0.6 + 0.4 * nz(p * 60.0)));
  vec2 cw = p * 3.2 + 0.35 * vec2(fbm2(p * 2.0 + q7 * 0.07), fbm2(p * 2.0 + 5.0 - q7 * 0.06));
  float ca = fbm(cw + vec2(q7 * 0.05, 0.0));
  float caust = pow(smoothstep(0.10, 0.0, abs(ca - 0.5)), 2.0);
  bed += vec3(0.20, 0.36, 0.24) * caust * (0.16 + 0.30 * q2);
  bed *= 0.75;
  vec3 c = max(prev * 0.72, bed);
  // plankton specks drifting down
  vec2 sg = p * 22.0 + vec2(0.3 * sin(q7 * 0.2 + p.y * 3.0), q7 * 0.25), si = floor(sg), sf = fract(sg) - 0.5 - 0.6 * (h22(si) - 0.5);
  c += vec3(0.55, 0.70, 0.50) * smoothstep(0.07, 0.0, length(sf)) * step(0.80, h2(si + 3.0)) * (0.10 + 0.5 * q4) * (0.5 + 0.5 * sin(q7 * 2.0 + h2(si) * TAU));
  for (int i = 0; i < 10; i++) {
    float fi = float(i);
    float h = h1(fi + 1.0), hb = h1(fi + 2.0);
    float s = 0.075 + 0.075 * hb;                                   // bell size, bigger ones are nearer
    float ph = q27 * PI + fi * 1.7;                                 // one squeeze per beat, each a little out of step
    float k = 0.5 + 0.5 * sin(ph);                                  // 1 = squeezed
    float lift = q7 * (0.012 + 0.012 * hb) + (q27 * PI - 0.6 * cos(ph)) * 0.012;    // rises fastest as the bell closes
    vec2 pos = vec2(-0.78 + 1.56 * fract(fi * 0.618 + 0.07) + 0.05 * sin(q7 * 0.21 + fi * 2.0), mod(lift + fi * 0.37 + h * 0.2, 1.6) - 0.80 + s);
    vec2 q = p - pos;
    float L = s * (3.0 + 1.5 * h);
    c += mix(vec3(0.92, 0.74, 0.42), vec3(0.50, 0.78, 0.64), h) * 0.05 * (0.55 + 0.55 * q2 + 0.35 * q3) * exp(-dot(q, q) / (s * s * 2.5));     // soft glow in the water around it
    if (abs(q.x) > s * 1.5 || q.y > s * 1.3 || q.y < -L - s) continue;
    float tilt = 0.20 * sin(q7 * 0.3 + fi * 3.0);
    q = rot2(q, tilt);
    float w = s * (1.0 - 0.24 * k), hg = s * (0.72 + 0.26 * k);
    float e = 1.5 / texsize.y;
    vec3 tint = mix(vec3(0.92, 0.74, 0.42), vec3(0.50, 0.78, 0.64), h);
    float lit = 0.55 + 0.55 * q2 + 0.35 * q3;
    // tentacles first, so the bell sits over them
    float ta = 0.0;
    for (int j = 0; j < 7; j++) {
      float fj = float(j);
      float t = sat(-q.y / L);
      float ax = w * (-0.82 + 1.64 * fj / 6.0);
      float lenj = 0.55 + 0.45 * h1(fi * 7.0 + fj);
      float sway = (0.10 + 0.10 * q3) * s * sin(t * (7.0 + 3.0 * h1(fj + fi)) - q7 * 2.2 - ph + fj * 1.3) * t + 0.35 * s * t * t * sin(q7 * 0.3 + fi * 3.0);
      float tx = ax * (1.0 - 0.55 * t) + sway;
      float th = e * 1.1 + 0.004 * s * (1.0 - t);
      ta = max(ta, smoothstep(th, 0.0, abs(q.x - tx)) * step(q.y, 0.0) * smoothstep(lenj, lenj * 0.55, t) * (0.30 + 0.25 * sin(t * 40.0 - q7 * 3.0 + fj)));
    }
    // two frilly arms in the middle
    for (int j = 0; j < 2; j++) {
      float fj = float(j);
      float t = sat(-q.y / (L * 0.55));
      float tx = w * (fj - 0.5) * 0.35 * (1.0 - t) + 0.10 * s * sin(t * 9.0 - q7 * 1.6 - ph + fj * 2.0) * t;
      float th = s * 0.11 * (1.0 - t) * (0.7 + 0.3 * sin(t * 30.0 + fj * 2.0)) + e;
      ta = max(ta, smoothstep(th, th * 0.3, abs(q.x - tx)) * step(q.y, 0.0) * step(t, 0.999) * (1.0 - t) * 0.55);
    }
    c += tint * ta * lit * 0.55;
    // the bell: a dome with a scalloped hem, clear in the middle and bright at the rim
    vec2 u = vec2(q.x / w, q.y / hg);
    float d = length(u);
    float hem = -0.16 - 0.07 * cos(u.x * 16.0) * (0.6 + 0.4 * k);
    float bell = smoothstep(e / s, -e / s, d - 1.0) * smoothstep(hem - e / hg, hem + e / hg, u.y);
    float rim = pow(sat(d), 4.0);
    float ribs = 0.5 + 0.5 * cos(asin(clamp(u.x / max(sqrt(max(1.0 - u.y * u.y * 0.8, 0.02)), 0.15), -1.0, 1.0)) * 9.0);
    float gut = exp(-dot(u - vec2(0.0, 0.25), u - vec2(0.0, 0.25)) * 7.0);
    float a = bell * (0.16 + 0.50 * rim + 0.14 * ribs * (1.0 - rim));
    vec3 bc = tint * (0.55 + 0.45 * rim) * lit + vec3(1.0, 0.80, 0.45) * gut * (0.22 + 0.6 * q2 + 0.4 * k);
    c = mix(c, bc, sat(a + bell * gut * 0.5));
  }
  ret = c;
`,
  comp: `
  vec2 p = P(uv);
  vec3 c = texture(sampler_main, uv).rgb;
  c += texture(sampler_blur1, uv).rgb * vec3(0.22, 0.26, 0.20) + texture(sampler_blur2, uv).rgb * vec3(0.10, 0.14, 0.11);
  ret = finish(c * 1.1, p, 0.8);
`,
});
