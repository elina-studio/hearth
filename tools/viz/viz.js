// Hearth visualizer renderer. Runs on the NucBox (Windows), started at sign-in by install.ps1.
//   node viz.js serve   the service the NAS helper calls (port 8790)
//   node viz.js bench   measures how fast this machine renders and picks the picture size
//   node viz.js loops   makes the ready-made loops (one per look) and uploads them to the helper
// For each song it renders MilkDrop (butterchurn) frame by frame from the song's own samples, so the
// picture follows the music, and streams video + song together as HLS, which the TV plays as one stream.
'use strict';
const fs = require('fs');
const path = require('path');
const http = require('http');
const os = require('os');
const crypto = require('crypto');
const { spawn } = require('child_process');

const HERE = __dirname;
const CFG_FILE = path.join(HERE, 'config.json');
const cfg = Object.assign({ helper: 'http://192.168.254.41:8765', token: '', port: 8790, width: 1280, height: 720, fps: 30, browser: 'msedge', keep: 6 },
  fs.existsSync(CFG_FILE) ? JSON.parse(fs.readFileSync(CFG_FILE, 'utf8')) : {});
const LOOKS = JSON.parse(fs.readFileSync(path.join(HERE, 'looks.json'), 'utf8'));
const WORK = process.env.HEARTH_VIZ_WORK || path.join(os.tmpdir(), 'hearth-viz');
const FFMPEG = process.env.FFMPEG || cfg.ffmpeg || 'ffmpeg';
const SR = 44100, N = 1024;
fs.mkdirSync(WORK, { recursive: true });

const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const saveCfg = () => fs.writeFileSync(CFG_FILE, JSON.stringify(cfg, null, 1));
const presetFor = look => { const l = LOOKS.find(x => String(x.n) === String(look)); return l ? l.preset : LOOKS[0].preset; };

// ---------------------------------------------------------------- browser
let browserP = null;
function browser() {
  if (!browserP) {
    const { chromium } = require('playwright-core');
    const opt = { headless: true, args: ['--ignore-gpu-blocklist', '--enable-gpu-rasterization', '--allow-file-access-from-files', '--autoplay-policy=no-user-gesture-required'] };
    if (process.env.CHROME_PATH) opt.executablePath = process.env.CHROME_PATH; else opt.channel = cfg.browser;
    if (process.env.HEARTH_VIZ_SOFTWARE) opt.args.push('--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader');
    browserP = chromium.launch(opt).then(b => { b.on('disconnected', () => { browserP = null; }); return b; }, e => { browserP = null; throw e; });
  }
  return browserP;
}

async function openPage(w, h) {
  const b = await browser();
  const p = await b.newPage({ viewport: { width: w, height: h } });
  const url = 'file:///' + path.join(HERE, 'page.html').replace(/\\/g, '/').replace(/^\//, '') + `?w=${w}&h=${h}`;
  await p.goto(url);
  await p.waitForFunction(() => window.ready === true, null, { timeout: 15000 });
  return p;
}

// three 1024-sample windows (mono, left, right) ending at sample `end`, as 0..255 bytes, base64
function windows(pcm, end) {
  const m = Buffer.alloc(N), l = Buffer.alloc(N), r = Buffer.alloc(N);
  const total = pcm.length / 4;
  for (let i = 0; i < N; i++) {
    const k = end - N + i;
    let a = 0, c = 0;
    if (k >= 0 && k < total) { a = pcm.readInt16LE(k * 4) / 32768; c = pcm.readInt16LE(k * 4 + 2) / 32768; }
    const q = v => Math.max(0, Math.min(255, Math.round(128 + v * 127)));
    l[i] = q(a); r[i] = q(c); m[i] = q((a + c) / 2);
  }
  return [m.toString('base64'), l.toString('base64'), r.toString('base64')];
}

// ---------------------------------------------------------------- ffmpeg helpers
function run(args, opts = {}) {
  return new Promise((res, rej) => {
    const p = spawn(FFMPEG, ['-hide_banner', '-loglevel', 'error', ...args], { stdio: ['ignore', opts.capture ? 'pipe' : 'ignore', 'pipe'] });
    const out = []; let err = '';
    if (opts.capture) p.stdout.on('data', d => out.push(d));
    p.stderr.on('data', d => { err += d; });
    p.on('error', rej);
    p.on('close', code => code === 0 ? res(Buffer.concat(out)) : rej(new Error('ffmpeg ' + code + ': ' + err.slice(-400))));
  });
}

// the whole song (from ss) as 16-bit stereo 44.1 kHz samples
const decode = (src, ss) => run([...(ss > 0 ? ['-ss', String(ss)] : []), '-i', src, '-vn', '-f', 's16le', '-ac', '2', '-ar', String(SR), '-'], { capture: true });

function encoder(args) {
  const p = spawn(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: ['pipe', 'ignore', 'pipe'] });
  let err = ''; p.stderr.on('data', d => { err += d; });
  p.done = new Promise(res => p.on('close', code => res({ code, err })));
  p.stdin.on('error', () => {});
  return p;
}

