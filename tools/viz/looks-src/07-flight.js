// Three looks bred from "martin - angel flight" (the house favourite): the same bones - faint shapes, a current
// that smears them into ribbons, and an endless fly-through of layers - with Hearth's colours and new currents.
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

  // Lantern flight: gold ribbons with moss-green shadows, on a grid of round eddies
  flight('Hearth - Lantern flight', {
    shape: { r: 1, g: 0.62, b: 0.12, r2: 0.10, g2: 0.30, b2: 0.06, a2: 0.3, sides: 24 },
    shapeEq: 'a.rad*=0.6;',
    dots: 'a.r=1;a.g=.8;a.b=.4;', line: 'a.r=.5;a.g=.6;a.b=.2;',
    current: `vec2 t = c0 * 0.022;
  vec2 flow = vec2(sin(t.y) * cos(t.x * 0.5), -sin(t.x) * cos(t.y * 0.5)) * 1.6 + clamp(tan(t * 0.5), -6.0, 6.0) * 0.15;`,
    layers: 4, speed: '1.0', turn: '1.5708',
    grade: 'r = vec3(r.r * 1.0 + r.b * 0.2, r.g * 0.88 + r.b * 0.2, r.b * 0.35) * 0.85;',
  });

  // Willow flight: the original current with wider eddies, in olive and old gold, three layers a third of a turn apart
  flight('Hearth - Willow flight', {
    shape: { r: 0.50, g: 0.60, b: 0.16, r2: 0.95, g2: 0.62, b2: 0.10, a2: 0.3, sides: 5 },
    shapeEq: 'a.rad*=0.7;',
    dots: 'a.r=.8;a.g=1;a.b=.4;', line: 'a.r=.9;a.g=.7;a.b=.2;',
    current: `vec2 t = c0 * 0.019;
  vec2 flow = clamp(tan(t), -12.0, 12.0) * cos(t.yx * t.yx);`,
    layers: 3, speed: '0.9', turn: '2.0944',
    grade: 'r = vec3(r.r * 0.95 + r.g * 0.1, r.g * 0.80 + r.b * 0.2, r.b * 0.3) * 0.85;',
  });

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
