// Dusk flight, bred from "martin - angel flight" (the house favourite): the same bones - faint shapes, a current
// that smears them into ribbons, and an endless fly-through of layers - in pale gold with teal shadows.
(function () {
  const packs = window.butterchurnPresets && (window.butterchurnPresets.default || window.butterchurnPresets);
  const src = packs && packs.getPresets()['martin - angel flight'];
  if (!src) return;
  const flight = (name, o) => {
    const p = JSON.parse(JSON.stringify(src));
    // the drifting shapes that become the ribbons
    Object.assign(p.shapes[2].baseVals, o.shape);
    p.shapes[2].frame_eqs_str += o.shapeEq || '';
    // the cloud of specks and the thin line
    p.waves[0].point_eqs_str = p.waves[0].point_eqs_str.replace('a.r=1;a.g=.5;a.b=1;', o.dots);
    p.waves[1].point_eqs_str = p.waves[1].point_eqs_str.replace('a.r=.4;a.g=.2;a.b=.7;', o.line);
    p.frame_eqs_str += 'a.mv_a=0;' + (o.frame || '');
    p.warp = ` shader_body {
  vec2 c0 = (uv - 0.5) * vec2(1280.0, 720.0);
  ${o.current}
  ret = 0.99 * texture(sampler_main, uv + flow * vec2(1.0 / 1280.0, 1.0 / 720.0) * 12.0).xyz - 0.01;
 }`;
    p.comp = ` shader_body {
  vec2 u = (uv - 0.5) * aspect.xy;
  vec3 r = vec3(0.0);
  for (int i = 0; i < ${o.layers}; i++) {
    float fi = float(i);
    float dist = 1.0 - fract(fi / ${o.layers}.0 + q29 * ${o.speed});
    float inten = sqrt(dist) * (1.0 - dist * dist);
    float a = fi * ${o.turn};
    vec2 v = vec2(u.x * cos(a) - u.y * sin(a), u.x * sin(a) + u.y * cos(a));
    r = max(r, texture(sampler_main, fract(2.0 * v * dist + 0.5)).xyz * inten);
  }
  r *= 3.0;
  ${o.grade}
  r *= 1.0 - 0.5 * smoothstep(0.35, 0.95, length(u));
  ret = r;
 }`;
    window.hearthLooks[name] = p;
  };

  // Dusk flight: closest to the original - pale gold ribbons with deep teal shadows, eight ways round
  flight('Hearth - Dusk flight', {
    shape: { r: 1, g: 0.66, b: 0.22, r2: 0.05, g2: 0.30, b2: 0.34, a2: 0.3, sides: 5 },
    dots: 'a.r=1;a.g=.75;a.b=.5;', line: 'a.r=.3;a.g=.6;a.b=.6;',
    current: `vec2 t = c0 * 0.03;
  vec2 flow = clamp(tan(t), -12.0, 12.0) * cos(t.yx * t.yx);`,
    layers: 4, speed: '1.0', turn: '0.7854',
    grade: 'r = vec3(r.r * 1.0, r.g * 0.92 + r.b * 0.1, r.b * 0.75) * 0.95;',
  });
})();