const write = (p, buf) => p.stdin.write(buf) ? null : new Promise(res => p.stdin.once('drain', res));

// draw every frame of `pcm` with `preset` and feed the JPEGs to `enc`; stops early when job.cancelled
async function drawFrames(pcm, preset, w, h, enc, job) {
  const page = await openPage(w, h);
  try {
    await page.evaluate(n => window.load(n, 0), preset);
    const frames = Math.floor(pcm.length / 4 / SR * cfg.fps);
    const t0 = Date.now();
    for (let f = 0; f < frames; f++) {
      if (job && job.cancelled) break;
      const [m, l, r] = windows(pcm, Math.floor(f / cfg.fps * SR));
      const jpg = await page.evaluate(([a, b, c, dt]) => window.frame(a, b, c, dt, 0.9), [m, l, r, 1 / cfg.fps]);
      const wait = write(enc, Buffer.from(jpg, 'base64'));
      if (wait) await wait;
      if (job) job.frames = f + 1;
    }
    return frames / ((Date.now() - t0) / 1000);
  } finally {
    await page.close().catch(() => {});
  }
}

// ---------------------------------------------------------------- song jobs
const jobs = new Map();   // id -> job
let active = null;
const queue = [];

function videoArgs(w, h) {
  return ['-vf', `scale=1280:720:flags=bicubic`, '-c:v', 'libx264', '-preset', 'veryfast', '-profile:v', 'high', '-level', '4.0', '-pix_fmt', 'yuv420p',
    '-r', String(cfg.fps), '-g', String(cfg.fps * 2), '-keyint_min', String(cfg.fps * 2), '-sc_threshold', '0', '-b:v', '4500k', '-maxrate', '6M', '-bufsize', '9M'];
}

async function runJob(job) {
  active = job;
  job.state = 'rendering';
  try {
    fs.rmSync(job.dir, { recursive: true, force: true });
    fs.mkdirSync(job.dir, { recursive: true });
    const pcm = await decode(job.audioUrl, job.ss);
    if (job.cancelled) throw new Error('cancelled');
    const raw = path.join(job.dir, 'audio.raw');
    fs.writeFileSync(raw, pcm);
    job.seconds = pcm.length / 4 / SR;
    const enc = encoder(['-f', 'image2pipe', '-framerate', String(cfg.fps), '-c:v', 'mjpeg', '-i', '-',
      '-f', 's16le', '-ar', String(SR), '-ac', '2', '-i', raw, '-map', '0:v', '-map', '1:a',
      ...videoArgs(cfg.width, cfg.height), '-c:a', 'aac', '-b:a', '192k', '-shortest',
      '-f', 'hls', '-hls_time', '2', '-hls_list_size', '0', '-hls_playlist_type', 'event', '-hls_flags', 'independent_segments',
      '-hls_segment_filename', path.join(job.dir, 's%04d.ts'), path.join(job.dir, 'index.m3u8')]);
    const fps = await drawFrames(pcm, job.preset, cfg.width, cfg.height, enc, job);
    enc.stdin.end();
    const r = await enc.done;
    fs.rmSync(raw, { force: true });
    if (job.cancelled) throw new Error('cancelled');
    if (r.code !== 0) throw new Error('encoder: ' + r.err.slice(-300));
    job.state = 'done';
    log(`done ${job.id} (${job.seconds.toFixed(0)} s of song at ${fps.toFixed(0)} frames a second)`);
  } catch (e) {
    job.state = job.cancelled ? 'cancelled' : 'failed';
    job.error = String(e.message || e);
    if (!job.cancelled) log('failed', job.id, job.error);
  } finally {
    active = null;
    prune();
    next();
  }
}

function next() {
  if (active || !queue.length) return;
  runJob(queue.shift());
}

