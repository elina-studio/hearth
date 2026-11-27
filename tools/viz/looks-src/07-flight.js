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
    dots: 'a.r=1;a.g=.8;a.b=.4;', line: 'a.r=.5;a.g=.6;a.b=.2;',
    current: `vec2 t = c0 * 0.022;
  vec2 flow = vec2(sin(t.y) * cos(t.x * 0.5), -sin(t.x) * cos(t.y * 0.5)) * 1.6 + clamp(tan(t * 0.5), -6.0, 6.0) * 0.15;`,
    layers: 4, speed: '1.0', turn: '1.5708',
    grade: 'r = vec3(r.r * 1.0 + r.b * 0.2, r.g * 0.95 + r.b * 0.25, r.b * 0.35);',
  });

  // Moss flight: green and gold vines that wind round the middle, three layers a third of a turn apart
  flight('Hearth - Moss flight', {
    shape: { r: 0.55, g: 0.85, b: 0.20, r2: 0.9, g2: 0.55, b2: 0.05, a2: 0.3, sides: 6 },
    dots: 'a.r=.8;a.g=1;a.b=.4;', line: 'a.r=.9;a.g=.7;a.b=.2;',
    current: `float rr = length(c0) + 1.0, an = atan(c0.y, c0.x);
  vec2 pol = vec2(log(rr) * 5.0, an * 5.0);
  vec2 f = clamp(tan(pol), -8.0, 8.0) * cos(pol.yx * pol.yx * 0.15);
  vec2 er = c0 / rr, et = vec2(-er.y, er.x);
  vec2 flow = (er * f.x + et * f.y) * 0.8;`,
    layers: 3, speed: '0.8', turn: '2.0944',
    grade: 'r = vec3(r.r * 0.95, r.g * 0.9 + r.b * 0.2, r.b * 0.3) ;',
  });

  // Ember flight: slow amber and russet ribbons on a slanted weave, like sparks rising up a chimney
  flight('Hearth - Ember flight', {
    shape: { r: 1, g: 0.42, b: 0.08, r2: 0.55, g2: 0.10, b2: 0.04, a2: 0.35, sides: 4 },
    dots: 'a.r=1;a.g=.6;a.b=.25;', line: 'a.r=1;a.g=.4;a.b=.1;',
    current: `vec2 t = vec2(c0.x + c0.y, c0.x - c0.y) * 0.016;
  vec2 f = clamp(tan(t), -12.0, 12.0) * cos(t.yx * t.yx);
  vec2 flow = vec2(f.x + f.y, f.x - f.y) * 0.7 + vec2(0.0, -0.25);`,
    layers: 4, speed: '0.7', turn: '0.7854',
    grade: 'r = vec3(r.r * 1.05 + r.b * 0.2, r.g * 0.85 + r.b * 0.1, r.b * 0.25);',
  });
})();