function prune() {
  const old = [...jobs.values()].filter(j => j !== active && !queue.includes(j)).sort((a, b) => b.used - a.used).slice(cfg.keep);
  for (const j of old) { jobs.delete(j.id); fs.rmSync(j.dir, { recursive: true, force: true }); }
}

// how many finished segments the playlist lists so far
function segments(job) {
  try { return (fs.readFileSync(path.join(job.dir, 'index.m3u8'), 'utf8').match(/\.ts/g) || []).length; } catch { return 0; }
}

// The TV gets the whole song's playlist up front, marked as a finished (VOD) stream, even while it is still
// being drawn. Segments are exactly 2 s (a keyframe every 2 s), so every one can be listed ahead; a segment
// that isn't drawn yet is held back until it is. A growing (EVENT) playlist makes the TV treat the song as
// live: it jumps in near the newest piece, skipping the start, and ends the song when drawing falls behind.
function vodPlaylist(job) {
  const total = Math.floor(job.seconds * cfg.fps) / cfg.fps;
  const n = Math.max(1, Math.ceil(total / 2 - 1e-6));
  const lines = ['#EXTM3U', '#EXT-X-VERSION:6', '#EXT-X-TARGETDURATION:2', '#EXT-X-MEDIA-SEQUENCE:0', '#EXT-X-PLAYLIST-TYPE:VOD', '#EXT-X-INDEPENDENT-SEGMENTS'];
  for (let i = 0; i < n; i++) {
    const d = i < n - 1 ? 2 : total - 2 * (n - 1);
    lines.push('#EXTINF:' + d.toFixed(6) + ',', 's' + String(i).padStart(4, '0') + '.ts');
  }
  lines.push('#EXT-X-ENDLIST', '');
  return lines.join('\n');
}

// wait until segment `name` is finished (ffmpeg lists it only once it is closed)
async function segmentReady(job, name, ms) {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    try { if (fs.readFileSync(path.join(job.dir, 'index.m3u8'), 'utf8').split('\n').includes(name)) return true; } catch {}
    if (job.state === 'failed' || job.state === 'cancelled') return false;
    if (job.state === 'done') return fs.existsSync(path.join(job.dir, name));
    await new Promise(r => setTimeout(r, 150));
  }
  return false;
}

function startJob(body) {
  const id = crypto.createHash('sha1').update([body.audioUrl.replace(/[?&]t=[^&]*/, ''), body.look, Math.round(body.ss || 0)].join('|')).digest('hex').slice(0, 16);
  let job = jobs.get(id);
  if (job && (job.state === 'failed' || job.state === 'cancelled')) { jobs.delete(id); job = null; }
  if (!job) {
    job = { id, audioUrl: body.audioUrl, look: body.look, preset: presetFor(body.look), ss: +body.ss || 0, dir: path.join(WORK, id), state: 'queued', frames: 0, prefetch: !!body.prefetch };
    jobs.set(id, job);
    queue.push(job);
  }
  job.used = Date.now();
  if (!body.prefetch) {
    // the song the TV wants now goes first; whatever else was rendering or waiting is dropped,
    // and a backup loop being made stops at once (it is made again later), so the song gets the whole machine
    if (loopJob) loopJob.cancelled = true;
    job.prefetch = false;
    if (active && active !== job) active.cancelled = true;
    for (let i = queue.length - 1; i >= 0; i--) if (queue[i] !== job) { queue[i].cancelled = true; queue[i].state = 'cancelled'; queue.splice(i, 1); }
    const at = queue.indexOf(job);
    if (at > 0) { queue.splice(at, 1); queue.unshift(job); }
  }
  next();
  return job;
}

async function waitReady(job, ms) {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    if (job.state === 'done' || segments(job) >= 3) return true;
    if (job.state === 'failed' || job.state === 'cancelled') return false;
    await new Promise(r => setTimeout(r, 200));
  }
  return false;
}

// ---------------------------------------------------------------- web
function json(res, code, obj) {
  const b = Buffer.from(JSON.stringify(obj));
  res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': b.length, 'Cache-Control': 'no-store' });
  res.end(b);
}

function readBody(req) {
  return new Promise((res, rej) => {
    let n = 0; const parts = [];
    req.on('data', d => { n += d.length; if (n > 65536) { rej(new Error('too big')); req.destroy(); } else parts.push(d); });
    req.on('end', () => res(Buffer.concat(parts).toString('utf8')));
    req.on('error', rej);
  });
}

const TYPES = { '.m3u8': 'application/vnd.apple.mpegurl', '.ts': 'video/mp2t' };

async function handle(req, res) {
  const u = new URL(req.url, 'http://x');
  if (u.pathname === '/status') {
    return json(res, 200, { ok: true, width: cfg.width, height: cfg.height, measuredFps: cfg.measuredFps || 0, active: active ? { id: active.id, frames: active.frames } : null, queued: queue.length });
  }
  if (u.pathname === '/render' && req.method === 'POST') {
    // only the helper (it knows the house key) may start renders
    if (!cfg.token || req.headers['x-hearth-token'] !== cfg.token) return json(res, 401, { error: 'no key' });
    let body;
    try { body = JSON.parse(await readBody(req)); } catch { return json(res, 400, { error: 'bad body' }); }
    if (!body.audioUrl || !/^https?:\/\//.test(body.audioUrl)) return json(res, 400, { error: 'no audio' });
    const job = startJob(body);
    if (body.prefetch) return json(res, 202, { ok: true, id: job.id, state: job.state });
    const ok = await waitReady(job, 25000);
    if (!ok) return json(res, 503, { error: job.error || 'not ready in time', state: job.state });
    return json(res, 200, { ok: true, id: job.id, path: `/s/${job.id}/index.m3u8`, look: job.look });
  }
  const m = u.pathname.match(/^\/s\/([0-9a-f]{16})\/(index\.m3u8|s\d{4}\.ts)$/);
  if (m && req.method === 'GET') {
    const job = jobs.get(m[1]);
    const file = path.join(WORK, m[1], m[2]);
    if (!job) return json(res, 404, { error: 'gone' });
    job.used = Date.now();
    let data;
    if (m[2] === 'index.m3u8' && job.seconds > 0) {
      data = Buffer.from(vodPlaylist(job));
    } else if (m[2] === 'index.m3u8') {
      if (!fs.existsSync(file)) return json(res, 404, { error: 'gone' });
      data = fs.readFileSync(file);
    } else {
      // a piece the TV asks for ahead of the drawing: hold the answer until it exists
      if (!(await segmentReady(job, m[2], 20000))) return json(res, 404, { error: 'not drawn' });
      data = fs.readFileSync(file);
    }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)], 'Content-Length': data.length, 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' });
    return res.end(data);
  }
  json(res, 404, { error: 'not found' });
}

async function hello() {
  try {
    const r = await fetch(cfg.helper + '/api/viz/hello', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Hearth-Token': cfg.token },
      body: JSON.stringify({ port: cfg.port, width: cfg.width, height: cfg.height, measuredFps: cfg.measuredFps || 0, looks: LOOKS.length, renderer: myVersion() }), signal: AbortSignal.timeout(5000) });
    if (!r.ok) { log('helper said', r.status, '(check the house key in config.json)'); return; }
    const a = await r.json().catch(() => ({}));
    if (a.renderer && a.renderer !== myVersion() && !active && !queue.length) await selfUpdate();
  } catch (e) { log('helper not reachable:', e.message); }
}

// ---------------------------------------------------------------- staying up to date
// The NAS helper carries the renderer's files from the same Hearth commit as itself. When they differ from
// these, the renderer takes the helper's copy and starts again, so updating the helper updates the NucBox too.
const OWN = ['viz.js', 'page.html', 'looks.json', 'package.json', 'package-lock.json'];
function myVersion() {
  const h = crypto.createHash('sha1');
  for (const f of OWN.slice().sort()) {
    h.update(f + '\0');
    try { h.update(fs.readFileSync(path.join(HERE, f))); } catch {}
    h.update('\0');
  }
  return h.digest('hex').slice(0, 12);
}

let updating = false;
async function selfUpdate() {
  if (updating) return;
  updating = true;
  try {
    const r = await fetch(cfg.helper + '/api/viz/renderer', { headers: { 'X-Hearth-Token': cfg.token }, signal: AbortSignal.timeout(30000) });
    if (!r.ok) throw new Error('helper said ' + r.status);
    const b = await r.json();
    if (!b.files || !b.files['viz.js']) throw new Error('no files');
    const oldPkg = fs.existsSync(path.join(HERE, 'package.json')) ? fs.readFileSync(path.join(HERE, 'package.json'), 'utf8') : '';
    for (const [name, data] of Object.entries(b.files)) {
      if (!OWN.includes(name)) continue;
      fs.writeFileSync(path.join(HERE, name), Buffer.from(data, 'base64'));
    }
    log('updated the renderer from the helper (' + b.version + ')');
    if (fs.readFileSync(path.join(HERE, 'package.json'), 'utf8') !== oldPkg) {
      log('installing its packages...');
      await new Promise(res => spawn(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['install', '--omit=dev', '--no-audit', '--no-fund'], { cwd: HERE, stdio: 'ignore', shell: true }).on('close', res));
    }
    // start the new copy and step aside; it waits a moment for this one to let go of the port
    let out;
    try { out = fs.openSync(path.join(HERE, 'serve.log'), 'a'); } catch { out = fs.openSync(path.join(HERE, 'serve-updated.log'), 'a'); }
    spawn(process.execPath, [path.join(HERE, 'viz.js'), 'serve'], { cwd: HERE, detached: true, stdio: ['ignore', out, out], env: Object.assign({}, process.env, { HEARTH_VIZ_RESTART: '1' }), windowsHide: true }).unref();
    try { if (browserP) (await browserP).close(); } catch {}
    process.exit(0);
  } catch (e) {
    log('could not update from the helper:', e.message);
  } finally {
    updating = false;
  }
}

async function serve() {
  const srv = http.createServer((req, res) => handle(req, res).catch(e => { log('error', e.message); try { json(res, 500, { error: 'renderer error' }); } catch {} }));
  // after an update the old copy may still hold the port for a moment
  let tries = 0;
  srv.on('error', e => {
    if (e.code === 'EADDRINUSE' && tries++ < 20) { setTimeout(() => srv.listen(cfg.port, '0.0.0.0'), 1000); return; }
    log('cannot listen:', e.message); process.exit(1);
  });
  srv.listen(cfg.port, '0.0.0.0', () => log(`Hearth visualizer on :${cfg.port}, ${cfg.width}x${cfg.height}, helper ${cfg.helper}, renderer ${myVersion()}`));
  browser().catch(e => log('browser did not start:', e.message));
  await hello();
  setInterval(hello, 60000);
  // looks added since the loops were made get theirs now, between songs
  setTimeout(() => loops(true).catch(e => log('loops:', e.message)), 30000);
}

// ---------------------------------------------------------------- bench and loops
function testTone(seconds) {
  // a plain beat: 96 bpm kick and a chord, enough to make the looks move
  const n = Math.floor(seconds * SR), buf = Buffer.alloc(n * 4);
  for (let i = 0; i < n; i++) {
    const t = i / SR, b = t % 0.625;
    const kick = Math.sin(2 * Math.PI * (50 + 90 * Math.exp(-b * 30)) * b) * Math.exp(-b * 7) * 0.8;
    const pad = (Math.sin(2 * Math.PI * 220 * t) + Math.sin(2 * Math.PI * 261.6 * t) + Math.sin(2 * Math.PI * 329.6 * t)) * 0.06;
    const v = Math.max(-1, Math.min(1, kick + pad)) * 32000;
    buf.writeInt16LE(v | 0, i * 4); buf.writeInt16LE(v | 0, i * 4 + 2);
  }
  return buf;
}

async function bench() {
  const sizes = [[1280, 720], [960, 540], [640, 360]];
  const pcm = testTone(8);
  let pick = sizes[sizes.length - 1], best = 0;
  for (const [w, h] of sizes) {
    const enc = encoder(['-f', 'image2pipe', '-framerate', String(cfg.fps), '-c:v', 'mjpeg', '-i', '-', ...videoArgs(w, h), '-f', 'null', '-']);
    const fps = await drawFrames(pcm, LOOKS[0].preset, w, h, enc, null);
    enc.stdin.end(); await enc.done;
    log(`${w}x${h}: ${fps.toFixed(0)} frames a second (needs ${cfg.fps} to keep up with the music)`);
    if (fps >= cfg.fps * 1.4) { pick = [w, h]; best = fps; break; }
    if (fps > best) { best = fps; pick = [w, h]; }
  }
  cfg.width = pick[0]; cfg.height = pick[1]; cfg.measuredFps = Math.round(best);
  saveCfg();
  console.log(`RESULT ${pick[0]}x${pick[1]} ${Math.round(best)}fps ${best >= cfg.fps * 1.1 ? 'OK' : 'SLOW'}`);
  (await browser()).close();
}

let loopJob = null;

// a 30 second loop per look, made seamless by fading the last 3 seconds into the first.
// In the service (keep = true) it makes only the missing ones, between songs, and leaves the browser open.
async function loops(keep) {
  let have = await fetch(cfg.helper + '/api/viz/loops', { headers: { 'X-Hearth-Token': cfg.token } }).then(r => r.ok ? r.json() : null).catch(() => null);
  if (keep && !have) return;
  if (!have) have = { looks: [] };
  if (keep && LOOKS.every(l => (have.looks || []).includes(l.n))) return;
  let pcm;
  try {
    const r = await fetch(cfg.helper + '/api/viz/sample', { headers: { 'X-Hearth-Token': cfg.token } });
    if (!r.ok) throw new Error('helper ' + r.status);
    const f = path.join(WORK, 'sample.audio');
    fs.writeFileSync(f, Buffer.from(await r.arrayBuffer()));
    pcm = await decode(f, 0);
    log(`using ${(pcm.length / 4 / SR).toFixed(0)} s of one of your songs to make the loops move`);
  } catch (e) {
    log('no song from the helper (' + e.message + '), using a plain beat');
    pcm = testTone(34);
  }
  // a stretch from the middle of the song (intros are often quiet), 33 seconds: 30 for the loop, 3 for the seam
  const need = 33 * SR * 4, from = pcm.length > need + 30 * SR * 4 ? 30 * SR * 4 : 0;
  pcm = pcm.subarray(from, Math.min(pcm.length, from + need));
  if (pcm.length < need) pcm = Buffer.concat([pcm, testTone(34).subarray(0, need - pcm.length)]);
  let made = 0;
  for (const look of LOOKS) {
    if ((have.looks || []).includes(look.n)) { if (!keep) log(`loop ${look.n} ${look.label}: already on the NAS`); continue; }
    // a song on the TV comes first
    while (keep && (active || queue.length)) await new Promise(r => setTimeout(r, 5000));
    const raw = path.join(WORK, `loop-${look.n}-raw.mp4`), out = path.join(WORK, `loop-${look.n}.mp4`);
    const enc = encoder(['-f', 'image2pipe', '-framerate', String(cfg.fps), '-c:v', 'mjpeg', '-i', '-', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '14', '-pix_fmt', 'yuv420p', raw]);
    loopJob = keep ? { cancelled: false } : null;
    await drawFrames(pcm, look.preset, cfg.width, cfg.height, enc, loopJob);
    enc.stdin.end();
    const r = await enc.done;
    if (loopJob && loopJob.cancelled) {
      // a song came in: drop this one and come back to it when the TV is quiet again
      loopJob = null;
      fs.rmSync(raw, { force: true });
      log(`loop ${look.n}: paused for a song, will finish later`);
      setTimeout(() => loops(true).catch(e => log('loops:', e.message)), 60000);
      return;
    }
    loopJob = null;
    if (r.code !== 0) { log('loop failed', look.n, r.err.slice(-200)); continue; }
    await run(['-y', '-i', raw, '-filter_complex',
      '[0:v]split=3[a][b][c];[a]trim=3:30,setpts=PTS-STARTPTS[main];[b]trim=30:33,setpts=PTS-STARTPTS[end];[c]trim=0:3,setpts=PTS-STARTPTS[start];' +
      '[end][start]xfade=transition=fade:duration=3:offset=0[seam];[main][seam]concat=n=2:v=1:a=0,scale=1280:720:flags=bicubic,format=yuv420p[v]',
      '-map', '[v]', '-c:v', 'libx264', '-preset', 'slow', '-profile:v', 'high', '-level', '4.0', '-r', String(cfg.fps), '-g', String(cfg.fps * 2), '-b:v', '2500k', '-maxrate', '3500k', '-bufsize', '6M', '-movflags', '+faststart', '-an', out]);
    const up = await fetch(cfg.helper + `/api/viz/loop?n=${look.n}`, { method: 'POST', headers: { 'X-Hearth-Token': cfg.token, 'Content-Type': 'video/mp4' }, body: fs.readFileSync(out) });
    log(`loop ${look.n} ${look.label}: ${up.ok ? 'uploaded' : 'upload FAILED (' + up.status + ')'}`);
    if (up.ok) made++;
    fs.rmSync(raw, { force: true }); fs.rmSync(out, { force: true });
  }
  console.log(`RESULT loops made ${made}`);
  if (!keep) (await browser()).close();
}

const cmd = process.argv[2] || 'serve';
({ serve, bench, loops })[cmd]().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
