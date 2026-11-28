/* Hearth for browsers: the TV app's look and rooms, for the projector.
   Plex and Overseerr are reached through the NAS helper at /px/<service>/... (it adds the saved keys),
   so nothing here holds a password or token. D-pad only: arrows move, Enter picks, Back/Esc goes back. */
(() => {
'use strict';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s == null ? '' : s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const PX = '/px/plex';
const stage = $('#stage');
let K = 1; // stage scale

/* ---------- stage fit, clock, fireflies ---------- */
// Fit to what is really visible: browsers in "desktop mode" can report a layout wider than the screen,
// so take the smallest of the sizes they report. +/- (or ?k=0.8) nudges the size and is remembered.
let adj = 1;
try { adj = parseFloat(new URLSearchParams(location.search).get('k')) || parseFloat(localStorage.getItem('hearth.k')) || 1; } catch (e) { /* ignore */ }
function fit() {
  const vv = window.visualViewport;
  const w = Math.min(innerWidth, document.documentElement.clientWidth || 1e9, vv ? vv.width : 1e9);
  const h = Math.min(innerHeight, document.documentElement.clientHeight || 1e9, vv ? vv.height : 1e9);
  K = Math.min(w / 1920, h / 1080) * adj;
  const ox = vv ? vv.offsetLeft : 0, oy = vv ? vv.offsetTop : 0;
  const tf = `translate(${ox + (w - 1920 * K) / 2}px,${oy + (h - 1080 * K) / 2}px) scale(${K})`;
  stage.style.transform = tf;
  document.querySelectorAll('.hudbox').forEach(e => { e.style.transform = tf; });
}
function nudge(f) { adj = Math.max(.3, Math.min(2, adj * f)); try { localStorage.setItem('hearth.k', adj); } catch (e) { /* ignore */ } fit(); }
addEventListener('resize', fit); if (window.visualViewport) { visualViewport.addEventListener('resize', fit); visualViewport.addEventListener('scroll', fit); }
fit(); setTimeout(fit, 300); setTimeout(fit, 1500);
function tick() {
  const d = new Date();
  $('#clk').textContent = d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  $('#dat').textContent = d.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
  const w = $('#clk').offsetWidth; $('#cfly').style.left = (1824 - w - 34) + 'px';
}
if (document.fonts) document.fonts.ready.then(() => tick());
tick(); setInterval(tick, 20000);
for (let i = 0; i < 9; i++) {
  const f = document.createElement('i'); f.className = 'ff';
  f.style.cssText = `left:${Math.random() * 1900}px;top:${200 + Math.random() * 800}px;--d:${6 + Math.random() * 8}s;--dx:${(Math.random() - .5) * 160}px;--dy:${-30 - Math.random() * 120}px;animation-delay:${-Math.random() * 8}s`;
  $('#flies').appendChild(f);
}
let toastT;
function toast(t) { const e = $('#toast'); e.textContent = t; e.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => e.classList.remove('show'), 2200); }

/* ---------- Plex ---------- */
async function pj(path, params) {
  const u = new URL(PX + path, location.origin);
  for (const k in (params || {})) u.searchParams.set(k, params[k]);
  const r = await fetch(u, { headers: { Accept: 'application/json' } });
  if (!r.ok) throw new Error('Plex said ' + r.status);
  const j = await r.json();
  return j.MediaContainer || {};
}
const img = (p, w, h) => p ? `${PX}/photo/:/transcode?width=${w}&height=${h}&minSize=1&upscale=1&url=${encodeURIComponent(p)}` : '';
const HIDE_WORDS = ['pimsleur'];
let LIBS = null, blocked = new Set(), musicLib = null, ambLib = null, photoLib = null;
async function libs() {
  if (LIBS) return LIBS;
  const mc = await pj('/library/sections');
  LIBS = mc.Directory || [];
  for (const d of LIBS) {
    const t = (d.title || '').toLowerCase();
    const loc = (d.Location || []).map(l => (l.path || '').toLowerCase().replace(/\/$/, ''));
    const amb = t.includes('ambiance') || t.includes('ambience') || loc.some(p => /\/(hearth|ambiance|ambience)$/.test(p));
    const hid = t.includes('exercise') || t.includes('audiobook') || t.includes('audio book');
    if (amb) { ambLib = d; blocked.add(String(d.key)); }
    else if (hid) blocked.add(String(d.key));
    else if (d.type === 'artist' && !musicLib) musicLib = d;
    else if (d.type === 'photo' && !photoLib) photoLib = d;
  }
  return LIBS;
}
const hiddenItem = md => {
  const t = ((md.title || '') + ' ' + (md.parentTitle || '') + ' ' + (md.grandparentTitle || '')).toLowerCase();
  return HIDE_WORDS.some(w => t.includes(w)) || blocked.has(String(md.librarySectionID));
};
function cardOf(md) {
  let title = md.title, sub = md.year || '', pic = md.art || md.thumb, prog = 0;
  if (md.type === 'episode') {
    title = md.grandparentTitle || md.title;
    sub = `S${md.parentIndex} E${md.index} · ${md.title}`;
    pic = md.thumb || md.grandparentArt || md.art;
  } else if (md.type === 'season') { title = md.parentTitle; sub = md.title; pic = md.parentArt || md.art || md.thumb; }
  else if (md.type === 'show') { sub = md.year || ''; pic = md.art || md.thumb; }
  if (md.viewOffset && md.duration) prog = Math.min(100, md.viewOffset / md.duration * 100);
  return { title, sub, pic, prog };
}
function cardHTML(md) {
  const c = cardOf(md);
  return `<div class="fx card" data-a="play" data-k="${md.ratingKey}" data-t="${md.type}"><div class="img" data-bg="${img(c.pic, 320, 180)}"><div class="ph">${esc(c.title)}</div>${c.prog ? `<div class="braid"><i style="width:${c.prog}%"></i></div>` : ''}</div><div class="t">${esc(c.title)}</div><div class="s">${esc(c.sub)}</div></div>`;
}
function albumHTML(md) {
  const t = md.type === 'artist' ? 'Artist' : md.type === 'playlist' ? `${md.leafCount || ''} songs` : (md.parentTitle || '');
  const pic = md.thumb || md.composite;
  return `<div class="fx alb" data-a="album" data-k="${md.ratingKey}" data-t="${md.type}"><div class="im" data-bg="${img(pic, 240, 240)}"></div><div class="t">${esc(md.title)}</div><div class="s">${esc(t)}</div></div>`;
}
const hd = (t, small) => `<div class="hd">${esc(t)}${small ? `<small>${esc(small)}</small>` : ''}</div>`;

/* ---------- pictures load as they come into view ---------- */
// Plex resizes every picture on demand, so asking for a whole page at once is slow. Load what is on screen (and a bit beyond).
const io = window.IntersectionObserver ? new IntersectionObserver(es => {
  for (const e of es) {
    if (!e.isIntersecting) continue;
    const u = e.target.dataset.bg;
    if (u) { e.target.style.backgroundImage = `url("${u}")`; delete e.target.dataset.bg; }
    io.unobserve(e.target);
  }
}, { rootMargin: '500px' }) : null;
new MutationObserver(() => {
  if ($('.rc[data-sk]:not([data-sd])')) rqScoresSoon();
  $$('[data-bg]').forEach(el => {
    if (el._o) return; el._o = 1;
    if (io) io.observe(el); else { el.style.backgroundImage = `url("${el.dataset.bg}")`; }
  });
}).observe(stage, { childList: true, subtree: true });

/* ---------- IMDb and Rotten Tomatoes on Requests posters (build 139: the helper's ratings.py, mini badge) ---------- */
const RSC = {}; let rscT = 0;
function rqScoresSoon() { clearTimeout(rscT); rscT = setTimeout(rqScores, 250); }
async function rqScores() {
  const cards = $$('.rc[data-sk]:not([data-sd])'); if (!cards.length) return;
  const want = [...new Set(cards.map(c => c.dataset.sk).filter(k => !(k in RSC)))].slice(0, 200);
  if (want.length) {
    try {
      const r = await fetch('/api/ratings', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ids: want }) });
      const j = await r.json(); const got = j.ratings || {}, pend = j.pending || [];
      for (const k of want) if (got[k] || !pend.includes(k)) RSC[k] = got[k] || null;
      if (pend.length) setTimeout(rqScoresSoon, 4000);
    } catch (e) { return; }
  }
  for (const c of $$('.rc[data-sk]:not([data-sd])')) {
    const k = c.dataset.sk; if (!(k in RSC)) continue;
    c.dataset.sd = '1'; const v = RSC[k]; if (!v || (v.rt == null && v.imdb == null)) continue;
    c.insertAdjacentHTML('beforeend', `<div class="rsc2">${v.rt != null ? `<img src="img/icons/${v.cert ? 'tomato-cert' : 'tomato'}.png" alt=""><b>${v.rt}%</b>` : ''}${v.imdb != null ? `<img src="img/icons/imdb.png" alt="" class="imdb"><b>${v.imdb}</b>` : ''}</div>`);
  }
}

/* ---------- focus and navigation ---------- */
let focusEl = null;
const layers = [];
function cands() { return layers.length ? $$('.fx', layers[layers.length - 1].el) : $$('#bar .fx, #room .fx'); }
function rectOf(e) { const r = e.getBoundingClientRect(); return { l: r.left, r: r.right, t: r.top, b: r.bottom, cx: (r.left + r.right) / 2, cy: (r.top + r.bottom) / 2 }; }
function reveal(el) {
  const sc = el.closest('.scroll,.tl');
  if (sc) {
    const cr = sc.getBoundingClientRect(), er = el.getBoundingClientRect();
    const top = (er.top - cr.top) / K, bot = (er.bottom - cr.top) / K, H = cr.height / K;
    if (top < 50) sc.scrollTop += top - 50; else if (bot > H - 70) sc.scrollTop += bot - (H - 70);
  }
  const row = el.closest('.row');
  if (row) {
    const cr = row.getBoundingClientRect(), er = el.getBoundingClientRect();
    const l = (er.left - cr.left) / K, r = (er.right - cr.left) / K, W = cr.width / K;
    if (l < 40) row.scrollLeft += l - 40; else if (r > W - 40) row.scrollLeft += r - (W - 40);
  }
}
const FH = {};
function setFocus(el) {
  if (focusEl) focusEl.classList.remove('on');
  focusEl = el;
  if (el && FH.any) FH.any(el);
  { const tl = layers[layers.length - 1]; if (tl && tl.onFocus) tl.onFocus(el); }
  mossOn(el); barFlies();
  if (el) { el.classList.add('on'); reveal(el); if (el.classList.contains('pc2') && el.dataset.i !== undefined && !el.closest('.layer') && typeof LRInfo === 'function') LRInfo(+el.dataset.i); if (el.classList.contains('rc') && typeof RQInfo === 'function') RQInfo(+el.dataset.i); if (el.dataset.a === 'rail' && RQ && cur === 'Requests' && RQ.idx !== +el.dataset.i) { RQ.idx = +el.dataset.i; RQ.over = null; RQ.show(); } }
}
function firstFocus(root) { const e = $('.fx', root); setFocus(e || null); }
function move(dir) {
  const list = cands();
  if (!focusEl || !list.includes(focusEl)) { setFocus(list[0] || null); return; }
  const c = rectOf(focusEl);
  let best = null, bs = 1e12;
  for (const e of list) {
    if (e === focusEl) continue;
    const r = rectOf(e);
    let main, cross;
    if (dir === 'ArrowRight') { main = r.cx - c.cx; cross = Math.abs(r.cy - c.cy); if (r.l < c.r - c.cx + c.cx - (c.r - c.l) * .7 && main < 4) continue; }
    else if (dir === 'ArrowLeft') { main = c.cx - r.cx; cross = Math.abs(r.cy - c.cy); }
    else if (dir === 'ArrowDown') { main = r.cy - c.cy; cross = Math.abs(r.cx - c.cx); }
    else { main = c.cy - r.cy; cross = Math.abs(r.cx - c.cx); }
    if (main < 8) continue;
    const s = main + cross * 2.6;
    if (s < bs) { bs = s; best = e; }
  }
  if (best) setFocus(best);
}

/* ---------- layers (sheets, player, moods) and history ---------- */
function openLayer(cls, html, handlers) {
  const el = document.createElement('div');
  el.className = 'layer ' + cls;
  // The video player and the full-screen music views sit outside the scaled stage: a video inside a scaled, animated page
  // makes weak chips drop frames. A popup opened over one of them goes there too, in its own scaled box.
  const top = layers[layers.length - 1];
  const inV = /\b(player|mview)\b/.test(cls) || (/\bdlg\b|\bqsheet\b/.test(cls) && top && top.el.parentNode === $('#vlayers'));
  el.innerHTML = inV && !/\b(player|mview)\b/.test(cls) ? `<div class="hudbox" style="pointer-events:auto">${html}</div>` : html;
  (inV ? $('#vlayers') : $('#layers')).appendChild(el);
  const L = Object.assign({ el, prev: focusEl }, handlers || {});
  layers.push(L);
  history.pushState({ n: layers.length }, '');
  syncCover(); fit();
  firstFocus(el);
  return L;
}
// While a full-screen layer is open, the pages underneath stop drawing (and the fireflies stop moving)
function syncCover() { stage.classList.toggle('cover', layers.some(l => /player|mood|slide|mview/.test(l.el.className))); paintChip(); }
function closeLayer() { if (layers.length) history.back(); }
addEventListener('popstate', () => {
  const L = layers.pop();
  if (!L) return;
  try { L.close && L.close(); } catch (e) { /* fine */ }
  L.el.remove(); syncCover();
  { const t = layers[layers.length - 1]; if (t && t.onShown) t.onShown(); }
  if (L.prev && document.contains(L.prev)) setFocus(L.prev); else firstFocus(layers.length ? layers[layers.length - 1].el : $('#room'));
  if (L.after) { try { L.after(); } catch (e) { toast(e.message); } }
});
// close the top layer, then do something once it is really gone (history.back() finishes later)
function closeThen(fn) { const L = layers[layers.length - 1]; if (!L) { fn(); return; } L.after = fn; history.back(); }
history.replaceState({ n: 0 }, '');

/* ---------- keys ---------- */
addEventListener('keydown', e => {
  const top = layers[layers.length - 1];
  if (top && top.onKey && top.onKey(e) === true) { e.preventDefault(); return; }
  const k = e.key;
  if (cur === 'Search' && !layers.length && SR && SR.key(e)) { e.preventDefault(); return; }
  if (cur === 'Requests' && !layers.length && RQ && RQ.cur().key === 'search' && !RQ.over) { if (/^[a-z0-9]$/i.test(k) && !e.ctrlKey && !e.metaKey) { RQ.type(RQ.text + k.toLowerCase()); e.preventDefault(); return; } if (k === 'Backspace' && RQ.text) { RQ.type(RQ.text.slice(0, -1)); e.preventDefault(); return; } }
  if (k.startsWith('Arrow')) { e.preventDefault(); move(k); }
  else if (k === 'Enter' || k === ' ') { if (focusEl) { e.preventDefault(); act(focusEl); } }
  else if (k === 'Escape' || k === 'Backspace' || k === 'BrowserBack' || k === 'GoBack') { e.preventDefault(); back(); }
  else if (k === '-' || k === 'PageDown') { nudge(.92); toast('Smaller'); }
  else if (k === '=' || k === '+' || k === 'PageUp') { nudge(1.08); toast('Bigger'); }
  else if (k === 'MediaPlayPause') { M.toggle(); }
  else if (k === 'MediaTrackNext') { M.next(); }
  else if (k === 'MediaTrackPrevious') { M.prev(); }
});
function back() {
  { const t = layers[layers.length - 1]; if (t && t.onBack && t.onBack()) return; }
  if (layers.length) { closeLayer(); return; }
  if (cur === 'Requests' && RQLeave && RQLeave()) return;
  if ((cur === 'Movies' || cur === 'Shows') && LRBack && LRBack()) return;
  if (cur !== 'Home') go('Home');
}
document.addEventListener('click', e => { const el = e.target.closest('[data-a]'); if (el) { setFocus(el); act(el); } });
document.addEventListener('mouseover', e => { const el = e.target.closest('.fx'); if (el && el !== focusEl && (!layers.length || layers[layers.length - 1].el.contains(el))) setFocus(el); });

/* ---------- mouse pointer ---------- */
// The projector's own remote moves a pointer instead of pressing arrows, so everything also works by pointing:
// click opens, the wheel scrolls, resting the pointer at a row's ends or the page's top and bottom scrolls too.
let mx = -1, my = -1;
document.addEventListener('mousemove', e => { mx = e.clientX; my = e.clientY; const L = layers[layers.length - 1]; if (L && L.onMouse) L.onMouse(); });
document.addEventListener('wheel', e => {
  e.preventDefault();
  const row = e.target.closest && e.target.closest('.row');
  if (row && (Math.abs(e.deltaX) > Math.abs(e.deltaY) || e.shiftKey)) { row.scrollLeft += e.deltaX || e.deltaY; return; }
  const top = layers[layers.length - 1];
  const sc = (e.target.closest && e.target.closest('.scroll,.tl')) || $('.scroll', top ? top.el : $('#room'));
  if (sc) sc.scrollTop += e.deltaY;
}, { passive: false });
setInterval(() => {
  if (mx < 0 || layers.length && layers[layers.length - 1].el.classList.contains('player')) return;
  const el = document.elementFromPoint(mx, my); if (!el || !el.closest) return;
  const row = el.closest('.row');
  if (row) { const r = row.getBoundingClientRect(); if (mx - r.left < 90 * K) row.scrollLeft -= 24; else if (r.right - mx < 90 * K) row.scrollLeft += 24; }
  const sc = el.closest('.scroll,.tl');
  if (sc) { const r = sc.getBoundingClientRect(); if (my - r.top < 50 * K) sc.scrollTop -= 22; else if (r.bottom - my < 60 * K) sc.scrollTop += 22; }
}, 40);

/* ---------- the phone remote drives this page too ---------- */
// The NAS helper keeps a small queue; this page asks it for new button presses and plays them as key presses.
const REMOTE_KEYS = { Up: 'ArrowUp', Down: 'ArrowDown', Left: 'ArrowLeft', Right: 'ArrowRight', Select: 'Enter', Enter: 'Enter', Back: 'Escape', Play: ' ', Rev: 'MediaRewind', Fwd: 'MediaFastForward', InstantReplay: 'MediaRewind', Backspace: 'Backspace' };
function remoteKey(k) {
  if (k === 'Home') { while (layers.length) { const L = layers.pop(); try { L.close && L.close(); } catch (e) { /* ignore */ } L.el.remove(); } history.go(-(history.state && history.state.n || 0)); go('Home'); return; }
  if (k === 'Info') { const L = layers[layers.length - 1]; if (L && L.toggleStats) L.toggleStats(); return; }
  if (k === 'VolumeUp' || k === 'VolumeDown' || k === 'VolumeMute') {
    const media = [aud, ...$$('video'), ...layers.map(l => l.sfx).filter(Boolean)];
    for (const m of media) { if (k === 'VolumeMute') m.muted = !m.muted; else m.volume = Math.max(0, Math.min(1, m.volume + (k === 'VolumeUp' ? .1 : -.1))); }
    toast(k === 'VolumeMute' ? 'Mute toggled' : 'Volume ' + Math.round(aud.volume * 100) + '%'); return;
  }
  const key = REMOTE_KEYS[k]; if (!key) return;
  window.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }));
}
(async function remoteLoop() {
  let seq = -1;
  for (;;) {
    try {
      const r = await fetch('/api/pj/poll?since=' + seq, { cache: 'no-store' });
      const j = await r.json();
      if (typeof j.seq !== 'number') { await new Promise(r => setTimeout(r, 5000)); continue; }
      if (seq < 0) { seq = j.seq; continue; }
      seq = j.seq;
      for (const c of j.cmds) { if (c.key) remoteKey(c.key); else if (c.text !== undefined) searchTyped(c.text, c.go); }
    } catch (e) { await new Promise(r => setTimeout(r, 3000)); }
  }
})();

/* ---------- rooms ---------- */
const ROOMS = ['Home', 'Shows', 'Movies', 'Music', 'Requests', 'Ambiance', 'Photos', 'Search', 'Test'];
const LIVE = new Set(['Home', 'Shows', 'Movies', 'Music', 'Requests', 'Ambiance', 'Photos', 'Search', 'Test']);
let cur = 'Home', renderTok = 0, autoF = null;
const RBX = { Home: [100, 101], Shows: [240, 121], Movies: [398, 133], Music: [570, 111], Requests: [719, 174], Ambiance: [931, 182], Photos: [1152, 134], Search: [1324, 60] };
function drawBar() {
  $('#rooms').innerHTML = ROOMS.map(r => `<div class="fx rm ${RBX[r] ? '' : 'tst'} ${r === cur ? 'cur' : ''}" data-a="room" data-r="${r}">${RBX[r] ? '' : r}</div>`).join('')
    + '<img class="bf" id="bglow" src="img/w/firefly-glow.png" alt=""><img class="bf" id="bf1" src="img/w/firefly-small.png" width="48" height="48" alt=""><img class="bf" id="bf2" src="img/w/firefly-small.png" width="48" height="48" style="opacity:.45" alt=""><img class="bf" id="bfly" src="img/w/firefly-main.png" width="64" height="64" alt="">';
  barFlies();
}
// the firefly marks of the Roku room bar: glow and a friend on the current room, the main one under the focused room
function barFlies() {
  const g = $('#bglow'); if (!g) return;
  const ci = RBX[cur] ? cur : null; if (!ci) { g.style.display = $('#bf1').style.display = $('#bf2').style.display = $('#bfly').style.display = 'none'; return; }
  const fo = focusEl && focusEl.classList && focusEl.classList.contains('rm') && RBX[focusEl.dataset.r] ? focusEl.dataset.r : ci;
  const [x, w] = RBX[ci], l = x + 2, r = x + w - 2;
  Object.assign(g.style, { display: '', left: (l - 24) + 'px', width: (r - l + 48) + 'px', opacity: fo !== ci ? .6 : 1 });
  Object.assign($('#bf1').style, { display: '', left: (r - 10) + 'px', top: '19px' });
  Object.assign($('#bf2').style, { display: '', left: (l - 36) + 'px', top: '55px' });
  Object.assign($('#bfly').style, { display: '', left: (RBX[fo][0] + Math.floor(RBX[fo][1] / 2) - 32) + 'px', top: '64px' });
}
// moss hugs the focused card (whimsy spec 4), the same kind every time for the same card
const MOSSK = ['1-round-caps', '2-tall-caps', '3-golden-funnels', '4-two-acorns'];
function mossOn(el) {
  $$('.moss').forEach(m => m.remove());
  if (!el || !el.matches('.card,.pc2,.rc,.ptile,.cc,.rsrow .rsp')) return;
  const key = el.dataset.k || el.dataset.i || el.textContent.slice(0, 20) || 'x';
  let h = 0; for (const ch of String(key)) h = (h * 31 + ch.charCodeAt(0)) % 1000003;
  const left = h % 3 === 0;
  const box = el.querySelector('.img,.im,.rim,.pti') || el;
  const bw = box.offsetWidth || 180;
  let mw = Math.max(80, Math.min(125, Math.floor((bw + 14) * .6)));
  const sc = mw / 125;
  const im = document.createElement('img'); im.className = 'moss';
  im.src = `img/w/moss-corner-${MOSSK[h % 4]}${left ? '-left' : ''}.png`;
  im.style.width = mw + 'px'; im.style.height = Math.floor(96 * sc) + 'px';
  im.style.top = Math.floor(-7 - 55 * sc) + 'px';
  im.style.left = (left ? Math.floor(-7 - 15 * sc) : Math.floor(bw + 7 - 110 * sc)) + 'px';
  el.appendChild(im);
}
async function go(name, keepFocus) {
  if (PH) PH.stop();
  cur = name; drawBar(); paintChip();
  const tok = ++renderTok;
  const room = $('#room'); room.innerHTML = '';
  let ok = true;
  try {
    if (name === 'Home') await roomHome(room, tok);
    else if (name === 'Music') await roomMusic(room, tok);
    else if (name === 'Movies') await roomLib(room, tok, 'movie');
    else if (name === 'Search') roomSearch(room, tok);
    else if (name === 'Requests') roomRequests(room, tok);
    else if (name === 'Photos') await roomPhotos(room, tok);
    else if (name === 'Shows') await roomLib(room, tok, 'show');
    else if (name === 'Ambiance') await roomAmbiance(room, tok);
    else if (name === 'Test') await roomTest(room, tok);
    else soon(room, name);
  } catch (e) { if (tok === renderTok) { room.innerHTML = `<div class="msg">Can't reach your library right now.<br>${esc(e.message)}</div>`; } }
  if (tok !== renderTok) return;
  if (!keepFocus) { const f = $('#room .fx[data-first]') || $('#room .fx') || $$('#bar .fx').find(x => x.dataset.r === name); setFocus(f); autoF = f; }
  else setFocus($$('#bar .fx').find(x => x.dataset.r === name));
}
function soon(room, name) {
  room.innerHTML = `<div class="soon"><img src="img/lantern.png" alt=""><h2>${esc(name)} is coming to the projector</h2><p>Home, Movies, Shows, Music, Ambiance and the video test are ready. Requests, Photos and Search are next.</p></div>`;
}

/* ---------- Home ---------- */
const MOODS = [['hearth', 'Hearth'], ['rain', 'Rain'], ['fireflies', 'Fireflies'], ['lightsout', 'Lights out']];
const TN = { eps: [], movies: [], lists: [], bump: 0 };
const tnLen = min => min >= 60 ? (min % 60 ? Math.floor(min / 60) + ' h ' + (min % 60) : Math.floor(min / 60) + ' h') : min + ' min';
// A short episode, a film and a playlist for the time of day; the date and time bucket seed the choice (same as the Roku)
function pickTonight() {
  if (cur !== 'Home' || !$('#rows')) return;
  const t = new Date(), h = t.getHours(), dow = t.getDay();
  const late = h >= 22 || h < 5; const bucket = late ? 3 : h >= 17 ? 2 : h >= 11 ? 1 : 0;
  const note = ['Morning', 'Afternoon', 'Evening', 'Late evening'][bucket];
  const epMax = late ? 25 : bucket === 2 ? 35 : 45, movieMax = late || (bucket === 2 && dow >= 1 && dow <= 5) ? 100 : 180;
  const seed = t.getFullYear() * 372 + (t.getMonth() + 1) * 31 + t.getDate() + bucket * 7 + TN.bump;
  const mins = x => Math.round((x.duration || 0) / 60000);
  const out = [];
  let c = TN.eps.filter(x => mins(x) > 0 && mins(x) <= epMax);
  if (!c.length && TN.eps.length) c = [TN.eps.slice().sort((a, b) => mins(a) - mins(b))[0]];
  if (c.length) { const it = c[seed % c.length], cd = cardOf(it); out.push({ a: `data-a="play" data-k="${it.ratingKey}" data-t="${it.type}"`, ic: 'episode', kick: 'A QUICK ONE · ' + tnLen(mins(it)).toUpperCase(), title: cd.title, pic: img(cd.pic, 296, 90) }); }
  c = TN.movies.filter(x => mins(x) > 0 && mins(x) <= movieMax);
  if (c.length) { const it = c[(seed * 3 + 1) % c.length]; out.push({ a: `data-a="play" data-k="${it.ratingKey}" data-t="movie"`, ic: 'film', kick: 'A FILM · ' + tnLen(mins(it)).toUpperCase(), title: it.title, pic: img(it.art || it.thumb, 296, 90) }); }
  let ls = TN.lists; const calm = ls.filter(x => /calm|quiet|soft|sleep|wind|chill|night|evening|ambient|relax|mellow|lull/i.test(x.title));
  if (bucket >= 2 && calm.length) ls = calm;
  if (ls.length) { const it = ls[(seed * 5 + 2) % ls.length], m2 = mins(it); out.push({ a: `data-a="album" data-k="${it.ratingKey}" data-t="playlist"`, ic: 'home-note', kick: 'A PLAYLIST' + (m2 ? ' · ' + tnLen(m2).toUpperCase() : ''), title: it.title, pic: img(it.composite || it.thumb, 300, 300) }); }
  const old = $('#tonight'); const had = old && old.contains(focusEl); if (old) old.remove();
  if (!out.length) return;
  const sec = document.createElement('div'); sec.id = 'tonight';
  sec.innerHTML = `<div class="tnh"><i class="ic" style="--m:url(img/icons/icon-moon.png)"></i>Tonight<small>${esc(note)}</small></div><div class="row">${out.map(o => `<div class="fx card tn" ${o.a}><div class="img" data-bg="${o.pic}"></div><div class="tk"><i class="ic" style="--m:url(img/icons/${o.ic}.png)"></i>${esc(o.kick)}</div><div class="t">${esc(o.title)}</div></div>`).join('')}</div>`;
  const box = $('#tnp'); if (!box) return; box.appendChild(sec); box.classList.add('on');
  if (had) setFocus($('.fx', sec));
}
async function roomHome(room, tok) {
  TN.eps = []; TN.movies = []; TN.lists = [];
  await libs();
  const mood = MOODS.map(([m, n]) => `<div class="fx mtile" data-a="mood" data-m="${m}" style="background-image:url(img/tile-${m}.jpg)"><b>${n}</b></div>`).join('');
  room.innerHTML = `<div class="scroll">
    <div class="htop"><div class="hero" id="hero"><div class="kick" style="left:40px;top:24px;position:absolute">Loading</div></div><div class="tnp" id="tnp"></div></div>
    <div class="tri">
      <div class="panel mcard" id="mc">${musicCardInner()}</div>
      <div class="panel rcard" id="rc"><div class="fx" data-a="room" data-r="Requests" style="position:absolute;inset:0;border-radius:18px"></div><div class="eb">Requests</div><div class="big" id="rn">·</div><div class="ms" id="rt" style="margin-top:6px"></div></div>
      <div class="panel rcard"><div class="eb">Set the mood</div><div class="moods">${mood}</div></div>
    </div>
    <div id="rows"></div></div>`;
  M.paint();
  // Continue hero + rows load independently so a slow one doesn't hold up the rest
  pj('/library/onDeck', { 'X-Plex-Container-Size': 40 }).then(mc => {
    if (tok !== renderTok) return;
    const items = (mc.Metadata || []).filter(m => !hiddenItem(m));
    const resume = items.find(m => m.viewOffset > 0);
    fillHero(resume);
    const nextUp = items.filter(m => m.type === 'episode' && !m.viewOffset);
    TN.eps = nextUp; pickTonight();
    addRow('Next up', 'to watch', nextUp.map(cardHTML), 0);
  }).catch(() => { if (tok === renderTok) $('#hero').innerHTML = `<div class="kick" style="position:absolute;left:40px;top:24px;color:var(--ember)">Can't reach your library</div><h1 style="position:absolute;left:40px;top:60px;margin:0;font:700 60px HearthSans">NAS OFFLINE?</h1>`; });
  pj('/library/recentlyAdded', { 'X-Plex-Container-Size': 60 }).then(mc => {
    if (tok !== renderTok) return;
    const seen = new Set(); const out = [];
    for (const m of (mc.Metadata || [])) {
      if (hiddenItem(m) || !['movie', 'episode', 'season', 'show'].includes(m.type)) continue;
      const key = m.type === 'movie' ? m.ratingKey : (m.grandparentTitle || m.parentTitle || m.title);
      if (seen.has(key)) continue; seen.add(key); out.push(m);
    }
    TN.movies = (mc.Metadata || []).filter(m => m.type === 'movie' && !hiddenItem(m) && !m.viewCount); pickTonight();
    addRow('Recently added', 'new', out.slice(0, 20).map(cardHTML), 1);
  }).catch(() => {});
  if (musicLib) pj(`/library/sections/${musicLib.key}/albums`, { sort: 'addedAt:desc', 'X-Plex-Container-Size': 20 }).then(mc => {
    if (tok !== renderTok) return;
    addRow('Music · new albums', 'albums', (mc.Metadata || []).map(albumHTML), 2);
  }).catch(() => {});
  pj('/playlists', { playlistType: 'audio' }).then(mc => { TN.lists = (mc.Metadata || []).filter(x => x.leafCount > 0); pickTonight(); }).catch(() => {});
  fetch('/px/overseerr/api/v1/request/count').then(r => r.json()).then(c => {
    if (tok !== renderTok) return;
    $('#rn').textContent = (c.pending || 0) + (c.processing || 0);
    $('#rt').textContent = `on the way · ${c.available || 0} ready`;
  }).catch(() => { if ($('#rt')) $('#rt').textContent = 'Overseerr not answering'; });
}
function addRow(title, small, cards, order) {
  const rows = $('#rows'); if (!rows || !cards.length) return;
  const sec = document.createElement('div'); sec.dataset.o = order;
  sec.innerHTML = hd(title, `${cards.length} ${small}`) + `<div class="row">${cards.join('')}</div>`;
  const after = [...rows.children].find(c => +c.dataset.o > order);
  rows.insertBefore(sec, after || null);
}
function fillHero(md) {
  const h = $('#hero'); if (!h) return;
  if (!md) { h.innerHTML = `<div class="art" style="background-image:url(img/bg.jpg)"></div><div class="fade"></div><div class="kick">Nothing to continue</div><h1>Pick something warm</h1><div class="btns"><div class="fx btn gold" data-a="room" data-r="Ambiance">Set the mood</div></div>`; return; }
  const c = cardOf(md);
  const eb = md.type === 'episode' ? `Continue · S${md.parentIndex} E${md.index}` : 'Continue';
  const left = md.duration ? Math.max(1, Math.round((md.duration - (md.viewOffset || 0)) / 60000)) + ' min left' : '';
  h.innerHTML = `<div class="art" style="background-image:url('${img(md.art || md.grandparentArt || md.thumb, 1728, 250)}')"></div><div class="fade"></div>
    <div class="kick">${esc(eb)}</div><h1>${esc(c.title)}</h1>
    <div class="pg"><i style="width:${c.prog}%"></i></div><div class="left">${left}</div>
    <div class="btns"><div class="fx btn gold" data-a="play" data-k="${md.ratingKey}" data-t="${md.type}">Resume</div><div class="fx btn" data-a="play" data-k="${md.ratingKey}" data-t="${md.type}" data-from="0">From the start</div></div>`;
  if (cur === 'Home' && !layers.length && (!focusEl || !document.contains(focusEl) || focusEl === autoF)) setFocus($('.btn', h));
}
function musicCardInner() {
  const t = M.cur();
  return `<div class="al" id="mc-art" style="background-image:url('${t ? img(t.thumb, 360, 360) : ''}')"></div>
  <div class="fx" data-a="room" data-r="Music" style="position:absolute;left:0;top:0;width:220px;height:100%;border-radius:18px"></div>
  <div class="tx"><div class="eb" id="mc-eb">${t ? (M.playing ? 'Now playing' : 'Paused') : 'Music'}</div>
  <div class="mt" id="mc-t">${esc(t ? t.title : 'Shuffle my music')}</div><div class="ms" id="mc-s">${esc(t ? t.artist : 'OK to start a random mix')}</div></div>
  <div class="ctl"><div class="fx ico" data-a="mprev">⏮</div><div class="fx ico" data-a="mtoggle" id="mc-pp">${M.playing ? '❚❚' : '▶'}</div><div class="fx ico" data-a="mnext">⏭</div></div>
  <div class="mbar"><i id="mc-bar"></i></div>`;
}

/* ---------- the rich popup (the Roku's HearthDialog: hand-cut card, twig, firefly, rows with icons) ---------- */
// o = { title, icon, now: {art, kick, title, sub, chips}, hero: {art, kick, title, sub, shape}, message, q (a question: centred, buttons in a row),
//       rows: [{ head, label, sub, icon, value ('On' / 'Off' draws a switch), arrow, tick, kind: '' | 'tile' | 'main' | 'pic', pic, hrt, cur }],
//       split (first row of the right column), wide, pick(i, row, L, el) }
// pick returns 'keep' to leave the popup open (after changing row.value etc.: the row is redrawn), otherwise the popup closes first.
const MI = n => `img/music/${n}.png`;
function dlgRow(r, i) {
  const ico = r.icon ? `<i class="ic" style="--m:url(${r.icon})"></i>` : '';
  if (r.kind === 'tile' || r.kind === 'main') return `<div class="fx dtile ${r.kind === 'main' ? 'main' : ''}" data-a="dlg" data-i="${i}">${ico}<b>${esc(r.label)}</b>${r.sub ? `<s>${esc(r.sub)}</s>` : ''}</div>`;
  if (r.kind === 'pic') return `<div class="fx dpic ${r.cur ? 'cur' : ''}" data-a="dlg" data-i="${i}" style="background-image:url('${esc(r.pic || '')}')">${r.hrt ? `<i class="ic hrt" style="--m:url(${MI('heart')})"></i>` : ''}<b>${esc(r.label)}</b></div>`;
  let right = '';
  if (r.value === 'On' || r.value === 'Off') right = `<span class="sw ${r.value === 'On' ? 'on' : ''}"><i></i></span>`;
  else if (r.value) right = `<span class="dv">${esc(r.value)}</span>`;
  else if (r.tick) right = `<i class="ic tick" style="--m:url(${MI('check')})"></i>`;
  else if (r.arrow) right = '<span class="da">›</span>';
  return `<div class="fx dr ${r.dis ? 'dis' : ''}" data-a="dlg" data-i="${i}">${ico}<div class="dt"><b>${esc(r.label)}</b>${r.sub ? `<s>${esc(r.sub)}</s>` : ''}</div>${right}</div>`;
}
function dlgCol(rows, from, to) {
  let h = '', i = from;
  while (i < to) {
    const r = rows[i];
    if (r.head) h += `<div class="dh">${esc(r.head)}</div>`;
    if (r.kind === 'tile' || r.kind === 'main' || r.kind === 'pic') {
      const k = r.kind === 'pic' ? 'pic' : 'tile'; let j = i, part = '';
      while (j < to && (k === 'pic' ? rows[j].kind === 'pic' : (rows[j].kind === 'tile' || rows[j].kind === 'main')) && (j === i || !rows[j].head)) { part += dlgRow(rows[j], j); j++; }
      h += k === 'pic' ? `<div class="dpics ${rows[i].four ? 'four' : ''}">${part}</div>` : `<div class="dtiles">${part}</div>`;
      i = j;
    } else { h += dlgRow(r, i); i++; }
  }
  return h;
}
function dlg(o) {
  const rows = o.rows || [];
  const head = o.now ? `<div class="dnow"><div class="a" style="background-image:url('${esc(o.now.art || '')}')"></div><div class="w"><div class="k">${esc(o.now.kick || '')}</div><div class="t">${esc(o.now.title || '')}</div><div class="s">${esc(o.now.sub || '')}</div></div>${o.now.chips && o.now.chips.length ? `<div class="chips">${o.now.chips.map(c => `<span>${esc(c)}</span>`).join('')}</div>` : ''}</div>`
    : o.hero ? `<div class="dhero"><div class="a ${o.hero.shape || ''}" style="background-image:url('${esc(o.hero.art || '')}')"></div><div class="w"><div class="k">${esc(o.hero.kick || '')}</div><div class="t">${esc(o.hero.title || '')}</div><div class="s">${esc(o.hero.sub || '')}</div></div></div>` : '';
  const title = o.title ? `<div class="dtitle">${o.icon ? `<i class="ic" style="--m:url(${o.icon})"></i>` : ''}${esc(o.title)}</div>` : '';
  const body = o.q ? `<div class="dbtns">${rows.map((r, i) => dlgRow(Object.assign({ kind: 'tile' }, r), i)).join('')}</div>`
    : o.split ? `<div class="dcols"><div class="dcol">${dlgCol(rows, 0, o.split)}</div><div class="dcol">${dlgCol(rows, o.split, rows.length)}</div></div>` : dlgCol(rows, 0, rows.length);
  const foot = `<div class="dfoot"><span><kbd>OK</kbd>Choose</span>${o.split ? '<span><kbd>◂ ▸</kbd>Other column</span>' : ''}<span><kbd>BACK</kbd>Close</span></div>`;
  const L = openLayer('dlg', `<div class="dcard ${o.q ? 'q' : ''} ${o.split || o.wide ? 'wide' : ''}"><div class="twig"></div><div class="fly"></div>${title}${head}${o.message ? `<div class="dmsg">${esc(o.message)}</div>` : ''}<div class="dbody scroll">${body}</div>${foot}</div>`);
  L.o = o; L.rows = rows;
  const first = rows.findIndex(r => r.focus);
  setFocus((first >= 0 && $(`.fx[data-i="${first}"]`, L.el)) || $('.fx', L.el) || null);
  return L;
}
function dlgPick(el) {
  const L = layers[layers.length - 1]; if (!L || !L.o) return;
  const i = +el.dataset.i, r = L.rows[i];
  if (r.dis) { if (r.why) toast(r.why); return; }
  if (r.keep) {
    const res = L.o.pick ? L.o.pick(i, r, L, el) : null;
    if (res !== 'close') { const n = document.createElement('div'); n.innerHTML = dlgRow(r, i); const nn = n.firstChild; el.replaceWith(nn); setFocus(nn); return; }
    closeLayer(); return;
  }
  closeThen(() => { if (L.o.pick) L.o.pick(i, r, L, el); });
}
// a question or a notice: centred, words, the buttons in one row
function ask(title, message, buttons, cb) { return dlg({ q: true, title, message, rows: buttons.map((b, i) => ({ label: b, kind: i === 0 ? 'tile' : 'tile' })), pick: i => cb && cb(i) }); }
// the old list sheet, now a popup with a tick on the current choice
function pickSheet(title, labels, cb, cur) {
  return dlg({ title, rows: labels.map((l, i) => ({ label: l, tick: i === cur, focus: i === cur })), pick: i => cb(i) });
}

/* ---------- Music engine ---------- */
const aud = new Audio(); aud.preload = 'auto';
const shuf = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0;[a[i], a[j]] = [a[j], a[i]]; } return a; };
const mmss = s => { s = Math.max(0, s | 0); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };
const M = {
  queue: [], i: -1, playing: false, shuffle: PREF0('shuffle') === '1', repeat: PREF0('repeat') || 'off', hooks: new Set(), held: false,
  cur() { return this.queue[this.i]; },
  trackOf(md) {
    const media = (md.Media || [])[0], part = media && (media.Part || [])[0];
    const c = ((media && media.container) || '').toLowerCase(), codec = ((media && media.audioCodec) || '').toLowerCase();
    const okC = ['mp3', 'flac', 'mp4', 'm4a', 'aac', 'wav', 'ogg'].includes(c) && !['alac', 'wma', 'dts'].includes(codec);
    const sid = 'hm' + md.ratingKey;
    const url = !part ? '' : okC ? `${PX}${part.key}`
      : `${PX}/music/:/transcode/universal/start.mp3?path=${encodeURIComponent('/library/metadata/' + md.ratingKey)}&mediaIndex=0&partIndex=0&protocol=http&directPlay=0&directStream=0&session=${sid}`;
    return { id: md.ratingKey, title: md.title, artist: md.originalTitle || md.grandparentTitle || '', album: md.parentTitle || '', albumKey: md.parentRatingKey || '', year: md.parentYear || md.year || '', thumb: md.parentThumb || md.thumb || md.grandparentThumb, dur: (md.duration || 0) / 1000, url, file: (part && part.file) || '' };
  },
  async playList(items, start, shuffle) {
    const q = items.filter(m => m.type === 'track').map(m => this.trackOf(m)).filter(t => t.url);
    if (!q.length) { toast('Nothing playable there'); return; }
    start = Math.max(0, start || 0);
    if (shuffle || this.shuffle) { const first = q.splice(shuffle ? Math.random() * q.length | 0 : start, 1)[0]; shuf(q); q.unshift(first); start = 0; if (shuffle) this.setShuffle(true, true); }
    this.queue = q; this.i = start; this.load(true);
  },
  load(play) {
    const t = this.cur(); if (!t) return;
    aud.src = t.url;
    if (play) { this.held = false; aud.play().then(() => { this.playing = true; this.paint(); }).catch(() => { toast('The browser blocked sound until you press a key'); this.playing = false; this.paint(); }); }
    try { localStorage.setItem('hearth.last', JSON.stringify(t)); } catch (e) { /* ignore */ }
    this.paint(true);
  },
  toggle() {
    if (!this.cur()) { this.shuffleAll(); return; }
    if (aud.paused) aud.play().then(() => { this.playing = true; this.held = false; this.paint(); }); else { aud.pause(); this.playing = false; this.paint(); }
  },
  // the song ended (auto) or Next was pressed. Music never just stops: at the end of the queue it starts a fresh mix.
  next(auto) {
    if (!this.queue.length) return;
    if (auto && this.repeat === 'one') { aud.currentTime = 0; aud.play().catch(() => {}); return; }
    if (this.i + 1 < this.queue.length) { this.i++; this.load(true); return; }
    if (this.repeat === 'all' || !auto) { this.i = 0; this.load(true); return; }
    this.shuffleAll().catch(() => {});
  },
  prev() { if (!this.queue.length) return; if (aud.currentTime > 4) { aud.currentTime = 0; return; } this.i = (this.i - 1 + this.queue.length) % this.queue.length; this.load(true); },
  jump(i) { if (i >= 0 && i < this.queue.length) { this.i = i; this.load(true); } },
  async shuffleAll() {
    await libs();
    if (!musicLib) { toast('No music library found'); return; }
    toast('Mixing something up…');
    const mc = await pj(`/library/sections/${musicLib.key}/all`, { type: 10, sort: 'random', 'X-Plex-Container-Size': 60 });
    await this.playList(mc.Metadata || [], 0, false);
  },
  playNext(items) { const q = items.filter(m => m.type === 'track').map(m => this.trackOf(m)).filter(t => t.url); if (!this.cur()) { this.playList(items, 0); return; } this.queue.splice(this.i + 1, 0, ...q); toast(q.length === 1 ? 'Plays next' : q.length + ' songs play next'); this.paint(); },
  addQueue(items) { const q = items.filter(m => m.type === 'track').map(m => this.trackOf(m)).filter(t => t.url); if (!this.cur()) { this.playList(items, 0); return; } this.queue.push(...q); toast(q.length === 1 ? 'Added to the queue' : q.length + ' songs added to the queue'); this.paint(); },
  setShuffle(on, quiet) {
    this.shuffle = on; SETPREF0('shuffle', on ? '1' : '0');
    if (on && this.queue.length > this.i + 2) { const rest = this.queue.splice(this.i + 1); this.queue.push(...shuf(rest)); }
    if (!quiet) toast(on ? 'Shuffle on' : 'Shuffle off');
    this.paint();
  },
  cycleRepeat() { this.repeat = { off: 'all', all: 'one', one: 'off' }[this.repeat]; SETPREF0('repeat', this.repeat); toast({ off: 'Repeat off', all: 'Repeat all', one: 'Repeat this song' }[this.repeat]); this.paint(); },
  // a mood or a video takes the sound: music stops, and comes back after if it was playing
  hold() { if (this.playing) { aud.pause(); this.playing = false; this.held = true; this.paint(); } },
  release() { if (this.held && this.cur()) { this.held = false; aud.play().then(() => { this.playing = true; this.paint(); }).catch(() => {}); } },
  upNext(n) { const out = []; for (let k = 1; k <= n && this.i + k < this.queue.length; k++) out.push(this.queue[this.i + k]); return out; },
  paint(song) {
    const t = this.cur();
    const set = (id, fn) => { const e = document.getElementById(id); if (e) fn(e); };
    set('mc-t', e => e.textContent = t ? t.title : 'Shuffle my music');
    set('mc-s', e => e.textContent = t ? t.artist : 'OK to start a random mix');
    set('mc-eb', e => e.textContent = t ? (this.playing ? 'Now playing' : 'Paused') : 'Music');
    set('mc-pp', e => e.textContent = this.playing ? '❚❚' : '▶');
    set('mc-art', e => e.style.backgroundImage = t ? `url('${img(t.thumb, 360, 360)}')` : '');
    for (const f of this.hooks) { try { f(song); } catch (e) { console.error(e); } }
    paintChip();
  }
};
function PREF0(k) { try { return localStorage.getItem('hearth.' + k) || ''; } catch (e) { return ''; } }
function SETPREF0(k, v) { try { localStorage.setItem('hearth.' + k, v); } catch (e) { /* ignore */ } }
aud.addEventListener('ended', () => M.next(true));
aud.addEventListener('timeupdate', () => {
  const p = aud.duration ? aud.currentTime / aud.duration * 100 : 0;
  for (const e of $$('#mc-bar,.mprog')) e.style.width = p + '%';
  for (const e of $$('.mcur')) e.textContent = mmss(aud.currentTime);
  for (const e of $$('.mdur')) e.textContent = mmss(aud.duration || (M.cur() || {}).dur || 0);
  LY.tick();
});
aud.addEventListener('error', () => { if (M.cur() && aud.src) { toast('Skipping a song that wouldn\'t play'); setTimeout(() => M.next(true), 600); } });
try { const l = JSON.parse(localStorage.getItem('hearth.last') || 'null'); if (l && l.url) { M.queue = [l]; M.i = 0; aud.src = l.url; } } catch (e) { /* ignore */ }

// the now-playing chip in the top bar: while music plays and Music is not the room (HubScreen.updateChip)
function paintChip() {
  const c = $('#npc'); if (!c) return;
  const t = M.cur(), on = !!(t && M.playing && cur !== 'Music' && !stage.classList.contains('cover'));
  c.classList.toggle('on', on);
  if (!on) return;
  $('#npc-t').textContent = t.title; $('#npc-s').textContent = t.artist;
  const a = $('#npc-a'), u = `url("${img(t.thumb, 120, 120)}")`; if (a.style.backgroundImage !== u) a.style.backgroundImage = u;
  // centred in the gap between the Search glass (1390) and the twig's leaf (1622), never wider than it
  const w = Math.min(232, c.offsetWidth || 232); c.style.maxWidth = '232px';
  c.style.left = Math.round((1390 + 1622 - w) / 2) + 'px';
}

/* ---------- lyrics plaque (LyricsPanel, build 144) ---------- */
const LY = {
  el: null, id: '', times: [], lines: [], plain: '', idx: -2, on: PREF0('lyricsOn') !== '0', found: false, hidden: false,
  html() { return '<div class="lyr" id="lyr"><div class="bg"></div><div class="bd"></div><div class="tw a"></div><div class="tw b"></div>' + [0, 1, 2, 3, 4].map(k => `<div class="ln n${k === 2 ? 'c' : Math.abs(k - 2) === 1 ? '1' : '0'} ${k === 2 ? 'cur' : ''}"></div>`).join('') + '</div>'; },
  attach(el) { this.el = el; this.idx = -2; this.load(); },
  detach() { this.el = null; },
  async load() {
    const t = M.cur(); if (!t || !this.el) return;
    if (t.id === this.id) { this.paint(); return; }
    this.id = t.id; this.times = []; this.lines = []; this.plain = ''; this.found = false; this.idx = -2; this.show();
    try {
      const r = await fetch('/api/lyrics?' + new URLSearchParams({ artist: t.artist, title: t.title, album: t.album, duration: Math.round(t.dur), file: t.file }));
      const j = await r.json();
      if (t.id !== this.id) return;
      this.times = j.times || []; this.lines = j.lines || []; this.plain = j.plain || '';
      if (!this.times.length && this.plain) { this.lines = this.plain.split('\n').filter(x => x.trim()); }
      this.found = this.lines.length > 0;
    } catch (e) { this.found = false; }
    this.idx = -2; this.show(); this.tick();
  },
  show() { if (this.el) $('#lyr', this.el).classList.toggle('on', this.on && this.found && !this.hidden); },
  toggle() { this.on = !this.on; SETPREF0('lyricsOn', this.on ? '1' : '0'); this.show(); if (this.on && !this.found && this.el) toast('No words found for this song'); },
  tick() {
    if (!this.el || !this.found) return;
    let i;
    if (this.times.length) { i = 0; const p = aud.currentTime; for (let k = 0; k < this.times.length; k++) if (this.times[k] <= p) i = k; }
    else i = Math.min(this.lines.length - 1, Math.floor((aud.currentTime / (aud.duration || 1)) * this.lines.length));
    if (i === this.idx) return;
    this.idx = i; this.paint();
  },
  paint() {
    if (!this.el) return;
    const ns = $$('.lyr .ln', this.el), ys = [52, 102, 212, 348, 402];
    for (let k = 0; k < 5; k++) { const j = this.idx + k - 2; ns[k].textContent = j >= 0 && j < this.lines.length ? (this.lines[j] || '…') : ''; }
    // the current line: 52, then 44 on one line; longer becomes two gold lines and the rest makes room
    const c = ns[2]; c.classList.remove('s2'); c.style.top = ys[2] + 'px';
    let up = 0, down = 0;
    if (c.scrollHeight > 70) { c.classList.add('s2'); if (c.scrollHeight > 60) { up = 16; down = 24; c.style.top = (ys[2] + 39 - c.scrollHeight / 2) + 'px'; } }
    ns[0].style.top = (ys[0] - up) + 'px'; ns[1].style.top = (ys[1] - up) + 'px'; ns[3].style.top = (ys[3] + down) + 'px'; ns[4].style.top = (ys[4] + down) + 'px';
    $('.lyr .tw.a', this.el).style.top = (116 - up) + 'px'; $('.lyr .tw.b', this.el).style.top = (250 + down) + 'px';
  }
};

/* ---------- Music room, layout B (MusicRoom + MusicNowPanel "column") ---------- */
const MTABS = ['For you', 'Artists', 'Albums', 'Playlists', 'New'];
const MR = { tab: +PREF0('musicTab') || 0, data: {}, scroll: 0 };
function mtile(md, round) {
  const a = md.type === 'artist' ? 'artist' : 'album';
  const sub = md.type === 'artist' ? '' : md.type === 'playlist' ? `${md.leafCount || ''} songs` : (md.parentTitle || md.year || '');
  return `<div class="fx mt2 ${round ? 'round' : ''}" data-a="malb" data-k="${md.ratingKey}" data-t="${md.type}"><div class="im" data-bg="${img(md.thumb || md.composite, 300, 300)}"></div><div class="t">${esc(md.title)}</div><div class="s">${esc(sub)}</div></div>`;
}
const chipHTML = (ic, a, cls, extra) => `<div class="fx mchip ${cls || ''}" data-a="${a}" ${extra || ''}><i class="ic" style="--m:url(${MI(ic)})"></i></div>`;
function mcolHTML() {
  const t = M.cur();
  if (!t) {
    let last = null; try { last = JSON.parse(localStorage.getItem('hearth.lastList') || 'null'); } catch (e) { /* none */ }
    return `<div class="idle"><div class="k">Music</div><h2>Nothing playing</h2>
      <div class="fx ib2" data-a="mshuffle" data-first><i class="ic" style="--m:url(${MI('shuffle')})"></i>Shuffle my music</div>
      ${last ? `<div class="fx ib2" data-a="malb" data-k="${esc(last.k)}" data-t="${esc(last.t)}"><i class="ic" style="--m:url(${MI('play')})"></i>Carry on: ${esc(last.n)}</div>` : ''}
      <div class="lh">Played lately</div><div id="mlately"></div></div>`;
  }
  return `<div class="art" style="background-image:url('${img(t.thumb, 440, 440)}')"></div>
    <div class="eb">${M.playing ? 'Now playing' : 'Paused'} · ${M.i + 1} of ${M.queue.length}</div><div class="tt">${esc(t.title)}</div><div class="sb">${esc(t.artist + (t.album ? ' · ' + t.album : ''))}</div>
    <div class="braid2"><i class="mprog" style="width:${aud.duration ? aud.currentTime / aud.duration * 100 : 0}%"></i></div><div class="tm"><span class="mcur">${mmss(aud.currentTime)}</span><span class="mdur">${mmss(t.dur)}</span></div>
    <div class="ctl"><div>${chipHTML('prev', 'mprev', 'big')}<span>Previous</span></div><div>${chipHTML(M.playing ? 'pause' : 'play', 'mtoggle', 'big', 'data-first')}<span>${M.playing ? 'Pause' : 'Play'}</span></div><div>${chipHTML('next', 'mnext', 'big')}<span>Next</span></div><div>${chipHTML('shuffle', 'mshuf', 'big' + (M.shuffle ? ' lit' : ''))}<span>Shuffle</span></div><div>${chipHTML('more', 'mmore', 'big')}<span>More</span></div></div>`;
}
function paintMcol(song) {
  const c = $('#mcol'); if (!c || cur !== 'Music') return;
  const had = focusEl && c.contains(focusEl) ? focusEl.dataset.a : null;
  const t = M.cur();
  if (!song && t && $('.tt', c)) {
    // just the play state: keep the nodes (and focus) where they are
    $('.eb', c).textContent = `${M.playing ? 'Now playing' : 'Paused'} · ${M.i + 1} of ${M.queue.length}`;
    const pp = $('[data-a=mtoggle]', c); if (pp) { $('.ic', pp).style.setProperty('--m', `url(${MI(M.playing ? 'pause' : 'play')})`); pp.nextElementSibling.textContent = M.playing ? 'Pause' : 'Play'; }
    const sh = $('[data-a=mshuf]', c); if (sh) sh.classList.toggle('lit', M.shuffle);
    return;
  }
  c.innerHTML = mcolHTML();
  if (!t) mLately();
  if (had) setFocus($(`[data-a=${had}]`, c) || $('[data-a=mtoggle]', c) || $('.fx', c));
}
async function mLately() {
  const box = $('#mlately'); if (!box || !musicLib) return;
  try {
    const mc = await pj(`/library/sections/${musicLib.key}/albums`, { sort: 'lastViewedAt:desc', 'X-Plex-Container-Size': 4 });
    if (!document.contains(box)) return;
    box.innerHTML = (mc.Metadata || []).slice(0, 4).map(md => `<div class="fx li" data-a="malb" data-k="${md.ratingKey}" data-t="album"><div class="a" style="background-image:url('${img(md.thumb, 120, 120)}')"></div><div><b>${esc(md.title)}</b><s>${esc(md.parentTitle || '')}</s></div></div>`).join('') || '<div class="ms">Nothing yet</div>';
  } catch (e) { box.innerHTML = ''; }
}
M.hooks.add(paintMcol);
async function roomMusic(room, tok) {
  await libs();
  if (!musicLib) { room.innerHTML = '<div class="msg">No music library in Plex yet.</div>'; return; }
  room.innerHTML = `<div class="mroom"><div class="mcol" id="mcol"></div>
    <div class="mtabs">${MTABS.map((t, i) => `<div class="fx mword ${i === MR.tab ? 'cur' : ''}" data-a="mtab" data-i="${i}">${t}</div>`).join('')}</div>
    <div id="mlet"></div><div class="mbody" id="mbody"><div class="scroll" id="mscroll"><div class="msg" style="position:relative;height:300px">Loading…</div></div></div></div>`;
  paintMcol(true);
  await mShowTab(tok);
}
async function mList(key, params) {
  if (MR.data[key] && Date.now() - MR.data[key].at < 300000) return MR.data[key].v;
  const mc = await pj(...params); const v = (mc.Metadata || []).filter(m => !hiddenItem(m));
  MR.data[key] = { at: Date.now(), v }; return v;
}
async function mShowTab(tok) {
  const sc = $('#mscroll'), body = $('#mbody'), let_ = $('#mlet'); if (!sc) return;
  const tab = MR.tab; let_.innerHTML = ''; body.classList.remove('lettered');
  const S = musicLib.key;
  const letters = items => {
    const first = {}; items.forEach((m, i) => { let c = (m.titleSort || m.title || '').trim().charAt(0).toUpperCase(); if (!/[A-Z]/.test(c)) c = '#'; if (first[c] === undefined) first[c] = i; });
    let_.innerHTML = `<div class="mletters">${'#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map(c => first[c] !== undefined ? `<div class="fx" data-a="mlet" data-i="${first[c]}">${c}</div>` : `<div class="dim">${c}</div>`).join('')}</div>`;
    body.classList.add('lettered');
  };
  try {
    if (tab === 0) {
      sc.innerHTML = '';
      const shelf = (t, s, items, round) => { if (tok !== renderTok || MR.tab !== 0 || !items.length) return; sc.insertAdjacentHTML('beforeend', hd(t, s) + `<div class="row">${items.map(m => mtile(m, round)).join('')}</div>`); };
      const [lately, recent, lists, artists] = await Promise.all([
        mList('lately', [`/library/sections/${S}/albums`, { sort: 'lastViewedAt:desc', 'X-Plex-Container-Size': 20 }]).catch(() => []),
        mList('recent', [`/library/sections/${S}/albums`, { sort: 'addedAt:desc', 'X-Plex-Container-Size': 20 }]).catch(() => []),
        mList('lists', ['/playlists', { playlistType: 'audio' }]).catch(() => []),
        mList('topart', [`/library/sections/${S}/all`, { type: 8, sort: 'viewCount:desc', 'X-Plex-Container-Size': 20 }]).catch(() => [])]);
      shelf('Played lately', `${lately.length} albums`, lately.filter(m => m.lastViewedAt || m.viewCount));
      shelf('Recently added', `${recent.length} albums`, recent);
      shelf('Playlists', `${lists.length}`, lists.filter(x => x.leafCount > 0));
      shelf('Artists you play', `${artists.length}`, artists, true);
      if (!sc.children.length) sc.innerHTML = '<div class="mmsg" style="position:relative;left:0;top:0">Nothing here yet. Play something and it shows up.</div>';
    } else if (tab === 1 || tab === 2 || tab === 3) {
      const items = tab === 1 ? await mList('artists', [`/library/sections/${S}/all`, { type: 8, sort: 'titleSort' }])
        : tab === 2 ? await mList('albums', [`/library/sections/${S}/albums`, { sort: 'titleSort' }])
          : (await mList('lists', ['/playlists', { playlistType: 'audio' }])).filter(x => x.leafCount > 0);
      if (tok !== renderTok || MR.tab !== tab) return;
      if (tab !== 3) letters(items);
      sc.innerHTML = items.length ? `<div class="mgrid">${items.map(m => mtile(m, tab === 1)).join('')}</div>` : '<div class="mmsg" style="position:relative;left:0;top:0">Nothing here yet.</div>';
    } else {
      const items = await mList('recent', [`/library/sections/${S}/albums`, { sort: 'addedAt:desc', 'X-Plex-Container-Size': 20 }]);
      if (tok !== renderTok || MR.tab !== 4) return;
      const sp = items[0];
      sc.innerHTML = sp ? `<div class="mspot"><div class="im" style="background-image:url('${img(sp.thumb, 300, 300)}')"></div><div class="k">Newest in your library</div><div class="t">${esc(sp.title)}</div><div class="s">${esc((sp.parentTitle || '') + (sp.year ? ' · ' + sp.year : ''))}</div>
        <div class="ch"><div class="fx mchip wide" data-a="mplayk" data-k="${sp.ratingKey}"><i class="ic" style="--m:url(${MI('play')})"></i>Play</div><div class="fx mchip wide" data-a="mshufk" data-k="${sp.ratingKey}"><i class="ic" style="--m:url(${MI('shuffle')})"></i>Shuffle</div><div class="fx mchip wide" data-a="malb" data-k="${sp.ratingKey}" data-t="album"><i class="ic" style="--m:url(${MI('more')})"></i>More</div></div></div>`
        + hd('Also new', `${items.length - 1} albums`) + `<div class="mgrid">${items.slice(1).map(m => mtile(m)).join('')}</div>` : '<div class="mmsg" style="position:relative;left:0;top:0">Nothing new yet.</div>';
    }
  } catch (e) {
    if (tok === renderTok) sc.innerHTML = `<div class="mmsg" style="position:relative;left:0;top:0">Plex didn't answer. <div class="fx mchip wide" data-a="mtab" data-i="${tab}" style="display:inline-flex;margin-left:20px"><i class="ic" style="--m:url(${MI('right')})"></i>Try again</div></div>`;
  }
}
// an album, playlist or artist: the Roku's album menu (cover, four big buttons, then more)
async function albumKids(id, type) {
  if (type === 'playlist') return ((await pj(`/playlists/${id}/items`)).Metadata || []).filter(t => !hiddenItem(t));
  if (type === 'artist') return ((await pj(`/library/metadata/${id}/allLeaves`)).Metadata || []).filter(t => !hiddenItem(t));
  return ((await pj(`/library/metadata/${id}/children`)).Metadata || []).filter(t => !hiddenItem(t));
}
async function albumMenu(id, type) {
  const meta = type === 'playlist' ? ((await pj(`/playlists/${id}`)).Metadata || [])[0] || {} : ((await pj(`/library/metadata/${id}`)).Metadata || [])[0] || {};
  const kids = await albumKids(id, type);
  const total = kids.reduce((a, k) => a + (k.duration || 0), 0) / 60000 | 0;
  try { localStorage.setItem('hearth.lastList', JSON.stringify({ k: id, t: type, n: meta.title || '' })); } catch (e) { /* ignore */ }
  const rows = [
    { label: 'Play', sub: 'From the top', icon: MI('play'), kind: 'main', go: () => M.playList(kids, 0) },
    { label: 'Shuffle', sub: 'Mixed up', icon: MI('shuffle'), kind: 'tile', go: () => M.playList(kids, 0, true) },
    { label: 'Play next', sub: 'After this song', icon: MI('next'), kind: 'tile', go: () => M.playNext(kids) },
    { label: 'Add to queue', sub: 'At the end', icon: MI('queue'), kind: 'tile', go: () => M.addQueue(kids) },
    { label: 'Songs', sub: `All ${kids.length}, pick one to start there`, icon: MI('list'), arrow: true, go: () => openAlbum(id, type) }];
  if (type === 'artist') {
    try {
      const albs = ((await pj(`/library/metadata/${id}/children`)).Metadata || []).slice(0, 8);
      albs.forEach((a, i) => rows.push({ head: i === 0 ? 'Albums' : '', label: a.title, pic: img(a.thumb, 300, 300), kind: 'pic', four: true, go: () => albumMenu(a.ratingKey, 'album').catch(e => toast(e.message)) }));
    } catch (e) { /* no albums list */ }
  }
  dlg({
    wide: type === 'artist',
    hero: { art: img(meta.thumb || meta.composite, 300, 300), shape: type === 'artist' ? 'round' : '', kick: type === 'artist' ? 'Artist' : type === 'playlist' ? 'Playlist' : 'Album' + (meta.year ? ' · ' + meta.year : ''), title: meta.title || '', sub: [type === 'album' ? meta.parentTitle : '', kids.length + ' songs', total ? total + ' min' : ''].filter(Boolean).join(' · ') },
    rows, pick: (i, r) => r.go()
  });
}
async function openAlbum(id, type) {
  const kids = await albumKids(id, type);
  const meta = type === 'playlist' ? ((await pj(`/playlists/${id}`)).Metadata || [])[0] || {} : ((await pj(`/library/metadata/${id}`)).Metadata || [])[0] || {};
  const rows = kids.map((t, n) => `<div class="fx trk" data-a="mtrack" data-n="${n}"><b>${t.index || n + 1}</b><span>${esc(t.title)}</span><em>${t.duration ? mmss(t.duration / 1000) : ''}</em></div>`).join('');
  const L = openLayer('sheet', `<div class="in"><div class="cov" style="background-image:url('${img(meta.thumb || meta.composite, 720, 720)}')"></div>
    <div style="position:relative;flex:1"><h2>${esc(meta.title || '')}</h2><div class="ar">${esc(meta.parentTitle || meta.leafCount && meta.leafCount + ' songs' || '')}</div>
    <div style="display:flex;gap:16px;margin-bottom:22px"><div class="fx chip live" data-a="sheetplay">▶ Play</div><div class="fx chip" data-a="sheetshuf">Shuffle</div><div class="fx chip" data-a="back">‹ Back</div></div>
    <div style="position:absolute;left:0;right:0;top:150px;bottom:0;overflow:hidden" class="tl-wrap"><div class="tl scroll" style="padding:6px 0 80px">${rows || '<div class="ms">No songs here.</div>'}</div></div></div></div>`);
  L.kids = kids;
}
// More: the music options popup (mockups/popups-rich/1-music-options.png)
function musicOptions() {
  const t = M.cur();
  const left = (aud.duration || (t && t.dur) || 0) - aud.currentTime, nx = M.upNext(1)[0];
  const rows = [
    { head: 'Playback', label: 'Shuffle', sub: 'Mix up what is queued', icon: MI('shuffle'), value: M.shuffle ? 'On' : 'Off', keep: true, go: r => { M.setShuffle(!M.shuffle); r.value = M.shuffle ? 'On' : 'Off'; } },
    { label: 'Repeat', sub: 'Off, all, or one song', icon: MI('repeat'), value: M.repeat.toUpperCase(), keep: true, go: r => { M.cycleRepeat(); r.value = M.repeat.toUpperCase(); } },
    { head: 'Words', label: 'Lyrics', sub: 'Show the words as it plays', icon: MI('lyrics'), value: LY.on ? 'On' : 'Off', keep: true, go: r => { LY.toggle(); r.value = LY.on ? 'On' : 'Off'; } },
    { label: 'Queue', sub: t ? `${M.queue.length} songs · what plays next` : 'Nothing queued yet', icon: MI('queue'), arrow: true, dis: !t, why: 'Nothing queued yet', go: () => queueSheet() },
    { head: 'On screen', label: 'Cover', pic: t ? img(t.thumb, 300, 300) : 'img/col-window.jpg', kind: 'pic', go: () => musicView('cover') },
    { label: 'Visualizer', pic: 'img/viz/221.jpg', kind: 'pic', go: () => musicView('milk') },
    { label: 'Hearth fire', pic: 'img/col-hearth.jpg', kind: 'pic', go: () => musicView('hearth') },
    { head: 'Player', label: 'Big view', sub: 'The player, full screen', icon: MI('expand'), arrow: true, go: () => musicView('big') },
    { label: 'Shuffle my music', sub: 'A fresh mix from everything', icon: MI('wave'), go: () => M.shuffleAll().catch(e => toast(e.message)) }];
  dlg({
    title: 'Music', icon: MI('disc'), split: 4,
    now: t ? { art: img(t.thumb, 200, 200), kick: M.playing ? 'Playing now' : 'Paused', title: t.title, sub: t.artist + (t.album ? ' · ' + t.album : ''), chips: [mmss(left) + ' left'].concat(nx ? ['Up next: ' + nx.title] : []) } : null,
    rows, pick: (i, r) => r.go(r)
  });
}
// QueueSheet A: the queue as a side sheet; OK plays from that song
function queueSheet() {
  if (!M.queue.length) { toast('Nothing queued yet'); return; }
  const rows = M.queue.map((t, i) => `<div class="fx qrow ${i === M.i ? 'now' : ''}" data-a="qjump" data-i="${i}"><div class="a" data-bg="${img(t.thumb, 120, 120)}" style="background-image:url('${img(t.thumb, 120, 120)}')"></div><div class="w"><b>${esc(t.title)}</b><s>${esc(t.artist)}</s></div><em>${i === M.i ? 'Playing' : mmss(t.dur)}</em></div>`).join('');
  const L = openLayer('qsheet', `<div class="qp"><h2>Queue</h2><div class="qs">${M.queue.length} songs · OK plays from that song</div><div class="scroll">${rows}</div></div>`);
  setFocus($(`.qrow[data-i="${M.i}"]`, L.el) || $('.qrow', L.el));
}

/* ---------- full-screen music: Big view, Cover, Visualizer, Hearth fire (MusicView) ---------- */
const LOOKS = [['40', 'Truly soft'], ['57', 'Angel flight'], ['58', 'Another kind of groove'], ['61', 'Chain breaker'], ['62', 'Charisma'], ['74', 'Reflections on black tiles'], ['77', 'Witchcraft'], ['78', 'Fata morgana'], ['94', 'Rewop'], ['99', 'True visionary'], ['102', 'Prismo'], ['108', 'Hexcollie'], ['109', 'Spark'], ['110', 'In da mash'], ['111', 'Disco mashup'], ['117', 'Witchcraft 2'], ['119', 'Bouncing balls'], ['201', 'Leaf mandala'], ['202', 'Ladybug swarm'], ['203', 'Leaf down a creek'], ['204', 'Dandelion drift'], ['205', 'Firefly meadow'], ['206', 'Rain on the pond'], ['213', 'Dusk flight'], ['221', 'Moth lantern'], ['222', 'Murmuration'], ['223', 'Mushrooms'], ['224', 'Smoke rings'], ['225', 'Tree rings'], ['226', 'Fern crown'], ['227', 'Fiddleheads'], ['228', 'Moonlit fronds'], ['229', 'Constellation weave'], ['230', 'Honeycomb glow'], ['231', 'Jellyfish'], ['232', 'Aurora over the hills'], ['233', 'Dew on the web'], ['234', 'Mycelium']];
const lookName = n => (LOOKS.find(l => l[0] === n) || [n, 'Look ' + n])[1];
const VZ = {
  choice: PREF0('vizLook') || 'all', // 'all', 'hearted' or a look number
  stars: new Set((PREF0('vizStars') || '').split(',').filter(Boolean)),
  have: null, // looks that have a loop on the NAS
  async loops() {
    if (this.have) return this.have;
    try { const j = await (await fetch('/api/viz/loops')).json(); this.have = new Set((j.looks || []).map(String)); } catch (e) { this.have = new Set(); }
    return this.have;
  },
  setStar(n, on) { if (on) this.stars.add(n); else this.stars.delete(n); SETPREF0('vizStars', [...this.stars].join(',')); },
  setChoice(c) { this.choice = c; SETPREF0('vizLook', c); },
  pool() { const all = LOOKS.map(l => l[0]).filter(n => !this.have || !this.have.size || this.have.has(n)); const h = all.filter(n => this.stars.has(n)); return this.choice === 'hearted' && h.length ? h : all; },
  pick(not) { if (/^\d+$/.test(this.choice)) return this.choice; const p = this.pool().filter(n => n !== not); return p.length ? p[Math.random() * p.length | 0] : '221'; }
};
let FIRE = PREF0('fireMix') || 'both'; // both, fire (fire only), music (music only)
function musicView(mode) {
  const top = layers[layers.length - 1];
  if (top && top.mv) { top.setMode(mode); return; }
  if (!M.cur() && mode !== 'hearth') { toast('Play something first'); M.shuffleAll().catch(() => {}); }
  const L = openLayer('mview ' + mode, `<div class="bgart"></div><video class="vz" muted playsinline loop preload="auto" style="display:none"></video>
    <div class="hudbox hud"><div class="note" style="display:none"></div>${LY.html()}
    <div class="ctl"><div class="shadeA"></div><div class="tag"></div><div class="cart"></div><div class="art6"></div><div class="eb"></div><div class="tt"></div><div class="sb"></div>
      <div class="braid2 bv"><i class="mprog"></i></div><div class="tm"><span class="mcur">0:00</span><span class="mdur">0:00</span></div>
      <div class="row6"></div><div class="cname"></div><div class="toast2"></div>
      <div class="unx">Up next</div><div class="unt"></div><div class="unl"></div></div></div>`, {
    onKey(e) { return L.key(e); }
  });
  L.mv = true; L.mode = null; L.look = null; L.ctlOn = true;
  const v = $('video.vz', L.el), fx = new Audio('sound/fire.mp3'); fx.loop = true; fx.volume = .55; L.sfx = fx;
  const ctl = $('.ctl', L.el);
  L.showCtl = (on) => {
    L.ctlOn = on; ctl.classList.toggle('off', !on); clearTimeout(L.ct);
    LY.hidden = on && L.mode !== 'cover'; LY.show();
    if (on) { if (!focusEl || !L.el.contains(focusEl)) setFocus($('.row6 [data-a=mvtoggle]', L.el) || $('.row6 .fx', L.el)); if (L.mode !== 'big') L.ct = setTimeout(() => L.showCtl(false), 8000); }
    else setFocus(null);
  };
  L.row = () => {
    const ch = (ic, a, name, cls) => `<div class="fx mchip ${cls || ''}" data-a="${a}" data-n="${esc(name)}"><i class="ic" style="--m:url(${MI(ic)})"></i></div>`;
    const sep = '<div class="sepv"></div>';
    let h = ch('prev', 'mvprev', 'Previous') + ch(M.playing ? 'pause' : 'play', 'mvtoggle', M.playing ? 'Pause' : 'Play', 'big') + ch('next', 'mvnext', 'Next') + ch('shuffle', 'mvshuf', 'Shuffle ' + (M.shuffle ? 'on' : 'off'), M.shuffle ? 'lit' : '') + ch('repeat', 'mvrep', 'Repeat ' + M.repeat, M.repeat !== 'off' ? 'lit' : '') + sep;
    if (L.mode === 'milk') h += ch('cover', 'mvmode', 'Cover').replace('data-a="mvmode"', 'data-a="mvmode" data-m="cover"') + ch('fire', 'mvmode', 'Hearth fire').replace('data-a="mvmode"', 'data-a="mvmode" data-m="hearth"') + sep + `<div class="fx mchip wide" data-a="mvlook" data-n="Heart this look, or pick another"><i class="ic" style="--m:url(${MI('viz')})"></i>Look</div>`;
    else if (L.mode === 'hearth') h += ch('cover', 'mvmode', 'Cover').replace('data-a="mvmode"', 'data-a="mvmode" data-m="cover"') + ch('viz', 'mvmode', 'Visualizer').replace('data-a="mvmode"', 'data-a="mvmode" data-m="milk"') + sep + `<div class="fx mchip wide" data-a="mvfire" data-n="Fire and music, fire only, or music only"><i class="ic" style="--m:url(${MI('fire')})"></i>Fire</div>`;
    else h += ch('cover', 'mvmode', 'Cover').replace('data-a="mvmode"', 'data-a="mvmode" data-m="cover"') + ch('viz', 'mvmode', 'Visualizer').replace('data-a="mvmode"', 'data-a="mvmode" data-m="milk"') + ch('fire', 'mvmode', 'Hearth fire').replace('data-a="mvmode"', 'data-a="mvmode" data-m="hearth"');
    h += `<div class="fx mchip wide lib" data-a="mvlib" data-n="Back to the Music room"><i class="ic" style="--m:url(${MI('collapse')})"></i>Library</div>`;
    const was = focusEl && L.el.contains(focusEl) ? (focusEl.dataset.a + (focusEl.dataset.m || '')) : null;
    $('.row6', L.el).innerHTML = h;
    if (was) setFocus($$('.row6 .fx', L.el).find(x => x.dataset.a + (x.dataset.m || '') === was) || null);
  };
  L.tag = () => {
    const t = { big: 'Big view', cover: 'Cover', milk: 'Visualizer · ' + (L.look ? lookName(L.look) : '…'), hearth: 'Hearth fire · ' + { both: 'Fire and music', fire: 'Fire only', music: 'Music only' }[FIRE] }[L.mode];
    $('.tag', L.el).textContent = t;
  };
  L.paint = (song) => {
    const t = M.cur();
    $('.eb', L.el).textContent = t ? `${M.playing ? 'Now playing' : 'Paused'} · ${M.i + 1} of ${M.queue.length}` : 'Music';
    $('.tt', L.el).textContent = t ? t.title : 'Nothing playing';
    $('.sb', L.el).textContent = t ? t.artist + (t.album ? ' · ' + t.album : '') : 'Shuffle my music from the Music room';
    const a = t ? `url("${img(t.thumb, 600, 600)}")` : '';
    for (const s of ['.art6', '.cart']) $(s, L.el).style.backgroundImage = a;
    $('.bgart', L.el).style.backgroundImage = a;
    $('.unl', L.el).innerHTML = M.upNext(4).map(x => `<div><div class="a" style="background-image:url('${img(x.thumb, 120, 120)}')"></div><div><b>${esc(x.title)}</b><s>${esc(x.artist)} · ${mmss(x.dur)}</s></div></div>`).join('');
    const none = !M.upNext(1).length; $('.unx', L.el).style.display = $('.unt', L.el).style.display = none ? 'none' : '';
    L.row(); L.tag();
    if (song) { LY.load(); if (L.mode === 'milk' && !/^\d+$/.test(VZ.choice)) L.setLook(VZ.pick(L.look)); }
    if (L.mode === 'hearth') L.fireSound();
  };
  L.note = t => { const n = $('.note', L.el); n.style.display = t ? '' : 'none'; n.textContent = t || ''; };
  L.setLook = async n => {
    const have = await VZ.loops();
    let shown = n;
    if (have.size && !have.has(n)) { const p = VZ.pool(); shown = p.length ? p[Math.random() * p.length | 0] : null; L.say(`${lookName(n)} has no loop on the NAS yet, showing ${shown ? lookName(shown) : 'nothing'}`); }
    L.look = shown; L.tag();
    if (!shown) { v.style.display = 'none'; L.note('No visualizer loops on the NAS yet. The NucBox makes them; check back in a while.'); return; }
    L.note(''); v.style.display = ''; v.src = '/api/viz/loopfile?n=' + shown; v.play().catch(() => {});
  };
  v.addEventListener('error', () => { if (L.mode === 'milk') L.note("This look's loop didn't load from the NAS. Press Right for another."); else if (L.mode === 'hearth') L.note("The fire clip didn't load from the NAS."); });
  v.addEventListener('playing', () => L.note(''));
  L.say = t => { const e = $('.toast2', L.el); e.textContent = t; clearTimeout(L.st); L.st = setTimeout(() => { e.textContent = ''; }, 4000); if (!L.ctlOn) toast(t); };
  L.fireSound = () => {
    if (L.mode === 'hearth' && FIRE !== 'music') fx.play().catch(() => {}); else fx.pause();
    if (L.mode === 'hearth' && FIRE === 'fire') M.hold(); else M.release();
  };
  L.setMode = async m => {
    L.mode = m; L.el.className = 'layer mview ' + m;
    v.pause(); v.style.display = 'none'; L.note('');
    if (m === 'milk') L.setLook(/^\d+$/.test(VZ.choice) ? VZ.choice : VZ.pick(L.look));
    if (m === 'hearth') {
      const c = (await clips()).hearth;
      if (L.mode !== 'hearth') return;
      if (c && c.clip) { v.style.display = ''; v.src = c.clip.url; v.play().catch(() => {}); } else L.note('No fire clip in the hearth folder on the NAS yet (a file whose name starts with "fire").');
    }
    L.fireSound(); L.paint(); LY.show();
    L.showCtl(true);
  };
  L.key = e => {
    const k = e.key;
    if (!L.ctlOn) {
      if (k === 'ArrowLeft' || k === 'ArrowRight') { if (L.mode === 'milk') { const p = VZ.pool(), i = Math.max(0, p.indexOf(L.look)); const n = p[(i + (k === 'ArrowRight' ? 1 : p.length - 1)) % p.length]; if (/^\d+$/.test(VZ.choice)) VZ.setChoice(n); L.setLook(n); toast(lookName(n)); } else L.showCtl(true); return true; }
      if (k === 'ArrowUp') { LY.toggle(); return true; }
      if (k === 'Enter' || k === ' ' || k === 'ArrowDown') { L.showCtl(true); return true; }
      return false;
    }
    if (L.mode !== 'big') { clearTimeout(L.ct); L.ct = setTimeout(() => L.showCtl(false), 8000); }
    if (k === 'ArrowUp' || k === 'ArrowDown') return true; // one row of buttons
    return false;
  };
  L.onBack = () => { if (L.ctlOn && L.mode !== 'big') { L.showCtl(false); return true; } return false; };
  L.onMouse = () => { if (!L.ctlOn) L.showCtl(true); };
  L.hook = s => { if (document.contains(L.el)) L.paint(s); };
  M.hooks.add(L.hook);
  L.close = () => { M.hooks.delete(L.hook); clearTimeout(L.ct); fx.pause(); v.pause(); v.removeAttribute('src'); v.load(); LY.detach(); M.release(); };
  // cname: the name of the focused button
  L.onFocus = el => { const n = $('.cname', L.el); if (n) n.textContent = el && el.dataset.n ? el.dataset.n : ''; };
  LY.attach(L.el);
  L.setMode(mode);
  return L;
}
function lookMenu(L) {
  const n = L.look || '221';
  const rows = [
    { head: 'This look', label: 'Heart this look', sub: lookName(n), icon: MI('heart'), value: VZ.stars.has(n) ? 'On' : 'Off', keep: true, go: r => { VZ.setStar(n, !VZ.stars.has(n)); r.value = VZ.stars.has(n) ? 'On' : 'Off'; } },
    { label: 'Keep this look', sub: 'Every song, until you pick another', icon: MI('check'), tick: VZ.choice === n, go: () => { VZ.setChoice(n); L.tag(); toast('Keeping ' + lookName(n)); } },
    { head: 'Which looks play', label: 'Play hearted looks', sub: VZ.stars.size ? `${VZ.stars.size} hearted, a new one each song` : 'Heart a few first', icon: MI('heart'), tick: VZ.choice === 'hearted', dis: !VZ.stars.size, why: 'Heart a look first', go: () => { VZ.setChoice('hearted'); L.setLook(VZ.pick(L.look)); } },
    { label: 'Play every look', sub: 'A new one each song', icon: MI('shuffle'), tick: VZ.choice === 'all', go: () => { VZ.setChoice('all'); L.setLook(VZ.pick(L.look)); } }];
  LOOKS.forEach(([k, name], i) => rows.push({ head: i === 0 ? 'Every look' : '', label: name, pic: `img/viz/${k}.jpg`, kind: 'pic', four: true, hrt: VZ.stars.has(k), cur: k === n, go: () => { VZ.setChoice(k); L.setLook(k); } }));
  dlg({ title: 'Visualizer', icon: MI('viz'), wide: true, now: { art: `img/viz/${n}.jpg`, kick: 'Showing now', title: lookName(n), sub: VZ.choice === 'all' ? 'Every look, a new one each song' : VZ.choice === 'hearted' ? 'Hearted looks, a new one each song' : 'Kept for every song' }, rows, pick: (i, r) => r.go(r) });
}
function fireMenu(L) {
  const set = m => { FIRE = m; SETPREF0('fireMix', m); L.fireSound(); L.tag(); };
  dlg({ title: 'Hearth fire', icon: MI('fire'), rows: [
    { label: 'Fire and music', sub: 'The crackle under your songs', icon: MI('fire'), tick: FIRE === 'both', go: () => set('both') },
    { label: 'Fire only', sub: 'The music waits', icon: MI('fire'), tick: FIRE === 'fire', go: () => set('fire') },
    { label: 'Music only', sub: 'The fire stays quiet', icon: MI('disc'), tick: FIRE === 'music', go: () => set('music') }], pick: (i, r) => r.go() });
}

/* ---------- Ambiance: five tall columns (AmbianceRoom); your clips from the hearth folder on the NAS ---------- */
const AMB = [['hearth', 'Hearth', 'A log fire, crackling'], ['rain', 'Rain', 'On the glass, after dark'], ['fireflies', 'Fireflies', 'A summer night outside'], ['lightsout', 'Lights out', 'Embers, then dark in 30 min'], ['window', 'The Window', 'Your photos']];
const SOUND = { hearth: 'fire', rain: 'rain', fireflies: 'night', lightsout: 'fire' };
let clipCache = null;
function clipMood(name) {
  const n = (name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  for (const [p, m] of [['firefl', 'fireflies'], ['lightsout', 'lightsout'], ['embers', 'lightsout'], ['hearth', 'hearth'], ['fireplace', 'hearth'], ['campfire', 'hearth'], ['fire', 'hearth'], ['rain', 'rain']]) if (n.startsWith(p)) return m;
  return '';
}
const niceName = n => { n = String(n || '').trim().replace(/-tv$/i, '').replace(/[_-]/g, ' ').trim(); return n ? n.charAt(0).toUpperCase() + n.slice(1) : ''; };
function ownLine(n) {
  n = n.toLowerCase();
  for (const [ws, l] of [[['creek', 'river', 'stream', 'brook', 'falls'], 'Water over stones'], [['handpan', 'guitar', 'piano', 'harp', 'flute'], 'Played in the forest'], [['flower', 'meadow', 'bloom', 'garden'], 'In bloom'], [['snow', 'winter'], 'Snow falling'], [['ocean', 'sea', 'wave', 'lake', 'beach'], 'By the water']]) if (ws.some(w => n.includes(w))) return l;
  return 'Your own footage';
}
// the moods in room order, with the folder's clips merged in (ambMerge): a clip that matches a mood plays there,
// the rest become moods of their own before The Window, and Lights out borrows the fire when it has no embers
async function clips() {
  if (clipCache && Date.now() - clipCache.at < 120000) return clipCache.v;
  const items = AMB.map(([mood, title, sub]) => ({ mood, title, sub, still: `img/col-${mood}.jpg` }));
  const v = {}; items.forEach(it => { v[it.mood] = it; });
  let list = [];
  try { const j = await (await fetch('/api/clips')).json(); list = (j.clips || []).filter(c => c.ready); } catch (e) { /* none: the drawn scenes stand in */ }
  const path = u => { try { return new URL(u, location.href).pathname; } catch (e) { return u; } };
  const extra = [];
  for (const c of list) {
    const clip = { url: path(c.url), thumb: c.thumb ? path(c.thumb) : '', name: niceName(c.name || c.file) };
    const md = clipMood(c.file) || clipMood(c.name);
    if (md && v[md] && !v[md].clip) {
      v[md].clip = clip; if (clip.thumb) v[md].still = clip.thumb;
      const same = clip.name.toLowerCase() === v[md].title.toLowerCase() || (clipMood(clip.name) === md && !clip.name.includes(' '));
      if (!same) v[md].sub = clip.name;
    } else if (!md) extra.push({ mood: 'own' + extra.length, title: clip.name, sub: ownLine(clip.name), still: clip.thumb || 'img/col-window.jpg', clip, own: true });
  }
  if (!v.lightsout.clip && v.hearth.clip) { v.lightsout.clip = v.hearth.clip; v.lightsout.still = v.hearth.still; }
  const out = []; for (const it of items) { if (it.mood === 'window') out.push(...extra); out.push(it); }
  out.forEach(it => { v[it.mood] = it; });
  clipCache = { at: Date.now(), v: Object.assign(v, { list: out }) };
  return clipCache.v;
}
const AG = { H: 930, RULE: 24, PEEK: 80, VIS: 5 }; AG.W = Math.floor((1920 - (AG.VIS + 1) * AG.RULE - 2 * AG.PEEK) / AG.VIS);
const ambSoundOn = m => PREF0('ambSound_' + m) !== '0';
async function roomAmbiance(room, tok) {
  const v = await clips(); if (tok !== renderTok) return;
  const items = v.list, n = items.length, px = i => i * (AG.W + AG.RULE);
  let last = PREF0('ambLast'); let idx = Math.max(0, items.findIndex(it => it.mood === last));
  room.innerHTML = `<div class="amb"><div class="strip" id="astrip">${items.map((it, i) => `<div class="fx ap" data-a="amood" data-i="${i}" ${i === idx ? 'data-first' : ''} style="left:${px(i)}px;width:${AG.W}px;background-image:url('${esc(it.still)}')"><div class="st"></div><div class="sb"></div><div class="n">${String(i + 1).padStart(2, '0')}</div><div class="t"><div class="w">${esc(it.title)}</div><div class="s">${esc(it.sub)}</div></div>
    <div class="c"><div><img src="img/amb/icon-ok.png" alt="">${it.mood === 'window' ? 'Open' : 'Play'}</div>${it.mood === 'window' ? '' : `<div><img class="snd" src="img/amb/icon-sound-${ambSoundOn(it.mood) ? 'on' : 'off'}.png" alt="">Sound ${ambSoundOn(it.mood) ? 'on' : 'off'}</div>`}</div><div class="bar"></div></div>${i < n - 1 ? `<div class="dv" style="left:${px(i) + AG.W}px"></div>` : ''}`).join('')}</div>
    <div class="dots">${items.map((_, i) => `<i data-i="${i}"></i>`).join('')}</div></div>`;
  // long names step down until they fit (UX review item 5)
  for (const t of $$('.amb .ap .t', room)) { const w = t.querySelector('.w'); for (const z of [60, 52, 46, 40]) { w.style.fontSize = z + 'px'; if (w.scrollWidth <= t.clientWidth + 1) break; } if (w.scrollWidth > t.clientWidth + 1) w.style.whiteSpace = 'normal'; }
  const slide = i => {
    const sx = n <= AG.VIS ? Math.floor((1920 - (n * AG.W + (n - 1) * AG.RULE)) / 2) : AG.PEEK + AG.RULE - px(Math.max(0, Math.min(n - AG.VIS, i - Math.floor(AG.VIS / 2))));
    $('#astrip').style.transform = `translateX(${sx}px)`;
    $$('.amb .ap').forEach((p, k) => p.classList.toggle('cur', k === i));
    $$('.amb .dots i').forEach((d, k) => d.classList.toggle('on', k === i));
  };
  slide(idx);
  FH.any = el => { if (cur === 'Ambiance' && el.classList.contains('ap')) slide(+el.dataset.i); };
}
// the sound line on each column follows what was set inside the mood
function ambSoundLabels() {
  const v = clipCache && clipCache.v; if (!v) return;
  for (const p of $$('.amb .ap')) {
    const it = v.list[+p.dataset.i], im = $('img.snd', p); if (!it || !im) continue;
    const on = ambSoundOn(it.mood); im.src = `img/amb/icon-sound-${on ? 'on' : 'off'}.png`; im.nextSibling.textContent = 'Sound ' + (on ? 'on' : 'off');
  }
}
async function openMood(mood) {
  const v = await clips(); const it = v[mood] || v.list.find(x => x.mood === mood) || v.hearth;
  if (it.mood === 'window') { go('Photos'); return; }
  SETPREF0('ambLast', it.mood);
  const snd = it.own ? (/creek|river|water|stream|brook|rain|lake|ocean|wave|falls/i.test(it.title) ? 'rain' : /fire|camp|ember|hearth/i.test(it.title) ? 'fire' : 'night') : SOUND[it.mood];
  const word = it.mood === 'lightsout' ? 'Embers' : snd === 'fire' ? 'Fire' : snd === 'rain' ? (it.mood === 'rain' ? 'Rain' : 'Water') : it.mood === 'fireflies' ? 'Night' : 'Nature';
  const icn = snd === 'fire' ? 'fire' : snd === 'rain' ? 'wave' : 'moon';
  const DIM = [0, .25, .5, .7], TIM = [0, 15, 30, 60, 90];
  const L = openLayer('mood2 ui', `<div class="still" style="background-image:url('${esc(it.still)}')"></div>${it.clip ? '<video playsinline loop preload="auto"></video>' : '<canvas id="mcv" width="1280" height="720" style="position:absolute;inset:0;width:100%;height:100%"></canvas>'}
    <div class="dim"></div><div class="fadeout"></div><div class="msg2" style="display:none"></div><div class="hint">OK shows these · Back leaves</div>
    <div class="mbar"><div class="mi"><i class="ic" style="--m:url(${MI(icn)})"></i></div><div class="mt">${esc(it.title)}</div><div class="ms">${esc(it.sub)}</div><div class="sep"></div>
      <div class="fx mb" data-a="msound" style="left:1148px;width:170px"><i class="ic" style="--m:url(${MI(icn)})"></i><span></span></div>
      <div class="fx mb" data-a="mdim" style="left:1338px;width:150px"><i class="ic" style="--m:url(${MI('sun')})"></i><span></span></div>
      <div class="fx mb" data-a="mtimer" style="left:1508px;width:194px"><i class="ic" style="--m:url(${MI('clock')})"></i><span></span></div></div>`, {
    onKey(e) { if (!L.ui) { if (e.key === 'Escape' || e.key === 'Backspace') return false; L.show(); return true; } L.show(); if (e.key === 'ArrowUp') { L.hide(); return true; } return false; }
  });
  L.mood = it.mood; L.soundOn = ambSoundOn(it.mood); L.dim = +PREF0('ambDim') || 0; L.timer = it.mood === 'lightsout' ? 2 : 0;
  // a mood plays its own clip and sound: the music stops, and comes back when you leave (build 135)
  M.hold();
  const vid = $('video', L.el);
  L.sfx = null;
  if (vid) {
    vid.src = it.clip.url; vid.muted = !L.soundOn;
    vid.addEventListener('playing', () => { $('.still', L.el).style.opacity = 0; });
    vid.addEventListener('error', () => { const m = $('.msg2', L.el); m.style.display = ''; m.textContent = "The clip didn't load from the NAS. The picture stays."; vid.remove(); });
    vid.play().catch(() => { vid.muted = true; vid.play().catch(() => {}); toast('Press OK to start the sound'); });
  }
  // no clip of your own: the drawn scene stands in, with the mood's sound
  if (!vid && snd) { L.sfx = new Audio(`sound/${snd}.mp3`); L.sfx.loop = true; L.sfx.volume = .7; if (L.soundOn) L.sfx.play().catch(() => toast('Press OK to start the sound')); }
  const stopFx = vid ? null : effect(it.mood === 'rain' ? 'rain' : it.mood === 'fireflies' ? 'fireflies' : 'hearth', $('#mcv', L.el));
  L.paintBar = () => {
    $('[data-a=msound] span', L.el).textContent = word + ' ' + (L.soundOn ? 'on' : 'off');
    $('[data-a=mdim] span', L.el).textContent = L.dim ? Math.round(DIM[L.dim] * 100) + '%' : 'Bright';
    $('[data-a=mtimer] span', L.el).textContent = 'Timer ' + (TIM[L.timer] ? TIM[L.timer] + ' min' : 'off');
    $('.dim', L.el).style.opacity = DIM[L.dim];
  };
  L.setSound = on => { L.soundOn = on; SETPREF0('ambSound_' + L.mood, on ? '1' : '0'); if (vid) { vid.muted = !on; if (on) vid.play().catch(() => {}); } if (L.sfx) on ? L.sfx.play().catch(() => {}) : L.sfx.pause(); L.paintBar(); };
  L.cycleDim = () => { L.dim = (L.dim + 1) % DIM.length; SETPREF0('ambDim', L.dim); L.paintBar(); };
  L.setTimer = () => {
    clearTimeout(L.tt); $('.fadeout', L.el).style.opacity = 0;
    if (TIM[L.timer]) L.tt = setTimeout(() => {
      $('.fadeout', L.el).style.opacity = 1; L.hide();
      let k = 1; const f = setInterval(() => { k -= .05; if (vid) vid.volume = Math.max(0, k); if (L.sfx) L.sfx.volume = Math.max(0, k * .7); if (k <= 0) { clearInterval(f); if (vid) vid.pause(); if (L.sfx) L.sfx.pause(); M.held = false; } }, 1000);
    }, TIM[L.timer] * 60000);
  };
  L.cycleTimer = () => { L.timer = (L.timer + 1) % TIM.length; L.paintBar(); L.setTimer(); };
  L.show = () => { L.el.classList.add('ui'); L.ui = true; clearTimeout(L.hideT); L.hideT = setTimeout(() => L.hide(), 6000); if (!focusEl || !L.el.contains(focusEl)) setFocus($('.mb', L.el)); };
  L.hide = () => { L.el.classList.remove('ui'); L.ui = false; clearTimeout(L.hideT); setFocus(null); };
  L.onBack = () => { if (L.ui) { L.hide(); return true; } return false; };
  L.onMouse = () => L.show();
  L.paintBar(); L.setTimer(); L.show();
  L.close = () => { clearTimeout(L.tt); clearTimeout(L.hideT); if (L.sfx) { L.sfx.pause(); L.sfx = null; } if (vid) { vid.pause(); vid.removeAttribute('src'); vid.load(); } if (stopFx) stopFx(); M.release(); ambSoundLabels(); };
}
function effect(mood, cv) {
  if (!cv) return () => {};
  const g = cv.getContext('2d'), W = cv.width, H = cv.height;
  const N = mood === 'rain' ? 110 : mood === 'fireflies' ? 34 : 46;
  const P = Array.from({ length: N }, () => ({ x: Math.random() * W, y: Math.random() * H, v: .4 + Math.random(), s: Math.random() * 6.28, r: 1 + Math.random() * 2 }));
  let run = true, last = 0;
  (function loop(t) {
    if (!run) return; requestAnimationFrame(loop);
    if (t - last < 40) return; last = t;
    g.clearRect(0, 0, W, H);
    for (const p of P) {
      if (mood === 'rain') { g.strokeStyle = 'rgba(190,210,230,.35)'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(p.x, p.y); g.lineTo(p.x - 5, p.y + 26 * p.v); g.stroke(); p.y += 20 * p.v; p.x -= 3 * p.v; if (p.y > H) { p.y = -30; p.x = Math.random() * (W + 80); } }
      else if (mood === 'fireflies') { p.s += .02; p.x += Math.cos(p.s * .7) * .8; p.y += Math.sin(p.s) * .6; const a = (Math.sin(p.s * 1.6) + 1) / 2; const gr = g.createRadialGradient(p.x, p.y, 0, p.x, p.y, 16); gr.addColorStop(0, `rgba(240,210,110,${a})`); gr.addColorStop(1, 'rgba(240,210,110,0)'); g.fillStyle = gr; g.fillRect(p.x - 16, p.y - 16, 32, 32); }
      else { p.y -= .9 * p.v; p.x += Math.sin(p.s += .03) * .6; if (p.y < -10) { p.y = H + 10; p.x = Math.random() * W; } g.fillStyle = `rgba(255,${150 + p.v * 50 | 0},60,${.25 + p.v * .35})`; g.beginPath(); g.arc(p.x, p.y, p.r, 0, 6.28); g.fill(); }
    }
  })(0);
  return () => { run = false; };
}

/* ---------- Player ---------- */
const fmt = s => { s = Math.max(0, s | 0); const h = s / 3600 | 0, m = (s % 3600) / 60 | 0; return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(s % 60).padStart(2, '0'); };
const TV = document.createElement('video');
const CAP = {
  h264: !!TV.canPlayType('video/mp4; codecs="avc1.640028"'),
  hevc: !!TV.canPlayType('video/mp4; codecs="hvc1.1.6.L120.90"'),
  vp9: !!TV.canPlayType('video/webm; codecs="vp9"'),
  av1: !!TV.canPlayType('video/mp4; codecs="av01.0.08M.08"'),
  ac3: !!TV.canPlayType('audio/mp4; codecs="ac-3"'),
  eac3: !!TV.canPlayType('audio/mp4; codecs="ec-3"'),
  hlsNative: !!TV.canPlayType('application/vnd.apple.mpegurl')
};
function canDirect(media) {
  if (!media) return false;
  const v = (media.videoCodec || '').toLowerCase(), a = (media.audioCodec || '').toLowerCase(), c = (media.container || '').toLowerCase();
  if (!['mp4', 'm4v', 'mov', 'mkv', 'webm'].includes(c)) return false;
  const vOk = (v === 'h264' && CAP.h264) || (v === 'hevc' && CAP.hevc) || (v === 'vp9' && CAP.vp9) || (v === 'av1' && CAP.av1);
  const aOk = ['aac', 'mp3', 'opus', 'vorbis', 'flac'].includes(a) || (a === 'ac3' && CAP.ac3) || (a === 'eac3' && CAP.eac3);
  return vOk && aOk && (media.videoProfile || '') !== 'high 10' && (!media.bitrate || media.bitrate <= 12000); // big files go through the converter, which sends a steady 8 Mbps
}
function hlsUrl(id, offsetSec, res, session, kbps, direct, aud) {
  const q = new URLSearchParams({
    path: '/library/metadata/' + id, mediaIndex: 0, partIndex: 0, protocol: 'hls', fastSeek: 1, directPlay: 0, directStream: direct ? 1 : 0,
    subtitleSize: 100, audioBoost: 100, maxVideoBitrate: kbps, videoResolution: res, videoQuality: 100, offset: offsetSec | 0, location: 'lan', session,
    'X-Plex-Product': 'Plex Web', 'X-Plex-Platform': 'Chrome', 'X-Plex-Device': 'Windows', 'X-Plex-Client-Identifier': 'hearth-projector', 'X-Plex-Session-Identifier': session
  });
  if (aud) q.set('audioStreamID', aud);
  return `${PX}/video/:/transcode/universal/start.m3u8?${q}`;
}
const streamsOf = md => { const p = md && md.Media && md.Media[0] && md.Media[0].Part && md.Media[0].Part[0]; return (p && p.Stream) || []; };
const subsOf = md => streamsOf(md).filter(s => s.streamType === 3);
const audOf = md => streamsOf(md).filter(s => s.streamType === 2);
const defAud = md => { const a = audOf(md); return (a.find(s => s.selected) || a[0] || {}).id || 0; };
const defSub = md => (subsOf(md).find(s => s.selected) || {}).id || 0;
const sLabel = s => s.displayTitle || s.extendedDisplayTitle || s.language || 'Unknown';
function parseSubs(t) {
  t = String(t || '').replace(/^﻿/, '').replace(/\r/g, '');
  const tm = x => { const m = /(?:(\d+):)?(\d+):(\d+)[,.](\d+)/.exec(x); return m ? (+(m[1] || 0)) * 3600 + (+m[2]) * 60 + (+m[3]) + (+m[4].padEnd(3, '0').slice(0, 3)) / 1000 : 0; };
  const out = [];
  for (const b of t.split(/\n\n+/)) {
    const ls = b.split('\n'); const i = ls.findIndex(l => l.includes('-->')); if (i < 0) continue;
    const [a, c] = ls[i].split('-->');
    const txt = ls.slice(i + 1).join('\n').replace(/<[^>]+>/g, '').replace(/\{\\[^}]*\}/g, '').trim();
    if (txt) out.push({ s: tm(a), e: tm(c), t: txt });
  }
  return out.sort((x, y) => x.s - y.s);
}
async function playItem(rk, type, o) {
  o = o || {};
  await libs();
  let md;
  if (type === 'show' || type === 'season') {
    const kids = (await pj(`/library/metadata/${rk}/${type === 'show' ? 'allLeaves' : 'children'}`)).Metadata || [];
    md = kids.find(k => !k.viewCount) || kids[0];
    if (!md) { toast('Nothing to play there'); return; }
  } else md = (await pj('/library/metadata/' + rk)).Metadata?.[0];
  if (!md) { toast('Plex has no such item'); return; }
  const media = md.Media?.[0], part = media?.Part?.[0];
  const full = (await pj('/library/metadata/' + md.ratingKey, { includeMarkers: 1, includeChapters: 1 })).Metadata?.[0] || md;
  let nextEp = null;
  if (full.type === 'episode' && full.grandparentRatingKey) { try { const all = (await pj(`/library/metadata/${full.grandparentRatingKey}/allLeaves`)).Metadata || []; const i = all.findIndex(x => x.ratingKey === full.ratingKey); nextEp = i >= 0 ? all[i + 1] || null : null; } catch (e) { /* no next */ } }
  const dur = (full.duration || 0) / 1000;
  let start = o.from != null ? o.from : ((full.viewOffset || 0) / 1000);
  if (dur && (start < 10 || start > dur * .95)) start = 0;
  let mode = o.mode || 'auto';
  if (mode === 'auto') mode = canDirect(media) ? 'direct' : 'hls1080';
  let session = 'hp' + Date.now().toString(36);
  const subL = subsOf(full), audL = audOf(full), audDef = defAud(full);
  let audId = o.audio !== undefined ? o.audio : audDef, subId = o.sub !== undefined ? o.sub : defSub(full);
  if (mode === 'direct' && audId && audId !== audDef) mode = 'hls1080';
  const sub = full.type === 'episode' ? `${full.grandparentTitle} · S${full.parentIndex} E${full.index}` : (full.year || '');
  const L = openLayer('player', `<video id="pv" playsinline poster="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" disablepictureinpicture disableremoteplayback controlslist="nodownload noremoteplayback"></video><div class="hudbox"><div class="stats" id="pst"></div><div class="subs" id="psub"></div><div class="pov show" id="pov"><h3>${esc(full.type === 'episode' ? full.title : full.title)}</h3><div class="sub">${esc(sub)}</div><div class="tm"><span id="pcur">0:00</span><div class="tr"><i id="pbar"></i></div><span id="pdur">${fmt(dur)}</span></div><div class="pbtns"><div class="fx chip" data-a="back">‹ Back</div><div class="fx chip" data-a="pseek" data-d="-10">⏪ 10s</div><div class="fx chip live" data-a="ppp">Play / Pause</div><div class="fx chip" data-a="pseek" data-d="30">30s ⏩</div><div class="fx chip" data-a="pchap">Chapters</div><div class="fx chip" data-a="pcc">CC</div><div class="fx chip" data-a="paud">Audio</div><div class="fx chip" data-a="pstats">Stats</div></div></div><div class="msg" id="pmsg" style="display:none"></div><div class="fx skipb" id="pskip" data-a="pskip" style="display:none">Skip intro ›</div><div class="pausescr" id="ppause"><div class="pk">PAUSED</div><div class="pt">${esc(full.title)}</div><div class="ps">${esc(sub)}</div><div class="pc" id="ppch"></div></div><div class="upnext" id="pup" style="display:none"><div class="uk">UP NEXT</div><div class="ut" id="put"></div><div class="us" id="pus"></div><div class="ub"><div class="fx chip live" data-a="pupplay">Play now</div><div class="fx chip" data-a="pupno">Watch credits</div></div></div></div>`, {
    onKey(e) {
      const v = L.v, k = e.key;
      if (k === ' ' || k === 'Enter' || k === 'MediaPlayPause') { v.paused ? v.play() : v.pause(); L.hud(); return true; }
      if (k === 'ArrowLeft' || k === 'MediaRewind') { L.seek(-10); return true; }
      if (k === 'ArrowRight' || k === 'MediaFastForward') { L.seek(30); return true; }
      if (k === 'ArrowUp' || k === 'ArrowDown') { L.hud(); if (k === 'ArrowDown') { const s = $('#pst', L.el); L.stats = !L.stats; s.style.display = L.stats ? 'block' : 'none'; } return true; }
      if (k === 'i' || k === 'I') { const s = $('#pst', L.el); L.stats = !L.stats; s.style.display = L.stats ? 'block' : 'none'; return true; }
      return false;
    }
  });
  const v = L.v = $('#pv', L.el); L.mode = mode; L.base = 0; L.hls = null; L.stats = !!o.stats;
  $('#pst', L.el).style.display = L.stats ? 'block' : 'none';
  L.hud = () => { const p = $('#pov', L.el); p.classList.add('show'); $('#psub', L.el).classList.add('up'); clearTimeout(L.ht); L.ht = setTimeout(() => { if (!v.paused) { p.classList.remove('show'); $('#psub', L.el).classList.remove('up'); } }, 3500); };
  L.pos = () => L.base + (v.currentTime || 0);
  L.seekTo = t => {
    t = Math.max(0, Math.min(dur - 2, t));
    if (L.mode === 'direct') v.currentTime = t;
    else if (t < L.base || t - L.base > (v.duration || 0) - 2 || Math.abs(t - L.pos()) > 120) load(L.mode, t); // restart the converted stream there
    else v.currentTime = t - L.base;
    L.hud();
  };
  L.seek = d => L.seekTo(L.pos() + d);
  L.onMouse = () => L.hud();
  L.toggle = () => { v.paused ? v.play() : v.pause(); L.hud(); };
  L.toggleStats = () => { const s = $('#pst', L.el); L.stats = !L.stats; s.style.display = L.stats ? 'block' : 'none'; };
  v.addEventListener('click', () => L.toggle());
  $('.tr', L.el).addEventListener('click', e => { const r = e.currentTarget.getBoundingClientRect(); L.seekTo(dur * (e.clientX - r.left) / r.width); });
  const msg = t => { const m = $('#pmsg', L.el); m.style.display = t ? 'flex' : 'none'; m.textContent = t || ''; };
  const load = (m, at) => {
    if (L.hls) { L.hls.destroy(); L.hls = null; }
    L.mode = m;
    if (m === 'direct') {
      L.base = 0; v.src = `${PX}${part.key}`;
      v.addEventListener('loadedmetadata', () => { if (at) v.currentTime = at; }, { once: true });
    } else {
      const res = m === 'hls720' ? '1280x720' : '1920x1080', kb = m === 'hls720' ? 4000 : 8000;
      const url = hlsUrl(full.ratingKey, at, res, session, kb, m !== 'hlsforce', audId !== audDef ? audId : 0);
      L.base = at;
      if (window.Hls && Hls.isSupported()) { L.hls = new Hls({ maxBufferLength: 40 }); L.hls.loadSource(url); L.hls.attachMedia(v); L.hls.on(Hls.Events.ERROR, (ev, d) => { if (d.fatal) msg('Playback failed (' + d.details + ')'); }); }
      else v.src = url;
    }
    v.play().catch(() => {});
  };
  v.addEventListener('error', () => { if (L.mode === 'direct') { toast('Direct play failed, switching to a converted stream'); load('hls1080', L.pos()); } else msg('The projector could not play this one.'); });
  v.addEventListener('waiting', () => { L.hud(); });
  const report = state => { fetch(`${PX}/:/timeline?${new URLSearchParams({ ratingKey: full.ratingKey, key: '/library/metadata/' + full.ratingKey, state, time: (L.pos() * 1000) | 0, duration: (dur * 1000) | 0, 'X-Plex-Client-Identifier': 'hearth-projector' })}`).catch(() => {}); };
  L.iv = setInterval(() => {
    $('#pcur', L.el).textContent = fmt(L.pos()); $('#pbar', L.el).style.width = (dur ? L.pos() / dur * 100 : 0) + '%';
    if (L.stats) { const q = v.getVideoPlaybackQuality ? v.getVideoPlaybackQuality() : {}; const buf = v.buffered.length ? v.buffered.end(v.buffered.length - 1) - v.currentTime : 0; $('#pst', L.el).textContent = `mode      ${L.mode}\nsource    ${media?.container}/${media?.videoCodec}/${media?.audioCodec} ${media?.width}x${media?.height}\nshown     ${v.videoWidth}x${v.videoHeight}\ndropped   ${q.droppedVideoFrames || 0} of ${q.totalVideoFrames || 0}\nbuffered  ${buf.toFixed(1)}s\nposition  ${fmt(L.pos())}`; }
  }, 500);
  // Skip intro, Up next, pause screen (same rules as the Roku player)
  const marks = full.Marker || [], chaps = full.Chapter || [];
  let intro = null, creditsAt = null; L.upDone = false; L.skipDone = false;
  for (const mk of marks) {
    if (mk.type === 'intro' && !intro && mk.endTimeOffset > mk.startTimeOffset + 5000 && mk.endTimeOffset / 1000 < dur * .5) intro = [mk.startTimeOffset / 1000, mk.endTimeOffset / 1000];
    if (mk.type === 'credits' && mk.startTimeOffset / 1000 > dur * .5) creditsAt = Math.max(creditsAt || 0, mk.startTimeOffset / 1000);
  }
  if (creditsAt == null && dur > 120) creditsAt = dur - Math.min(40, dur * .08);
  const chapAt = p => { let c = null; for (const x of chaps) if (x.startTimeOffset / 1000 <= p) c = x; return c; };
  L.step = () => {
    const p = L.pos(), skip = $('#pskip', L.el), up = $('#pup', L.el);
    const inIntro = intro && !L.skipDone && p >= intro[0] - 1 && p < intro[1] - 1 && !v.paused;
    skip.style.display = inIntro ? 'block' : 'none';
    if (inIntro && !focusEl) setFocus(skip);
    if (nextEp && creditsAt != null && !L.upDone && p >= creditsAt && !v.paused) {
      L.upDone = true; L.upLeft = PREF('autoplay', 'on') === 'off' ? 0 : 10;
      $('#put', L.el).textContent = (nextEp.title || 'Next episode'); $('#pus', L.el).textContent = `S${nextEp.parentIndex} E${nextEp.index}`;
      up.style.display = 'block'; setFocus($('#pup .fx', L.el));
      clearInterval(L.upT);
      if (L.upLeft) L.upT = setInterval(() => { L.upLeft--; $('#pus', L.el).textContent = `S${nextEp.parentIndex} E${nextEp.index}  ·  playing in ${L.upLeft}`; if (L.upLeft <= 0) { clearInterval(L.upT); L.goNext(); } }, 1000);
    }
    const pa = $('#ppause', L.el); const showP = v.paused && !L.closing && !$('#pmenu', L.el);
    pa.classList.toggle('on', showP);
    if (showP) { const c = chapAt(p); $('#ppch', L.el).textContent = (c ? (c.tag || 'Chapter') + '  ·  ' : '') + fmt(p) + ' of ' + fmt(dur); }
  };
  L.goNext = () => { clearInterval(L.upT); fetch(`${PX}/:/scrobble?key=${full.ratingKey}&identifier=com.plexapp.plugins.library`).catch(() => {}); closeLayer(); setTimeout(() => playItem(nextEp.ratingKey, 'episode', { from: 0 }).catch(e => toast(e.message)), 350); };
  L.doSkip = () => { L.skipDone = true; $('#pskip', L.el).style.display = 'none'; L.seekTo(intro[1]); setFocus(null); };
  L.pickChap = () => { if (!chaps.length) { toast('No chapters in this one'); return; } L.menu('Chapters', chaps.map((c, i) => ({ label: `${fmt(c.startTimeOffset / 1000)}  ${c.tag || 'Chapter ' + (i + 1)}`, on: chapAt(L.pos()) === c })), i => L.seekTo(chaps[i].startTimeOffset / 1000)); };
  L.stepT = setInterval(L.step, 400);
  L.rt = setInterval(() => report(v.paused ? 'paused' : 'playing'), 10000);
  v.addEventListener('ended', () => { fetch(`${PX}/:/scrobble?key=${full.ratingKey}&identifier=com.plexapp.plugins.library`).catch(() => {}); closeLayer(); });
  L.cues = [];
  L.setSub = async id => {
    subId = id; L.cues = []; $('#psub', L.el).textContent = '';
    if (!id) return;
    const st = subL.find(x => x.id === id); if (!st) return;
    try {
      const base = st.key || '/library/streams/' + id;
      let r = await fetch(`${PX}${base}${base.includes('?') ? '&' : '?'}format=srt&encoding=utf-8`); let t = r.ok ? await r.text() : '';
      if (!t || !t.includes('-->')) { r = await fetch(`${PX}${base}.srt`); t = r.ok ? await r.text() : ''; }
      L.cues = parseSubs(t);
      if (!L.cues.length) toast('Those subtitles could not be read');
    } catch (e) { toast('Subtitles did not load'); }
  };
  L.subTick = setInterval(() => { const el = $('#psub', L.el); if (!el) return; const p = L.pos(); const c = L.cues.find(x => p >= x.s && p <= x.e); const t = c ? c.t : ''; if (el.textContent !== t) el.textContent = t; }, 200);
  L.menu = (title, opts, cb) => {
    L.closeMenu();
    const hb = $('.hudbox', L.el); hb.insertAdjacentHTML('beforeend', `<div class="pmenu" id="pmenu"><h4>${esc(title)}</h4>${opts.map((x, i) => `<div class="fx chip ${x.on ? 'live' : ''}" data-a="pmopt" data-i="${i}">${esc(x.label)}</div>`).join('')}</div>`);
    L.menuCb = cb; clearTimeout(L.ht); $('#pov', L.el).classList.add('show'); $('#psub', L.el).classList.add('up');
    setFocus($$('.fx', $('#pmenu', L.el)).find(e => e.classList.contains('live')) || $('#pmenu .fx', L.el));
  };
  L.closeMenu = () => { const m = $('#pmenu', L.el); if (m) { m.remove(); L.menuCb = null; return true; } return false; };
  L.onBack = () => { if (L.closeMenu()) { setFocus($('.pbtns .fx', L.el)); L.hud(); return true; } return false; };
  L.pickSub = () => L.menu('Subtitles', [{ label: 'Off', on: !subId }].concat(subL.map(x => ({ label: sLabel(x), on: x.id === subId }))), i => L.setSub(i ? subL[i - 1].id : 0));
  L.pickAud = () => {
    if (audL.length < 2) { toast('Only one audio track'); return; }
    L.menu('Audio', audL.map(x => ({ label: sLabel(x), on: x.id === audId })), i => {
      const old = session; audId = audL[i].id; session = 'hp' + Date.now().toString(36);
      fetch(`${PX}/video/:/transcode/universal/stop?session=${old}`).catch(() => {});
      load(L.mode === 'direct' ? 'hls1080' : L.mode, L.pos());
    });
  };
  L.setSub(subId);
  aud.pause(); M.playing = false; M.paint();
  L.close = () => { L.closing = true; clearInterval(L.stepT); clearInterval(L.upT); clearInterval(L.iv); clearInterval(L.rt); clearInterval(L.subTick); clearTimeout(L.ht); report('stopped'); if (L.hls) L.hls.destroy(); v.pause(); v.removeAttribute('src'); v.load(); if (L.mode !== 'direct') fetch(`${PX}/video/:/transcode/universal/stop?session=${session}`).catch(() => {}); };
  load(mode, mode === 'direct' ? start : start);
  L.hud(); setFocus(null);
}

/* ---------- Movies and Shows (same layout as the Roku: info strip, tabs, poster grid; Ledger details) ---------- */
const ic = (n, c) => `<i class="ic ${c || ''}" style="--m:url(img/icons/${n}.png)"></i>`;
const mins = ms => ms ? Math.max(1, Math.round(ms / 60000)) : 0;
const runtime = ms => { const m = mins(ms); return m >= 60 ? `${m / 60 | 0} h ${m % 60} m` : `${m} m`; };
const LS = {};
let LR = null, LRInfo = null, LRBack = null;
const SORTS = [['A to Z', 'titleSort'], ['Recently added', 'addedAt:desc'], ['Newest first', 'originallyAvailableAt:desc'], ['Top rated', 'audienceRating:desc']];
const LTABS = ['Continue', 'New', 'Unwatched', 'A to Z', 'Genres'];
const LETTERS = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const letterOf = it => { const c = ((it.titleSort || it.title || '')[0] || '#').toUpperCase(); const p = LETTERS.indexOf(c); return p < 1 ? 0 : p; };
const posterOf = md => md.type === 'episode' ? (md.grandparentThumb || md.thumb) : md.thumb;
const titleOf = md => md.type === 'episode' ? (md.grandparentTitle || md.title) : md.title;

async function roomLib(room, tok, type) {
  await libs();
  const lib = LIBS.find(d => d.type === type && !blocked.has(String(d.key)));
  if (!lib) { room.innerHTML = `<div class="msg">No ${type === 'movie' ? 'movies' : 'shows'} library in Plex yet.</div>`; return; }
  const S = LS[type] || (LS[type] = { tab: 0, sort: 0, unw: false, genre: null, decade: '', cache: {} });
  S.genreOpen = null;
  room.innerHTML = `<div class="lr"><div class="le" id="le"></div><div class="lt" id="lt"></div><div class="lo" id="lo"></div><div class="lb" id="lb"></div>
    <div class="la" id="la"></div><div class="lfade"></div>
    <div class="ltabs" id="ltabs">${LTABS.map((n, i) => `<div class="fx ltab" data-a="ltab" data-i="${i}">${n}</div>`).join('')}</div>
    <div class="lcount" id="lc"></div><div class="lchips" id="lchips"></div><div class="lletters" id="lletters"></div>
    <div class="gclip scroll" id="lg"><div class="gg" id="gg"></div></div><div class="lempty" id="lempty"></div></div>`;
  const R = LR = { type, lib, S, items: [], cur: null, tok };
  const gg = $('#gg', room), lg = $('#lg', room);
  const az = () => LTABS[S.tab] === 'A to Z' && !S.genreOpen;
  const lettersOn = () => az() && S.sort === 0;

  R.paintTabs = () => $$('.ltab', room).forEach((t, i) => t.classList.toggle('cur', i === S.tab));
  R.paintChips = () => {
    const box = $('#lchips', room); box.style.display = az() ? 'flex' : 'none';
    if (!az()) { $('#lletters', room).style.display = 'none'; return; }
    const spec = [[SORTS[S.sort][0], 'home-sort', S.sort > 0, 'sort'], ['Unwatched', 'home-check', S.unw, 'unw'], [S.genre ? S.genre.title : 'Genre', 'home-filter', !!S.genre, 'genre'], [S.decade ? S.decade + 's' : 'Decade', 'home-cal', !!S.decade, 'decade'], ['Clear', 'home-x', false, 'clear']];
    box.innerHTML = spec.map(([t, i, on, k]) => `<div class="fx pill sm ${on ? 'act' : ''}" data-a="lchip" data-k="${k}">${ic(i)}<span>${esc(t)}</span></div>`).join('');
    const lt = $('#lletters', room); lt.style.display = lettersOn() ? 'flex' : 'none';
    lg.style.top = lettersOn() ? '388px' : '330px';
    if (lettersOn()) lt.innerHTML = [...LETTERS].map((c, i) => `<div class="fx lch ${R.firstAt && R.firstAt[i] >= 0 ? '' : 'dim'}" data-a="lletter" data-i="${i}">${c}</div>`).join('');
    else lg.style.top = '330px';
  };
  R.info = i => {
    const it = R.items[i]; if (!it) return; R.cur = it;
    if (it.genreName) { $('#le', room).textContent = 'GENRE'; $('#lt', room).textContent = it.genreName.toUpperCase(); $('#lo', room).textContent = `OK shows everything in ${it.genreName}.`; $('#la', room).style.backgroundImage = ''; $('#lb', room).innerHTML = ''; return; }
    const bits = [];
    if (it.type === 'episode') bits.push(`S${it.parentIndex} E${it.index}`);
    if (it.year) bits.push(it.year);
    if (it.duration && it.type !== 'show') bits.push(runtime(it.duration).toUpperCase());
    if (it.contentRating) bits.push(it.contentRating);
    $('#le', room).textContent = bits.join(' · ').toUpperCase();
    $('#lt', room).textContent = titleOf(it).toUpperCase();
    $('#lo', room).textContent = it.summary || '';
    const u = img(it.art || it.grandparentArt || it.thumb, 356, 200);
    $('#la', room).style.backgroundImage = u ? `url("${u}")` : '';
    const b = [];
    if (it.type === 'show') b.push(['detail', 'Open', 'home-play']);
    else { b.push([it.viewOffset ? 'resume' : 'play', it.viewOffset ? 'Resume' : 'Play', 'home-play']); b.push(['detail', 'Details', 'home-info']); }
    $('#lb', room).innerHTML = b.map(([a, t, i]) => `<div class="fx pill" data-a="lbtn" data-b="${a}">${ic(i)}<span>${t}</span></div>`).join('');
  };
  LRInfo = i => { if (LR === R) R.info(i); };
  R.draw = items => {
    R.items = items; R.firstAt = new Array(27).fill(-1);
    if (lettersOn()) items.forEach((it, i) => { const k = letterOf(it); if (R.firstAt[k] < 0) R.firstAt[k] = i; });
    gg.innerHTML = items.map((it, i) => it.genreName
      ? `<div class="fx pc2 gen" data-a="open" data-i="${i}"><div class="ph">${esc(it.genreName)}</div></div>`
      : `<div class="fx pc2" data-a="open" data-i="${i}"><div class="im" data-bg="${img(posterOf(it), 180, 270)}"></div><div class="ph">${esc(titleOf(it))}</div>${it.viewOffset && it.duration ? `<div class="braid"><i style="width:${Math.min(100, it.viewOffset / it.duration * 100)}%"></i></div>` : ''}</div>`).join('');
    lg.scrollTop = 0;
    $('#lempty', room).textContent = items.length ? '' : (S.genreOpen ? `Nothing in ${S.genreOpen}.` : 'Nothing here yet.');
    $('#lc', room).textContent = items.length ? `${items.length} ${LTABS[S.tab] === 'Genres' && !S.genreOpen ? 'genres' : 'titles'}` : '';
    R.paintChips();
    if (items.length) R.info(0); else { $('#le', room).textContent = ''; $('#lt', room).textContent = ''; $('#lo', room).textContent = ''; $('#lb', room).innerHTML = ''; $('#la', room).style.backgroundImage = ''; }
  };
  const sec = `/library/sections/${lib.key}`;
  const getAll = async p => ((await pj(sec + '/all', Object.assign({ 'X-Plex-Container-Start': 0 }, p))).Metadata || []).filter(m => !hiddenItem(m));
  R.load = async () => {
    R.paintTabs(); R.paintChips();
    const name = LTABS[S.tab];
    const key = name === 'A to Z' ? `az|${S.sort}|${S.unw}|${S.genre && S.genre.key}|${S.decade}` : name;
    if (S.cache[key]) { R.draw(S.cache[key]); return; }
    R.items = []; gg.innerHTML = ''; $('#lempty', room).textContent = 'Loading…'; $('#lc', room).textContent = '';
    let items = [];
    try {
      if (name === 'Continue') items = ((await pj(sec + '/onDeck', { 'X-Plex-Container-Size': 45 })).Metadata || []).filter(m => !hiddenItem(m));
      else if (name === 'New') items = await getAll({ sort: 'addedAt:desc', 'X-Plex-Container-Size': 45 });
      else if (name === 'Unwatched') { items = await getAll({ unwatched: 1, 'X-Plex-Container-Size': 400 }); for (let i = items.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0; [items[i], items[j]] = [items[j], items[i]]; } items = items.slice(0, 90); }
      else if (name === 'A to Z') { const p = { sort: SORTS[S.sort][1], 'X-Plex-Container-Size': 3000 }; if (S.unw) p.unwatched = 1; if (S.genre) p.genre = S.genre.key; if (S.decade) p.decade = S.decade; items = await getAll(p); }
      else items = ((await pj(sec + '/genre')).Directory || []).map(g => ({ genreName: g.title, genreKey: g.key }));
    } catch (e) { if (R.tok === renderTok) $('#lempty', room).textContent = "Can't reach your library: " + e.message; return; }
    if (R !== LR || R.tok !== renderTok) return;
    S.cache[key] = items; R.draw(items);
  };
  R.openGenre = async g => {
    S.genreOpen = g.genreName; $('#lempty', room).textContent = 'Loading ' + g.genreName + '…'; gg.innerHTML = '';
    R.paintChips();
    try { const items = await getAll({ genre: g.genreKey, sort: 'titleSort', 'X-Plex-Container-Size': 500 }); R.draw(items); $('#lc', room).textContent = `${g.genreName} · ${items.length}`; } catch (e) { $('#lempty', room).textContent = e.message; }
  };
  LRBack = () => { if (S.genreOpen) { S.genreOpen = null; R.load().then(() => setFocus($$('.pc2', room)[0] || null)); return true; } return false; };
  R.pickList = (title, labels, cb) => pickSheet(title, labels, cb);
  await R.load();
}

function openItem(i) {
  const it = LR.items[i]; if (!it) return;
  if (it.genreName) return LR.openGenre(it);
  if (it.type === 'episode') return openDetail(it.grandparentRatingKey, 'show', { want: { season: it.parentIndex, id: it.ratingKey } }).catch(e => toast(e.message));
  return openDetail(it.ratingKey, it.type).catch(e => toast(e.message));
}

const seasonLabel = s => s.index === 0 ? 'SPECIALS' : 'SEASON ' + s.index;
const hhmm = ms => new Date(Date.now() + ms).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
async function openDetail(id, type, opt) {
  opt = opt || {};
  const L = openLayer('page det', '<div class="scroll dscroll" id="dsc"><div class="dpage" id="dp"><div class="msg" style="position:relative;height:500px">Loading…</div></div></div>');
  L.id = id; L.want = opt.want || null; L.btn = 0;
  L.load = async () => {
    const md = (await pj('/library/metadata/' + L.id, { includeOnDeck: 1, includeExtras: 1, includeRelated: 1 })).Metadata?.[0];
    if (!md) throw new Error('Plex has no such title');
    L.md = md; L.isShow = md.type === 'show';
    L.extras = (md.Extras && md.Extras.Metadata) || [];
    L.target = L.isShow ? (md.OnDeck && md.OnDeck.Metadata && md.OnDeck.Metadata[0]) || null : md;
    if (L.isShow) {
      const seasons = ((await pj(`/library/metadata/${md.ratingKey}/children`)).Metadata || []);
      L.seasons = seasons.filter(s => s.index > 0).concat(seasons.filter(s => s.index === 0));
      const want = L.want ? L.want.season : (L.target ? L.target.parentIndex : null);
      let pick = L.seasons.findIndex(s => s.index === want);
      if (pick < 0) pick = L.seasons.findIndex(s => s.index > 0 && (s.viewedLeafCount || 0) < (s.leafCount || 0));
      L.sIdx = pick < 0 ? 0 : pick;
      await L.loadEps();
    } else L.eps = [];
    L.full = L.isShow ? (L.target ? ((await pj('/library/metadata/' + L.target.ratingKey)).Metadata?.[0] || L.target) : null) : md;
    L.render();
    $$('.ep', L.el).length; L.focusInit();
    pj(`/library/metadata/${md.ratingKey}/similar`).then(mc => L.below('More like this', 'heart', 'tall', (mc.Metadata || []).filter(x => !hiddenItem(x)))).catch(() => {});
  };
  L.loadEps = async () => {
    const s = L.seasons[L.sIdx]; if (!s) { L.eps = []; return; }
    L.eps = ((await pj(`/library/metadata/${s.ratingKey}/children`)).Metadata || []).filter(e => !hiddenItem(e));
    let sel = -1;
    if (L.want) { sel = L.eps.findIndex(e => e.ratingKey === L.want.id); L.want = null; }
    if (sel < 0 && L.target) sel = L.eps.findIndex(e => e.ratingKey === L.target.ratingKey);
    if (sel < 0) sel = L.eps.findIndex(e => !e.viewCount);
    L.epSel = Math.max(0, sel);
    if (!L.target && L.eps[L.epSel]) { L.target = L.eps[L.epSel]; }
  };
  L.tags = () => {
    const out = []; const md = L.md;
    const ratings = (md.Rating || []);
    for (const r of ratings) { const k = /imdb/.test(r.image || '') ? 'IMDb' : /rottentomatoes/.test(r.image || '') ? (/audience/.test(r.image) ? 'Audience' : 'Tomatometer') : (r.type === 'audience' ? 'Audience' : 'Critics'); out.push(`<span class="rt"><em>${k.toUpperCase()}</em><b>${esc(/rotten/.test(r.image || '') ? Math.round(r.value * 10) + '%' : r.value)}</b></span>`); }
    if (!ratings.length && md.audienceRating) out.push(`<span class="rt"><em>AUDIENCE</em><b>${md.audienceRating}</b></span>`);
    const tf = L.full, media = tf && tf.Media && tf.Media[0];
    if (media) {
      const part = media.Part && media.Part[0], st = (part && part.Stream) || [];
      const tag = (t, k, i) => `<span class="tg ${k || ''}">${i ? ic(i) : ''}${esc(t)}</span>`;
      const res = { '4k': '4K', '1080': '1080p', '720': '720p', '480': '480p', sd: 'SD' }[media.videoResolution] || (media.videoResolution ? media.videoResolution + 'p' : '');
      if (res) out.push(tag(res, 'gold'));
      const vc = (media.videoCodec || '').toLowerCase(); out.push(tag({ h264: 'H.264', hevc: 'HEVC', av1: 'AV1', vc1: 'VC-1', mpeg4: 'MPEG-4' }[vc] || vc.toUpperCase()));
      const v = st.find(s => s.streamType === 1);
      if (v && /dolby vision|dovi/i.test(v.displayTitle || '')) out.push(tag('Dolby Vision')); else if (v && /hdr/i.test(v.displayTitle || '')) out.push(tag('HDR'));
      const au = st.find(s => s.streamType === 2 && s.selected) || st.find(s => s.streamType === 2);
      if (au) out.push(tag(`${(au.codec || '').toUpperCase().replace('EAC3', 'DD+').replace('AC3', 'DD')} ${au.channels === 6 ? '5.1' : au.channels === 8 ? '7.1' : au.channels === 2 ? '2.0' : (au.channels || '')}`.trim()));
      const subs = st.filter(s => s.streamType === 3);
      const en = subs.some(s => (s.languageCode || '').startsWith('en'));
      out.push(tag(en ? 'English subs' : (subs.length ? subs.length + ' subs' : 'No subs'), en ? '' : 'warn', en ? '' : 'd-ccx'));
      if (canDirect(media)) out.push(`<span class="tg green">${ic('d-leaf')}Plays directly</span>`);
      else if (vc === 'hevc') out.push(tag('Will convert to 720p', '', 'd-wand')); else out.push(tag('Converts to play', '', 'd-wand'));
    }
    return out.join('');
  };
  L.render = () => {
    const md = L.md, tgt = L.target;
    const kick = L.isShow ? `SHOWS  ›  ${md.title.toUpperCase()}${tgt && tgt.type === 'episode' ? `  ›  ${tgt.viewOffset ? 'CONTINUE' : 'NEXT UP'} S${tgt.parentIndex} E${tgt.index}` : ''}` : `MOVIES  ›  ${md.title.toUpperCase()}${md.studio ? '  ›  ' + md.studio.toUpperCase() : ''}`;
    const parts = [md.year, md.contentRating, (md.Genre || []).slice(0, 2).map(g => g.tag).join(', ')];
    if (L.isShow && md.childCount) parts.push(md.childCount === 1 ? '1 season' : md.childCount + ' seasons');
    if (tgt && tgt.duration) { parts.push(runtime(tgt.duration)); parts.push('ends ' + hhmm(tgt.duration - (tgt.viewOffset || 0))); }
    const acts = [];
    if (tgt) {
      const resume = tgt.viewOffset > 0 && !tgt.viewCount; const ep = L.isShow && tgt.type === 'episode' ? ` S${tgt.parentIndex} E${tgt.index}` : '';
      if (resume) { acts.push(['play', 'Resume' + ep, 'resume']); acts.push(['restart', 'From start', 'restart']); } else acts.push(['play', 'Play' + ep, 'restart']);
    }
    const trailer = L.extras.find(x => x.subtype === 'trailer'); if (trailer) acts.push(['film', 'Trailer', 'trailer:' + trailer.ratingKey]);
    if (L.full) {
      const sl = subsOf(L.full), al = audOf(L.full);
      const sid = L.subSel !== undefined ? L.subSel : defSub(L.full), aid = L.audSel !== undefined ? L.audSel : defAud(L.full);
      const sst = sl.find(x => x.id === sid), ast = al.find(x => x.id === aid);
      acts.push(['cc', sst ? (sst.language || 'Subtitles') : (sl.length ? 'Subs off' : 'No subs'), 'cc']);
      if (al.length > 1) acts.push(['audio', ast ? (ast.language || 'Audio') : 'Audio', 'audio']);
    }
    const allW = L.isShow ? !((md.leafCount || 0) - (md.viewedLeafCount || 0)) : !!md.viewCount;
    acts.push(allW ? ['checkc', 'Watched', 'unwatch'] : ['eye', 'Mark watched', 'watch']);
    acts.push(['more', 'More', 'more']);
    L.acts = acts;
    const people = (md.Role || []).slice(0, 24);
    $('#dp', L.el).innerHTML = `<div class="dhead"><div class="dpanel"></div><div class="dposter" style="background-image:url('${img(md.thumb, 200, 300)}')"></div>
      <div class="dtxt"><div class="dk">${ic('d-back')}<span>${esc(kick)}</span></div><div class="dtitle">${esc(md.title.toUpperCase())}</div><div class="dmeta">${esc(parts.filter(Boolean).join('  ·  '))}</div>
      <div class="dtags">${L.tags()}</div><div class="dov">${esc(md.summary || '')}</div>
      <div class="dacts">${acts.map(([i, t, a]) => `<div class="fx ib" data-a="dact" data-d="${a}">${ic('d-' + i)}${t ? `<span>${esc(t)}</span>` : ''}</div>`).join('')}</div></div></div>
      ${L.isShow ? `<div class="dtabs" id="dtabs"></div><div id="deps"></div>` : ''}<div id="dbelow"></div>`;
    if (L.isShow) { L.drawTabs(); L.drawEps(); }
    if (people.length) L.below('Cast & crew', 'people', 'person', people);
    if (L.extras.length) L.below('Extras', 'film', 'wide', L.extras);
  };
  L.drawTabs = () => {
    $('#dtabs', L.el).innerHTML = `<div class="stabs">${L.seasons.map((s, i) => { const done = s.leafCount && s.viewedLeafCount >= s.leafCount; return `<div class="fx stab ${i === L.sIdx ? 'cur' : ''} ${done ? 'done' : ''}" data-a="season" data-i="${i}">${i === L.sIdx || s.index === 0 ? esc(seasonLabel(s)) : s.index}${done ? ic('d-check', 'tick') : ''}</div>`; }).join('')}</div><div class="schips">${L.eps.length ? `<div class="fx ib" data-a="shuffle">${ic('d-shuffle')}<span>Shuffle</span></div>` : ''}</div>`;
  };
  L.drawEps = () => {
    $('#deps', L.el).innerHTML = L.eps.map((e, i) => {
      const meta = [e.duration ? runtime(e.duration) : '', e.originallyAvailableAt ? new Date(e.originallyAvailableAt + 'T12:00:00').toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' }) : '', e.viewOffset && !e.viewCount && e.duration ? mins(e.duration - e.viewOffset) + ' min left' : ''].filter(Boolean).join('  ·  ');
      const m0 = e.Media && e.Media[0], conv = m0 && (m0.videoCodec || '').toLowerCase() === 'hevc' && !CAP.hevc;
      return `<div class="fx ep" data-a="ep" data-i="${i}"><div class="en">${e.index || ''}</div><div class="eth" data-bg="${img(e.thumb, 184, 104)}">${e.viewOffset && e.duration ? `<div class="braid"><i style="width:${Math.min(100, e.viewOffset / e.duration * 100)}%"></i></div>` : ''}</div>
        <div class="etx"><div class="et">${esc(e.title)}</div><div class="es">${esc(e.summary || '')}</div><div class="em">${esc(meta)}</div></div><div class="est">${conv ? '<span class="tg">' + ic('d-wand') + 'To 720p</span>' : ''}${e.viewCount ? ic('d-checkc', 'ok') : ''}</div></div>`;
    }).join('') || '<div class="lempty" style="position:relative;padding:30px 0">No episodes in this season yet.</div>';
  };
  L.below = (title, icon, kind, list) => {
    const box = $('#dbelow', L.el); if (!box || !list.length) return;
    const card = x => {
      if (kind === 'person') return `<div class="fx pcard"><div class="pim" data-bg="${img(x.thumb, 160, 240)}"><div class="ph">${esc((x.tag || '').split(' ').map(w => w[0]).join('').slice(0, 2))}</div></div><div class="t">${esc(x.tag)}</div><div class="s">${esc(x.role || '')}</div></div>`;
      if (kind === 'wide') return `<div class="fx card" data-a="clip" data-k="${x.ratingKey}"><div class="img" data-bg="${img(x.thumb, 320, 180)}"><div class="ph">${esc(x.title)}</div></div><div class="t">${esc(x.title)}</div><div class="s">${esc(x.subtype || '')}</div></div>`;
      return `<div class="fx pc2 tallc" data-a="detail" data-k="${x.ratingKey}" data-t="${x.type}"><div class="im" data-bg="${img(x.thumb, 200, 300)}"></div><div class="ph">${esc(x.title)}</div></div>`;
    };
    box.insertAdjacentHTML('beforeend', `<div class="hd">${ic('d-' + icon, 'hic')}${esc(title)}<small>${list.length}</small></div><div class="row">${list.map(card).join('')}</div>`);
  };
  L.focusInit = () => { const b = $$('.ib', L.el)[0]; if (L.want === null && L.isShow && L.eps.length && opt.want) setFocus($$('.ep', L.el)[L.epSel]); else setFocus(b || null); };
  L.onShown = () => { const keep = L.eps && L.eps[L.epSel]; if (keep) L.want = { season: L.seasons[L.sIdx].index, id: keep.ratingKey }; L.load().catch(() => {}); };
  await L.load();
  return L;
}
function playTarget(L, from, tgt) {
  const t = tgt || L.target; if (!t) { toast('Nothing to play yet'); return; }
  const o = from != null ? { from } : {};
  if (!tgt) { if (L.subSel !== undefined) o.sub = L.subSel; if (L.audSel !== undefined) o.audio = L.audSel; }
  playItem(t.ratingKey, t.type, o).catch(e => toast(e.message));
}

/* ---------- Search (Hearth keyboard on the left, matches on the right) ---------- */
let SR = null, vocab = null, vocabP = null, reqSearch = '';
const normT = s => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
function loadVocab() {
  if (vocab || vocabP) return vocabP;
  vocabP = libs().then(async () => {
    const out = [];
    for (const d of LIBS) {
      if (blocked.has(String(d.key)) || !['movie', 'show', 'artist'].includes(d.type)) continue;
      try { const mc = await pj(`/library/sections/${d.key}/all`, { 'X-Plex-Container-Size': 6000, 'X-Plex-Container-Start': 0 }); for (const m of (mc.Metadata || [])) out.push(m.title); } catch (e) { /* skip */ }
    }
    vocab = [...new Set(out)].map(t => [t, normT(t)]);
    if (SR) SR.vocabReady();
  }).catch(() => { vocab = []; });
  return vocabP;
}
const recentSearches = () => { try { return JSON.parse(localStorage.getItem('hearth.recent') || '[]'); } catch (e) { return []; } };
const rememberSearch = t => { t = (t || '').trim(); if (!t) return; try { localStorage.setItem('hearth.recent', JSON.stringify([t].concat(recentSearches().filter(x => x.toLowerCase() !== t.toLowerCase())).slice(0, 5))); } catch (e) { /* ignore */ } };
const KEYCH = 'abcdefghijklmnopqrstuvwxyz1234567890';

function roomSearch(room, tok) {
  room.innerHTML = `<div class="sr"><div class="seb">SEARCH</div>
    <div class="skb"><div class="sdisp" id="sd"></div><div class="srule"></div><div class="schips" id="sc"></div>
      <div class="skeys" id="sk">${[...KEYCH].map(c => `<div class="fx key" data-a="skey" data-c="${c}">${c.toUpperCase()}</div>`).join('')}
        <div class="fx key wide" data-a="skey" data-c=" ">${ic('d-plus', 'k')}<span>Space</span></div><div class="fx key wide" data-a="skey" data-c="⌫">${ic('home-x', 'k')}<span>Delete</span></div><div class="fx key wide" data-a="skey" data-c="⌧">${ic('home-x', 'k')}<span>Clear</span></div></div></div>
    <div class="sres" id="srl"></div><div class="shint" id="sh"></div>
    <div class="sview scroll" id="sv"><div id="slist"></div></div></div>`;
  const S = SR = { text: '', seq: 0, rows: [], timer: null, tok, term: '' };
  const disp = $('#sd', room), chips = $('#sc', room), list = $('#slist', room), label = $('#srl', room), hint = $('#sh', room);
  S.paintKeyboard = () => {
    disp.textContent = S.text || ''; disp.classList.toggle('ph', !S.text);
    if (!S.text) disp.textContent = 'Type a title';
    const q = normT(S.text);
    let sug = [];
    if (vocab && q) {
      sug = vocab.filter(([t, n]) => n.startsWith(q));
      if (sug.length < 3) sug = sug.concat(vocab.filter(([t, n]) => !n.startsWith(q) && n.includes(q)));
      sug = sug.sort((a, b) => a[1].length - b[1].length).slice(0, 3).map(x => x[0]);
    }
    chips.innerHTML = sug.map(t => `<div class="fx schip" data-a="spick" data-t="${esc(t)}">${esc(t)}</div>`).join('');
    $$('#sk .key', room).forEach(k => {
      const c = k.dataset.c;
      let dim = false;
      if (vocab && vocab.length && c.length === 1 && c !== ' ') dim = !vocab.some(([t, n]) => n.startsWith(q + c));
      k.classList.toggle('dim', dim);
    });
  };
  S.vocabReady = () => S.paintKeyboard();
  S.set = t => { S.text = t.slice(0, 40); S.paintKeyboard(); clearTimeout(S.timer); S.timer = setTimeout(S.run, 350); };
  S.key = e => {
    if (e.key.length === 1 && /[a-z0-9]/i.test(e.key) && !e.ctrlKey && !e.metaKey) { S.set(S.text + e.key.toLowerCase()); return true; }
    if (e.key === 'Backspace' && S.text) { S.set(S.text.slice(0, -1)); return true; }
    return false;
  };
  const sub = (it, withKind) => {
    const kinds = { movie: 'Movie', show: 'Show', episode: 'Episode', artist: 'Artist', album: 'Album', track: 'Song' };
    const p = [];
    if (withKind && kinds[it.type]) p.push(kinds[it.type]);
    if (it.type === 'episode') { p.push(it.grandparentTitle); p.push(`S${it.parentIndex} E${it.index}`); }
    else if (it.type === 'album' || it.type === 'track') { p.push(it.type === 'album' ? it.parentTitle : it.grandparentTitle); if (it.type === 'track' && it.parentTitle) p.push(it.parentTitle); if (it.type === 'album' && it.year) p.push(it.year); }
    else if (it.type === 'movie' || it.type === 'show') { if (it.year) p.push(it.year); if (it.type === 'show' && it.childCount) p.push(it.childCount === 1 ? '1 season' : it.childCount + ' seasons'); }
    return p.filter(Boolean).join('  ·  ');
  };
  const HEADS = [['movie', 'MOVIES', 'film'], ['show', 'SHOWS', 'tv'], ['episode', 'EPISODES', 'episode'], ['artist', 'ARTISTS', 'artist'], ['album', 'ALBUMS', 'album'], ['track', 'SONGS', 'song']];
  const rank = (a, q) => a.sort((x, y) => { const f = t => { t = (t.title || '').toLowerCase(); return t === q ? 0 : t.startsWith(q) ? 1 : t.includes(q) ? 2 : 3; }; return f(x) - f(y); });
  const rowHTML = (it, i, withKind) => {
    const sq = ['artist', 'album', 'track'].includes(it.type);
    const pic = sq ? it.thumb : (it.type === 'episode' ? (it.thumb || it.grandparentThumb) : (it.art || it.thumb));
    const req = it.type === 'show' ? '<div class="fx pill sm rq" data-a="srq" data-i="' + i + '">' + ic('d-plus') + '<span>Request</span></div>' : '';
    return `<div class="fx srow" data-a="sopen" data-i="${i}"><div class="sth ${sq ? 'sq' : ''}" data-bg="${img(pic, sq ? 144 : 256, sq ? 144 : 144)}"></div><div class="stx"><div class="st">${esc(it.title)}</div>${sub(it, withKind) ? `<div class="ss">${esc(sub(it, withKind))}</div>` : ''}</div>${req}</div>`;
  };
  const head = (t, i) => `<div class="shd">${ic('d-' + (i === 'search' ? 'info' : 'film'), 'hi')}<span>${t}</span><b></b></div>`;
  const idle = () => {
    S.rows = []; label.textContent = ''; hint.textContent = ''; const rs = recentSearches();
    list.innerHTML = rs.length ? `<div class="shd"><span>RECENT SEARCHES</span><b></b></div>` + rs.map(t => `<div class="fx srow rec" data-a="srecent" data-t="${esc(t)}"><div class="stx"><div class="st">${esc(t)}</div></div></div>`).join('') : '';
    hint.textContent = rs.length ? '' : 'Type a title. Matches appear as you go.';
  };
  S.run = async () => {
    const term = S.text.trim(); const my = ++S.seq;
    if (!term) { idle(); return; }
    S.term = term;
    if (!S.rows.length) { list.innerHTML = ''; label.textContent = ''; hint.textContent = 'Looking…'; }
    const find = async q => { const mc = await pj('/hubs/search', { query: q, limit: 20, includeCollections: 0 }); const out = []; for (const h of (mc.Hub || [])) for (const m of (h.Metadata || [])) if (!hiddenItem(m)) out.push(m); return out; };
    let found = [], tried = term;
    try {
      found = await find(term);
      if (!found.length && term.length >= 3) { tried = term.slice(0, -1).trim(); found = await find(tried); }
    } catch (e) { if (my === S.seq) { list.innerHTML = ''; label.textContent = ''; hint.textContent = "Couldn't reach Plex. Check the server is on, then type again."; } return; }
    if (my !== S.seq || R_not_here()) return;
    const q = tried.toLowerCase(); const rows = []; let html = '';
    const flat = tried !== term;
    if (flat) {
      label.textContent = `NOTHING FOR "${term.toUpperCase()}"`;
      if (found.length) { html += `<div class="shd"><span>SHOWING "${esc(tried.toUpperCase())}"</span><b></b></div>`; for (const it of rank(found, q).slice(0, 12)) { rows.push(it); html += rowHTML(it, rows.length - 1, true); } }
    } else {
      for (const [t, h] of HEADS) {
        const g = found.filter(x => x.type === t); if (!g.length) continue;
        html += `<div class="shd">${ic('d-' + ({ movie: 'film', show: 'film', episode: 'film', artist: 'people', album: 'layers', track: 'heart' }[t]), 'hi')}<span>${h}</span><b></b></div>`;
        for (const it of rank(g, q).slice(0, 8)) { rows.push(it); html += rowHTML(it, rows.length - 1, false); }
      }
      label.textContent = rows.length === 1 ? '1 MATCH' : rows.length ? rows.length + ' MATCHES' : `NOTHING FOR "${term.toUpperCase()}"`;
    }
    html += `<div class="shd"><span>NOT IN YOUR LIBRARY?</span><b></b></div><div class="fx srow" data-a="sask"><div class="sth ask">${ic('d-plus', 'k')}</div><div class="stx"><div class="st">Ask Overseerr for "${esc(term)}"</div><div class="ss">Movies and shows</div></div></div>`;
    S.rows = rows; hint.textContent = ''; list.innerHTML = html; $('#sv', room).scrollTop = 0;
    // "Request" only on a show Overseerr says is not fully in the library
    if (rows.some(r => r.type === 'show')) {
      fetch('/px/overseerr/api/v1/search?query=' + encodeURIComponent(term) + '&page=1').then(r => r.json()).then(j => {
        if (my !== S.seq) return;
        $$('.rq', list).forEach(b => { const it = rows[+b.dataset.i]; const m = (j.results || []).find(x => x.mediaType === 'tv' && (x.name || '').toLowerCase() === (it.title || '').toLowerCase()); if (m && !(m.mediaInfo && m.mediaInfo.status === 5)) b.style.display = 'flex'; });
      }).catch(() => {});
    }
  };
  const R_not_here = () => cur !== 'Search';
  idle(); S.paintKeyboard(); loadVocab();
  if (reqSearch) { const t = reqSearch; reqSearch = ''; S.set(t); }
}
function searchOpen(i) {
  const it = SR.rows[i]; if (!it) return; rememberSearch(SR.term);
  if (it.type === 'episode') openDetail(it.grandparentRatingKey, 'show', { want: { season: it.parentIndex, id: it.ratingKey } }).catch(e => toast(e.message));
  else if (it.type === 'movie' || it.type === 'show') openDetail(it.ratingKey, it.type).catch(e => toast(e.message));
  else if (it.type === 'track') { M.playList([it], 0, false); toast('Playing'); }
  else openAlbum(it.ratingKey, it.type).catch(e => toast(e.message));
}
function searchTyped(text, go) {
  if (cur !== 'Search') { reqSearch = text; go('Search'); } else SR.set(text);
}

/* ---------- Requests (Overseerr): rail of lists, poster grid, request popup ---------- */
let RQ = null;
const OV = '/px/overseerr';
async function ov(method, path, body) {
  const r = await fetch(OV + path, { method, headers: body ? { 'Content-Type': 'application/json' } : {}, body: body ? JSON.stringify(body) : undefined });
  const txt = await r.text(); let j = null; try { j = txt ? JSON.parse(txt) : null; } catch (e) { /* not json */ }
  if (!r.ok) { const e = new Error((j && j.message) || ('Overseerr said ' + r.status)); e.status = r.status; throw e; }
  return j || {};
}
const tmdb = (p, s) => p ? `https://image.tmdb.org/t/p/${s}${p}` : '';
const rqChip = (text, icon, tone) => ({ text, icon, tone });
function rqMediaChip(st) {
  if (st === 2) return rqChip('Requested', 'clock', 'gold');
  if (st === 3) return rqChip('Approved', 'stamp', 'gold');
  if (st === 4) return rqChip('Partly here', 'check', 'olive');
  if (st === 5) return rqChip('In library', 'check', 'olive');
  return rqChip('Request', 'plus', 'out');
}
function rqDownload(media) {
  if (!media || !media.downloadStatus || !media.downloadStatus.length) return null;
  let size = 0, left = 0, secs = 0, allDone = true;
  for (const d of media.downloadStatus) {
    size += d.size || 0; left += d.sizeLeft || 0;
    if (!['completed', 'importpending', 'importing'].includes(String(d.status || '').toLowerCase())) allDone = false;
    const p = String(d.timeLeft || '').split(':'); if (p.length === 3) secs = Math.max(secs, +p[0] * 3600 + +p[1] * 60 + +p[2]);
  }
  const pct = size > 0 ? Math.floor((size - left) * 100 / size) : 0;
  const stage = allDone || pct >= 100 ? 'importing' : 'downloading';
  const lt = stage === 'downloading' && secs > 0 ? (secs >= 3600 ? `${secs / 3600 | 0} h ${(secs % 3600) / 60 | 0} min left` : secs >= 60 ? `${secs / 60 | 0} min left` : 'under a minute left') : '';
  return { pct, stage, left: lt, n: media.downloadStatus.length };
}
const rqYear = r => { const d = r.releaseDate || r.firstAirDate || ''; return d.length >= 4 ? d.slice(0, 4) : ''; };
function rqMediaCard(r) {
  const st = r.mediaInfo && r.mediaInfo.status != null ? r.mediaInfo.status : -1;
  const title = r.title || r.name || '';
  return { kind: 'media', title, image: tmdb(r.posterPath, 'w185'), chip: rqMediaChip(st), progress: -1, data: { id: r.id, mediaType: r.mediaType, title, year: rqYear(r), overview: r.overview, poster: r.posterPath, rating: r.voteAverage, mediaStatus: st }, score: r.voteAverage > 0 ? (Math.round(r.voteAverage * 10) / 10).toFixed(1) : '', vote: r.voteAverage || 0, genreIds: r.genreIds || [], date: r.releaseDate || r.firstAirDate || '' };
}
function rqWhen(iso) {
  if (!iso) return ''; const d = new Date(iso), n = new Date();
  if (d.toDateString() === n.toDateString()) return 'today at ' + d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
}
function rqRequestCard(q, info) {
  const media = q.media, ms = media && media.status != null ? media.status : -1, rs = q.status != null ? q.status : -1, dl = rqDownload(media);
  let pct = dl ? dl.pct : -1, caption = '', chip, note;
  if (rs === 1) { caption = 'Waiting for approval'; chip = rqChip('Waiting approval', 'clock', 'out'); note = 'Waiting for approval in Overseerr.'; }
  else if (rs === 3) { chip = rqChip('Declined', 'warn', 'ember'); note = 'This request was declined in Overseerr.'; }
  else if (rs === 4) { chip = rqChip('Failed', 'warn', 'ember'); note = "Overseerr couldn't send this to Radarr or Sonarr. Check Overseerr's Requests page."; }
  else if (ms === 5) { chip = rqChip('Ready · Play', 'play', 'olive'); caption = 'Ready to watch'; note = 'Ready to watch. Press OK to open it.'; }
  else if (ms === 4) { chip = rqChip('Partly ready', 'play', 'olive'); caption = 'The rest is on the way'; note = 'Some of it is ready to watch; the rest is on the way.'; }
  else if (dl && dl.stage === 'importing') { chip = rqChip('Importing', 'layers', 'dim'); note = 'Downloaded. Adding it to Plex now.'; caption = 'Adding to Plex'; }
  else if (dl) { chip = rqChip('Downloading ' + pct + '%', 'down', 'dim'); note = 'Downloading now.'; caption = dl.n > 1 ? dl.n + ' parts coming. ' + dl.left : dl.left; }
  else { chip = rqChip('Searching', 'search', 'dim'); note = 'Approved. Waiting for a download to start.'; caption = 'Looking for a release'; pct = 0; }
  const when = rqWhen(q.createdAt); if (when) note = `Requested ${when}. ` + note;
  const title = info.title || 'Untitled';
  return { kind: 'media', title, image: tmdb(info.posterPath, 'w185'), chip, progress: pct, caption, active: !!dl || (rs === 2 && ms !== 5), data: { id: info.id, mediaType: info.mediaType, title, year: rqYear(info), overview: info.overview, poster: info.posterPath, rating: info.voteAverage, mediaStatus: ms, requestId: q.id, requestStatus: rs, note, runtime: info.runtime, seasons: info.numberOfSeasons } };
}
const rqEyebrow = d => {
  let e = d.mediaType === 'tv' ? 'SHOW' : 'MOVIE';
  if (d.year) e += ' · ' + d.year;
  if (d.runtime > 0) e += ' · ' + (d.runtime >= 60 ? `${d.runtime / 60 | 0}H ${d.runtime % 60}M` : d.runtime + 'M');
  if (d.seasons > 0) e += ` · ${d.seasons} SEASON${d.seasons > 1 ? 'S' : ''}`;
  return e;
};
const rqRating = v => v > 0 ? (Math.round(v * 10) / 10).toFixed(1) : '';
function rqSeasons(tv) {
  const have = {};
  for (const s of ((tv.mediaInfo && tv.mediaInfo.seasons) || [])) if (s.seasonNumber != null && [5, 2, 3].includes(s.status)) have[s.seasonNumber] = s.status;
  return (tv.seasons || []).filter(s => s.seasonNumber > 0).map(s => {
    let info = s.episodeCount != null ? s.episodeCount + ' episodes' : '';
    info += s.airDate && s.airDate.length >= 4 ? ' · ' + s.airDate.slice(0, 4) : (info ? '' : 'announced');
    const st = have[s.seasonNumber];
    return { number: s.seasonNumber, label: 'Season ' + s.seasonNumber, sub: info, tag: st ? (st === 5 ? 'In library' : 'Requested') : '', aired: !!s.airDate };
  });
}
const arrivedWhen = secs => {
  if (!secs) return { band: '', text: '', today: false };
  const d = new Date(secs * 1000), n = new Date(); const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const days = Math.round((day(n) - day(d)) / 86400000);
  if (days <= 0) return { band: 'TODAY', text: 'today ' + d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }), today: true };
  if (days === 1) return { band: 'YESTERDAY', text: 'yesterday', today: false };
  if (days < 7) return { band: d.toLocaleDateString([], { weekday: 'short' }).toUpperCase(), text: d.toLocaleDateString([], { weekday: 'long' }), today: false };
  const md = d.toLocaleDateString([], { month: 'short', day: 'numeric' }); return { band: md.toUpperCase(), text: md, today: false };
};
const RQ_FILT = ['trending', 'movies', 'tv'];
const rqNF = kind => ({ kind: kind || 'movie', genres: [], provider: '', minRating: 0, sort: 'popular' });
// The streaming services worth showing (TMDB has hundreds), in a fixed order, without the "with ads" and channel variants
function rqPickProviders(all) {
  const out = [];
  for (const [k, n] of [['netflix', 'Netflix'], ['max', 'Max'], ['disney', 'Disney+'], ['prime video', 'Prime'], ['apple tv', 'Apple TV+'], ['hulu', 'Hulu'], ['paramount', 'Paramount+'], ['peacock', 'Peacock'], ['tubi', 'Tubi']]) {
    const p = all.find(x => { const nm = (x.name || '').toLowerCase(); return (k === 'max' ? (nm === 'max' || nm === 'hbo max') : nm.includes(k)) && !nm.includes('ads') && !nm.includes('channel'); });
    if (p) out.push({ id: p.id, name: n, logoPath: p.logoPath });
  }
  return out;
}
const RLISTS = [
  { key: 'search', icon: 'search', name: 'Search', about: 'TYPE A TITLE' },
  { key: 'new', icon: 'down', name: 'New', about: 'NEWLY DOWNLOADED · NEWEST FIRST' },
  { key: 'trending', icon: 'spark', name: 'Trending', about: 'TRENDING THIS WEEK', path: '/api/v1/discover/trending' },
  { key: 'movies', icon: 'film', name: 'Popular movies', about: 'POPULAR MOVIES', path: '/api/v1/discover/movies' },
  { key: 'tv', icon: 'tv', name: 'Popular shows', about: 'POPULAR SHOWS', path: '/api/v1/discover/tv' },
  { key: 'upcoming', icon: 'cal', name: 'Coming soon', about: 'MOVIES COMING SOON', path: '/api/v1/discover/movies/upcoming' },
  { key: 'mine', icon: 'clock', name: 'Your requests', about: "WHAT YOU'VE ASKED FOR" },
  { key: 'music', icon: 'note', name: 'Music', about: 'LIDARR' }
];
const RTABS = [['', 'layers', 'All'], ['movie', 'film', 'Movies'], ['tv', 'tv', 'Shows'], ['music', 'note', 'Music']];
const ricon = n => `<i class="ic" style="--m:url(img/icons/${n}.png)"></i>`;

function roomRequests(room, tok) {
  room.innerHTML = `<div class="rr"><div class="rrail" id="rrail">${RLISTS.map((l, i) => `<div class="fx rli" data-a="rail" data-i="${i}">${ricon(l.icon)}<span>${l.name}</span><em></em></div>`).join('')}</div>
    <div class="rhead"><div class="reb" id="reb"></div><div class="rtt" id="rtt"></div></div>
    <div class="rtabs" id="rtabs"></div>
    <div class="rfbar" id="rfb"><div class="fx rfbtn" data-a="rqfilter">${ricon('list')}<span>Filter &amp; sort</span></div><div class="rfsum" id="rfs"></div></div>
    <div class="rgrid scroll" id="rg"><div class="rgg" id="rgg"></div></div>
    <div class="rempty" id="rem"></div>
    <div class="rsearch" id="rs"><div class="skb"><div class="sdisp" id="rsd"></div><div class="srule"></div>
      <div class="skeys" style="margin-top:20px">${[...KEYCH].map(c => `<div class="fx key" data-a="rqkey" data-c="${c}">${c.toUpperCase()}</div>`).join('')}
      <div class="fx key wide" data-a="rqkey" data-c=" ">Space</div><div class="fx key wide" data-a="rqkey" data-c="⌫">Delete</div><div class="fx key wide" data-a="rqkey" data-c="⌧">Clear</div></div></div>
      <div class="rsres"><div class="rsh" id="rsh"></div><div id="rsl"></div></div></div>
    <div class="rmusic" id="rm">${ricon('note')}<h3>ASK LIDARR FOR AN ARTIST</h3><p>Music requests aren't on the projector yet. Use the TV for those for now.</p></div>
    <div class="rtoast" id="rto"><span id="rtt2"></span><em id="rth"></em></div></div>`;
  const S = RQ = RQ && RQ.keep ? Object.assign(RQ, { room }) : { room, idx: 2, cards: {}, details: {}, newTab: 0, newAll: null, text: '', query: '', pending: null, seq: 0, keep: true, filters: { trending: rqNF('all'), movies: rqNF('movie'), tv: rqNF('tv') }, gen: {}, acc: {}, seen: {}, pageNo: {}, totalPages: {}, moreBusy: {}, busy: {}, listError: {}, totals: {}, loadedAt: {}, genres: { movie: [], tv: [] }, provs: { movie: [], tv: [] }, rt: {} };
  S.room = room; S.tok = tok; S.over = null;
  const $r = s => $(s, room);
  S.cur = () => RLISTS[S.idx];
  S.paintRail = () => $$('.rli', room).forEach((e, i) => {
    e.classList.toggle('cur', i === S.idx);
    const k = RLISTS[i].key, c = S.cards[k];
    e.querySelector('em').textContent = c && k !== 'search' && k !== 'music' ? c.length : '';
  });
  S.header = (eb, title, rating) => { $r('#reb').innerHTML = esc(eb) + (rating ? `<i class="star">★</i>${esc(rating)}` : ''); $r('#rtt').textContent = (title || '').toUpperCase(); };
  const chipHTML = ch => ch && ch.text ? `<div class="rchip ${ch.tone}">${ricon(ch.icon)}<span>${esc(ch.text.toUpperCase())}</span></div>` : '';
  S.cardHTML = (c, i) => {
    const sq = c.square, mine = S.cur().key === 'mine' && !S.over;
    const sk = c.kind === 'media' && c.data && c.data.id && (c.data.mediaType === 'movie' || c.data.mediaType === 'tv') ? c.data.mediaType + ':' + c.data.id : '';
    return `<div class="fx rc ${mine ? 'mine' : ''}" data-a="rqcard" data-i="${i}" ${sk ? `data-sk="${sk}"` : ''}><div class="rim ${sq ? 'sq' : ''}" data-bg="${esc(c.image || '')}"></div><div class="rph ${sq ? 'sq' : ''}">${esc(c.title)}</div>${c.score && c.kind === 'media' ? `<div class="rscore">★ ${esc(c.score)}</div>` : ''}${chipHTML(c.chip)}${c.progress >= 0 ? `<div class="rbar"><i style="width:${Math.max(c.progress > 0 ? 8 : 0, Math.min(100, c.progress))}%"></i></div>` : ''}${c.caption ? `<div class="rcap"><b>${esc(c.title)}</b><span>${esc(c.caption)}</span></div>` : ''}</div>`;
  };
  S.show = () => {
    const l = S.cur(); S.paintRail();
    if (RQ_FILT.includes(l.key) && !S.busy[l.key] && S.loadedAt[l.key] && Date.now() - S.loadedAt[l.key] > 300000) S.loadList(l.key);
    const k = l.key, ov_ = S.over;
    $r('#rs').style.display = k === 'search' && !ov_ ? 'block' : 'none';
    $r('#rm').style.display = k === 'music' && !ov_ ? 'flex' : 'none';
    $r('#rg').style.display = (k === 'search' || k === 'music') && !ov_ ? 'none' : 'block';
    $r('#rtabs').style.display = k === 'new' && !ov_ ? 'flex' : 'none';
    const filt = RQ_FILT.includes(k) && !ov_;
    $r('#rfb').style.display = filt ? 'flex' : 'none';
    if (filt) $r('#rfs').textContent = S.summary(k);
    $r('#rg').style.top = (k === 'new' || filt) && !ov_ ? '210px' : '140px';
    $r('#rem').style.top = (k === 'new' || filt) && !ov_ ? '230px' : '160px';
    if (k === 'new') $r('#rtabs').innerHTML = RTABS.map(([, ic_, n], i) => `<div class="fx rtab ${i === S.newTab ? 'cur' : ''}" data-a="rtab" data-i="${i}">${ricon(ic_)}<span>${n}</span></div>`).join('');
    if (ov_) { S.header(ov_.eyebrow, ov_.title); S.draw(ov_.cards); return; }
    $r('#rem').textContent = '';
    if (k === 'search') { S.header('SEARCH OVERSEERR', ''); S.paintResults(); return; }
    if (k === 'music') { S.header('MUSIC · LIDARR', 'Request music'); return; }
    S.header(l.about, l.name);
    const cards = S.cards[k];
    $r('#rem').textContent = '';
    if (!cards) { $r('#rg #rgg') && ($r('#rgg').innerHTML = ''); $r('#rem').textContent = S.problem || (k === 'new' ? 'Asking Plex…' : 'Asking Overseerr…'); return; }
    if (k === 'new') { const want = RTABS[S.newTab][0]; S.draw(cards.filter(c => !want || c.data.kind === want)); } else S.draw(cards);
    if (!cards.length && RQ_FILT.includes(k) && S.active(k)) $r('#rem').textContent = 'Nothing matches those filters. Open Filter & sort to change them.';
    else if (!cards.length && S.listError[k]) $r('#rem').textContent = S.listError[k] + ' Open Filter & sort to change the filters.';
    else if (!cards.length) $r('#rem').textContent = k === 'mine' ? 'No requests yet. Pick something in Trending or Search and press OK.' : k === 'new' ? "Nothing new here yet. Things you request show up here once they've downloaded." : 'Nothing here right now.';
  };
  S.draw = cards => {
    S.shown = cards; const g = $r('#rgg'); g.className = 'rgg' + (S.cur().key === 'mine' && !S.over ? ' mine' : '');
    g.innerHTML = cards.map(S.cardHTML).join(''); $r('#rg').scrollTop = 0;
  };
  S.info = i => {
    const c = S.shown && S.shown[i]; if (!c) return;
    if (c.kind === 'plex') { S.header(c.eyebrow, c.title); return; }
    S.header(rqEyebrow(Object.assign({}, c.data, S.details[c.data.mediaType + c.data.id] ? { runtime: S.details[c.data.mediaType + c.data.id].runtime, seasons: S.details[c.data.mediaType + c.data.id].numberOfSeasons } : {})), c.data.title, rqRating(c.data.rating));
    clearTimeout(S.dt); S.dt = setTimeout(async () => {
      const key = c.data.mediaType + c.data.id; if (S.details[key]) return;
      try { S.details[key] = await ov('GET', `/api/v1/${c.data.mediaType}/${c.data.id}`); if (RQ === S && S.shown === S.shown) S.info(i); } catch (e) { /* ignore */ }
    }, 400);
  };
  S.toastMsg = (text, hint, ms) => { $r('#rtt2').textContent = text; $r('#rth').textContent = hint || ''; $r('#rto').classList.add('show'); clearTimeout(S.tt); if (ms !== 0) S.tt = setTimeout(() => $r('#rto').classList.remove('show'), ms || 4000); };
  S.load = async () => {
    for (const l of RLISTS) if (l.path) S.loadList(l.key);
    ov('GET', '/api/v1/genres/movie').then(j => { S.genres.movie = j.results || []; }).catch(() => {});
    ov('GET', '/api/v1/genres/tv').then(j => { S.genres.tv = j.results || []; }).catch(() => {});
    for (const kind of ['movie', 'tv']) ov('GET', `/api/v1/watchproviders/${kind === 'movie' ? 'movies' : 'tv'}?watchRegion=US`).then(j => { S.provs[kind] = rqPickProviders(j.results || []); }).catch(() => {});
    S.loadMine(); S.loadNew();
  };
  /* Discover lists: every filter is a live Overseerr query; pages load as you scroll (Trending, once narrowed, asks the movie or show Discover list) */
  S.eff = key => key === 'movies' ? 'movie' : key === 'tv' ? 'tv' : key === 'trending' ? S.filters.trending.kind : '';
  S.pathFor = key => key === 'trending' && S.filters.trending.kind === 'movie' ? '/api/v1/discover/movies' : key === 'trending' && S.filters.trending.kind === 'tv' ? '/api/v1/discover/tv' : RLISTS.find(l => l.key === key).path;
  S.loadList = key => {
    S.gen[key] = (S.gen[key] || 0) + 1; S.acc[key] = []; S.seen[key] = new Set(); S.pageNo[key] = 0; S.totalPages[key] = 0; S.moreBusy[key] = false; S.loadedAt[key] = Date.now(); S.busy[key] = true; S.listError[key] = '';
    S.page(key, 1);
  };
  S.page = (key, p) => {
    const g = S.gen[key], path = S.pathFor(key);
    ov('GET', path + '?' + S.query_(key, p)).then(j => {
      if (S.gen[key] !== g) return;
      S.busy[key] = false; S.moreBusy[key] = false;
      const fresh = [];
      for (const r of (j.results || [])) {
        if (r.mediaType === undefined && r.title !== undefined) r.mediaType = 'movie';
        if (r.mediaType !== 'movie' && r.mediaType !== 'tv') continue;
        const id = r.mediaType + r.id;
        if (!S.seen[key].has(id)) { S.seen[key].add(id); const c = rqMediaCard(r); S.acc[key].push(c); fresh.push(c); }
      }
      S.problem = ''; S.pageNo[key] = p; S.totalPages[key] = j.totalPages || 0; S.totals[key] = j.totalResults; S.cards[key] = S.acc[key];
      if (RQ === S && S.room === room) {
        S.paintRail();
        if (S.cur().key === key && !S.over) {
          if (p === 1) S.show();
          else { const n = $$('.rc', room).length; $r('#rgg').insertAdjacentHTML('beforeend', fresh.map((c, i) => S.cardHTML(c, n + i)).join('')); S.shown = S.acc[key]; $r('#rfs').textContent = S.summary(key); }
        }
      }
      if (p === 1) S.more(key);
    }).catch(e => {
      if (S.gen[key] !== g) return; S.busy[key] = false; S.moreBusy[key] = false;
      if (e.status === 401 || e.status === 403 || e.status === 503) S.problem = 'Overseerr is not letting this in (' + e.message + '). Re-send the Overseerr key from the phone.';
      else if (p === 1 && S.cards[key]) { S.listError[key] = "Overseerr couldn't do that search (" + e.message + ')'; S.acc[key] = []; S.cards[key] = []; }
      else S.problem = "Can't reach Overseerr: " + e.message;
      if (S.cur().key === key) S.show();
    });
  };
  S.more = key => { if (S.moreBusy[key] || S.busy[key] || !S.pageNo[key] || S.pageNo[key] >= S.totalPages[key]) return; S.moreBusy[key] = true; S.page(key, S.pageNo[key] + 1); };
  S.query_ = (key, p) => {
    const q = new URLSearchParams({ page: p }), kind = S.eff(key);
    if (kind !== 'movie' && kind !== 'tv') return q.toString();
    const f = S.filters[key];
    const ids = f.genres.map(n => (S.genres[kind].find(g => g.name === n) || {}).id).filter(Boolean); if (ids.length) q.set('genre', ids.join(','));
    if (f.provider) { q.set('watchProviders', f.provider); q.set('watchRegion', 'US'); }
    let votes = 0; if (f.minRating > 0) { q.set('voteAverageGte', f.minRating); votes = 50; }
    const today = new Date().toISOString().slice(0, 10);
    if (f.sort === 'rating') { q.set('sortBy', 'vote_average.desc'); votes = votes || 300; }
    else if (f.sort === 'newest') { if (kind === 'movie') { q.set('sortBy', 'primary_release_date.desc'); q.set('primaryReleaseDateLte', today); } else { q.set('sortBy', 'first_air_date.desc'); q.set('firstAirDateLte', today); } votes = votes || 20; }
    else if (f.sort === 'az') { q.set('sortBy', kind === 'movie' ? 'original_title.asc' : 'original_name.asc'); votes = votes || 20; }
    if (votes) q.set('voteCountGte', votes);
    return q.toString();
  };
  S.active = key => { const f = S.filters[key]; return (key === 'trending' && f.kind !== 'all') || f.genres.length > 0 || !!f.provider || f.minRating > 0 || f.sort !== 'popular'; };
  S.summary = key => {
    const f = S.filters[key], parts = [], kind = S.eff(key) === 'tv' ? 'tv' : 'movie';
    if (key === 'trending' && f.kind !== 'all') parts.push(f.kind === 'tv' ? 'shows' : 'movies');
    if (f.genres.length) parts.push(f.genres.join(' + '));
    if (f.provider) { const p = S.provs[kind].find(x => String(x.id) === f.provider); if (p) parts.push('on ' + p.name); }
    if (f.minRating) parts.push('rated ' + f.minRating + '.0+');
    if (key !== 'trending' || f.kind !== 'all') parts.push({ popular: 'most popular', rating: 'top rated', newest: 'newest', az: 'A to Z' }[f.sort]);
    const n = Math.max((S.cards[key] || []).length, S.totals[key] || 0);
    return (S.busy[key] ? 'Asking Overseerr… · ' : (S.active(key) ? 'Filtered · ' : '') + n.toLocaleString() + ' titles · ') + parts.join(' · ');
  };
  S.sheet = () => {
    const key = S.cur().key; S.fkey = key; S.fw = JSON.parse(JSON.stringify(S.filters[key]));
    const L = openLayer('popup', '<div class="rfpanel" id="rfp"></div>', { close: () => S.applyFilters() });
    S.drawSheet(); firstFocus(L.el);
  };
  S.drawSheet = () => {
    const key = S.fkey, f = S.fw, ek = f.kind;
    const chip = (k, v, label, on, extra) => `<div class="fx rfc ${on ? 'sel' : ''}" data-a="rqfc" data-k="${k}" data-v="${esc(v)}">${extra || ''}<span>${esc(label)}</span></div>`;
    const head = `<div class="rfh">${esc(RLISTS.find(l => l.key === key).name)}</div>`;
    const kinds = key === 'trending' ? `<div class="rfs">Show</div><div class="rfrow">${[['all', 'Trending now'], ['movie', 'Movies'], ['tv', 'Shows']].map(([v, t]) => chip('kind', v, t, f.kind === v)).join('')}</div>` : '';
    if (ek === 'all') { $('#rfp').innerHTML = head + kinds + `<div class="rfs" style="font:24px HearthText;color:var(--muted)">Pick Movies or Shows to narrow Trending by genre, streaming service, rating or sort.</div><div class="rfrow rfend"><div class="fx rfc sel wide" data-a="rqfdone"><span>Show results</span></div></div>`; return; }
    const names = S.genres[ek].map(g => g.name), provs = S.provs[ek] || [];
    $('#rfp').innerHTML = head + kinds + `
      <div class="rfs">Genre</div><div class="rfrow">${chip('any', '', 'Any', !f.genres.length)}${names.map(n => chip('genre', n, n, f.genres.includes(n))).join('')}</div>
      ${provs.length ? `<div class="rfs">Streaming on</div><div class="rfrow">${chip('prov', '', 'Any', !f.provider)}${provs.map(p => chip('prov', String(p.id), p.name, f.provider === String(p.id), `<img src="${tmdb(p.logoPath, 'w92')}" alt="">`)).join('')}</div>` : ''}
      <div class="rfs">Rating (TMDB)</div><div class="rfrow">${[[0, 'Any'], [6, '6.0+'], [7, '7.0+'], [8, '8.0+']].map(([v, t]) => chip('rate', v, t, f.minRating === v, v ? '<i class="rfstar">★</i>' : '')).join('')}</div>
      <div class="rfs">Sort</div><div class="rfrow">${[['popular', 'Popular'], ['rating', 'Top rated'], ['newest', 'Newest'], ['az', 'A to Z']].map(([v, t]) => chip('sort', v, t, f.sort === v)).join('')}</div>
      <div class="rfrow rfend"><div class="fx rfc sel wide" data-a="rqfdone"><span>Show results</span></div>${chip('reset', '', 'Reset', false)}</div>`;
  };
  S.fchip = el => {
    const f = S.fw, k = el.dataset.k, v = el.dataset.v;
    if (k === 'kind') { if (f.kind !== v) { f.kind = v; f.genres = []; f.provider = ''; if (v === 'all') { f.minRating = 0; f.sort = 'popular'; } } }
    else if (k === 'any') f.genres = [];
    else if (k === 'genre') f.genres = f.genres.includes(v) ? f.genres.filter(x => x !== v) : f.genres.concat(v);
    else if (k === 'prov') f.provider = v; else if (k === 'rate') f.minRating = +v; else if (k === 'sort') f.sort = v;
    else if (k === 'reset') Object.assign(f, rqNF(S.fkey === 'trending' ? 'all' : S.fkey === 'tv' ? 'tv' : 'movie'));
    S.drawSheet(); const again = $$('#rfp .rfc').find(e => e.dataset.k === k && e.dataset.v === v) || $('#rfp .rfc'); setFocus(again);
  };
  S.applyFilters = () => {
    const key = S.fkey; if (!key || JSON.stringify(S.fw) === JSON.stringify(S.filters[key])) return;
    S.filters[key] = S.fw; S.loadList(key);
  };
  S.loadMine = async () => {
    try {
      const j = await ov('GET', '/api/v1/request?take=20&skip=0&sort=added&filter=all'); const out = [];
      for (const q of (j.results || [])) {
        const media = q.media; if (!media || media.tmdbId == null) continue; const kind = media.mediaType || q.type;
        let d = {}; try { d = await ov('GET', `/api/v1/${kind}/${media.tmdbId}`); } catch (e) { /* title unknown */ }
        out.push(rqRequestCard(q, { id: media.tmdbId, mediaType: kind, title: d.title || d.name || '', posterPath: d.posterPath, overview: d.overview, releaseDate: d.releaseDate, firstAirDate: d.firstAirDate, voteAverage: d.voteAverage, runtime: d.runtime, numberOfSeasons: d.numberOfSeasons }));
      }
      S.cards.mine = out; S.mineActive = out.some(c => c.active);
      if (RQ === S && S.room === room) { S.paintRail(); if (S.cur().key === 'mine' && !S.over) { const f = document.querySelector('#room .rc.on'); const at = f ? +f.dataset.i : -1; S.show(); if (at >= 0) setFocus($$('.rc', room)[at] || null); } }
    } catch (e) { /* leave as is */ }
  };
  S.loadNew = async () => {
    try {
      const mc = await pj('/library/recentlyAdded', { 'X-Plex-Container-Size': 60 }); const seen = new Set(), out = [];
      for (const it of (mc.Metadata || [])) {
        if (hiddenItem(it)) continue;
        const kind = it.type === 'movie' ? 'movie' : (it.type === 'show' || it.type === 'episode' || it.type === 'season') ? 'tv' : it.type === 'album' ? 'music' : ''; if (!kind) continue;
        const name = it.type === 'episode' ? it.grandparentTitle : it.type === 'season' ? it.parentTitle : it.title; const key = kind + '|' + name; if (seen.has(key)) continue; seen.add(key);
        const when = arrivedWhen(it.addedAt); const pic = it.type === 'episode' ? it.grandparentThumb : it.type === 'season' ? it.parentThumb : it.thumb;
        out.push({ kind: 'plex', title: name, image: img(pic, 180, kind === 'music' ? 180 : 270), square: kind === 'music', chip: rqChip(when.band, 'down', when.today ? 'olive' : 'out'), progress: -1, eyebrow: `${kind === 'movie' ? 'MOVIE' : kind === 'tv' ? 'SHOW' : 'ALBUM'}${it.year && kind !== 'music' ? ' · ' + it.year : ''} · ARRIVED ${when.text.toUpperCase()}`, data: { kind, item: it } });
      }
      S.cards.new = out; if (RQ === S && S.room === room) { S.paintRail(); if (S.cur().key === 'new' && !S.over) S.show(); }
    } catch (e) { S.cards.new = []; }
  };
  /* search */
  S.paintResults = () => {
    $r('#rsd').textContent = S.text || 'Type a title'; $r('#rsd').classList.toggle('ph', !S.text);
    const r = S.cards.search || []; $r('#rsh').textContent = !S.query ? 'Type a few letters' : !r.length ? `Nothing found for “${S.query}”` : 'Results · ' + r.length;
    S.shown = r;
    $r('#rsl').innerHTML = r.slice(0, 6).map((c, i) => `<div class="fx rsrow" data-a="rqcard" data-i="${i}"><div class="rsp" data-bg="${esc(c.image)}"></div><div class="rst"><b>${esc(c.title)}</b><span>${c.data.mediaType === 'tv' ? 'Show' : 'Movie'}${c.data.year ? ' · ' + c.data.year : ''}</span></div>${chipHTML(c.chip)}</div>`).join('');
  };
  S.type = t => { S.text = t.slice(0, 40); $r('#rsd').textContent = S.text || 'Type a title'; $r('#rsd').classList.toggle('ph', !S.text); clearTimeout(S.st); S.st = setTimeout(S.runSearch, 500); };
  S.runSearch = async () => {
    const q = S.text.trim(); if (q === S.query && S.cards.search) return; S.query = q;
    if (!q) { S.cards.search = []; S.paintResults(); return; }
    $r('#rsh').textContent = 'Searching…';
    try { const j = await ov('GET', '/api/v1/search?query=' + encodeURIComponent(q) + '&page=1'); if (q !== S.query) return; S.cards.search = (j.results || []).filter(r => r.mediaType === 'movie' || r.mediaType === 'tv').map(rqMediaCard); S.paintResults(); }
    catch (e) { $r('#rsh').textContent = e.message; }
  };
  S.sendPending = () => {
    const p = S.pending; if (!p) return; S.pending = null; clearInterval(S.undoT); $r('#rto').classList.remove('show');
    ov('POST', '/api/v1/request', p.body).then(() => { S.toastMsg('Requested ' + p.card.data.title); S.loadMine(); })
      .catch(e => S.toastMsg("Couldn't request " + p.card.data.title, e.message));
  };
  S.undo = () => { const p = S.pending; if (!p) return false; S.pending = null; clearInterval(S.undoT); S.paintChip(p.card, p.card.chip); S.toastMsg('Not requested: ' + p.card.data.title); return true; };
  S.paintChip = (c, chip) => { $$('.rc, .rsrow', room).forEach(e => { const cc = S.shown && S.shown[+e.dataset.i]; if (cc && cc.data && cc.data.id === c.data.id && cc.data.mediaType === c.data.mediaType) { const old = e.querySelector('.rchip'); const h = chipHTML(chip); if (old) old.outerHTML = h; else e.insertAdjacentHTML('beforeend', h); } }); };
  S.start = (c, seasons) => {
    if (S.pending) S.sendPending();
    const body = { mediaType: c.data.mediaType, mediaId: c.data.id }; if (seasons !== undefined) body.seasons = seasons;
    S.pending = { body, card: c, left: 3 }; S.paintChip(c, rqChip('Requested', 'clock', 'gold'));
    const tick = () => S.toastMsg(`Requesting ${c.data.title} · ${S.pending.left}`, 'Back to undo', 0); tick();
    clearInterval(S.undoT); S.undoT = setInterval(() => { if (!S.pending) return clearInterval(S.undoT); S.pending.left--; if (S.pending.left <= 0) S.sendPending(); else tick(); }, 1000);
  };
  S.open = async c => {
    if (!c) return;
    if (c.kind === 'plex') { const it = c.data.item; if (c.data.kind === 'music') openAlbum(it.ratingKey, it.type === 'album' ? 'album' : it.type).catch(e => toast(e.message)); else openDetail(it.type === 'episode' ? it.grandparentRatingKey : it.type === 'season' ? it.parentRatingKey : it.ratingKey, c.data.kind === 'tv' ? 'show' : 'movie').catch(e => toast(e.message)); return; }
    const d = c.data, rs = d.requestStatus != null ? d.requestStatus : -1;
    if (d.mediaStatus === 5 || (rs > 0 && d.mediaStatus === 4 && d.mediaType === 'movie')) return S.openInPlex(d);
    const key = d.mediaType + d.id;
    if (!S.details[key] && d.mediaType === 'tv') { S.toastMsg('Opening ' + d.title + '…'); try { S.details[key] = await ov('GET', '/api/v1/tv/' + d.id); } catch (e) { S.toastMsg("Couldn't open " + d.title, e.message); return; } }
    S.popup(c);
  };
  S.openInPlex = async d => {
    try {
      const mc = await pj('/hubs/search', { query: d.title, limit: 10 }); const want = d.mediaType === 'tv' ? 'show' : 'movie'; let hit = null;
      for (const h of (mc.Hub || [])) for (const m of (h.Metadata || [])) if (!hit && m.type === want && (m.title || '').toLowerCase() === d.title.toLowerCase()) hit = m;
      if (!hit) for (const h of (mc.Hub || [])) for (const m of (h.Metadata || [])) if (!hit && m.type === want) hit = m;
      if (hit) openDetail(hit.ratingKey, hit.type); else S.toastMsg("Couldn't find " + d.title + ' in Plex yet');
    } catch (e) { S.toastMsg(e.message); }
  };
  S.popup = c => {
    const d = Object.assign({}, c.data); const x = S.details[d.mediaType + d.id]; if (x) { d.runtime = x.runtime; d.seasons = x.numberOfSeasons; }
    const items = []; let overview = d.note || d.overview || ''; const rs = d.requestStatus != null ? d.requestStatus : -1;
    if (rs === 1) items.push({ label: 'Cancel request', icon: 'cancel', tag: 'cancel' });
    else if (d.mediaStatus === 2 || d.mediaStatus === 3) { if (rs < 0) overview = 'Already requested and on its way. ' + (d.overview || ''); }
    else if (rs === 3 || rs === 4 || rs < 0) {
      if (d.mediaType === 'tv') {
        const ss = x ? rqSeasons(x) : []; let latest = -1; for (const s of ss) if (s.aired && !s.tag && s.number > latest) latest = s.number;
        items.push({ label: d.mediaStatus === 4 ? 'Request the rest' : 'Request all seasons', icon: 'layers', tag: 'all' });
        if (latest > 0) items.push({ label: 'Latest season', sub: 'Season ' + latest, icon: 'latest', tag: 's' + latest });
        items.push({ label: 'Choose seasons…', icon: 'list', tag: 'choose' });
      } else items.push({ label: 'Request', icon: 'plus', tag: 'movie' });
    }
    if (d.mediaStatus === 5 || d.mediaStatus === 4) items.push({ label: 'Open in Plex', icon: 'play', tag: 'plex' });
    items.push({ label: 'More like this', icon: 'spark', tag: 'like' }, { label: 'Close', icon: 'close', tag: 'back' });
    S.showPopup(c, { eyebrow: rqEyebrow(d), rating: rqRating(d.rating), title: d.title, overview, poster: tmdb(d.poster, 'w342'), items });
  };
  S.choose = c => {
    const d = c.data, x = S.details[d.mediaType + d.id]; if (!x) return;
    const items = rqSeasons(x).map(s => ({ label: s.label, sub: s.sub, check: !!s.tag, locked: !!s.tag, right: s.tag, tag: 's' + s.number }));
    items.push({ label: 'Request 0 seasons', icon: 'plus', tag: 'send' }, { label: 'Cancel', icon: 'close', tag: 'back' });
    S.showPopup(c, { eyebrow: 'CHOOSE SEASONS', rating: '', title: d.title, overview: '', poster: tmdb(d.poster, 'w342'), items });
  };
  S.showPopup = (c, m) => {
    const L = openLayer('popup', `<div class="rpanel"><div class="rpp" style="background-image:url('${esc(m.poster)}')"></div><div class="rpx"><div class="reb">${esc(m.eyebrow)}${m.rating ? `<i class="star">★</i>${esc(m.rating)}` : ''}</div><div class="rpt">${esc(m.title.toUpperCase())}</div><div class="rpo">${esc(m.overview)}</div>
      <div class="rpi">${m.items.map(it => `<div class="fx rpb ${it.check ? 'chk' : ''} ${it.locked ? 'locked' : ''} ${it.check ? 'checked' : ''}" data-a="rqpick" data-t="${it.tag}">${it.check ? '<i class="bx"></i>' : (it.icon ? ricon(it.icon) : '')}<span>${esc(it.label)}</span>${it.sub ? `<em>${esc(it.sub)}</em>` : ''}${it.right ? `<u>${esc(it.right)}</u>` : ''}</div>`).join('')}</div><div class="rph2">Back to close</div></div></div>`);
    L.card = c; L.rq = true;
    if (c.kind === 'media' && c.data.id != null && m.rating !== '') {
      const rk = c.data.mediaType + c.data.id, put = t => { const eb = $('.reb', L.el); if (t && eb && !eb.querySelector('.rtc')) eb.insertAdjacentHTML('beforeend', `<span class="rtc">${esc(t)}</span>`); };
      if (S.rt[rk] !== undefined) put(S.rt[rk]);
      else ov('GET', c.data.mediaType === 'tv' ? `/api/v1/tv/${c.data.id}/ratings` : `/api/v1/movie/${c.data.id}/ratingscombined`).then(j => { const r = j.rt || j; S.rt[rk] = r.criticsScore != null ? 'ROTTEN TOMATOES ' + Math.round(r.criticsScore) + '%' : ''; put(S.rt[rk]); }).catch(() => { S.rt[rk] = ''; });
    }
  };
  S.pick = (L, el) => {
    const a = el.dataset.t, c = L.card, d = c.data;
    if (el.classList.contains('chk')) {
      if (el.classList.contains('locked')) return;
      el.classList.toggle('checked'); const n = $$('.chk.checked:not(.locked)', L.el).length; const send = $('[data-t=send] span', L.el); if (send) send.textContent = `Request ${n} season${n === 1 ? '' : 's'}`; return;
    }
    if (a === 'send') { const nums = $$('.chk.checked:not(.locked)', L.el).map(e => +e.dataset.t.slice(1)); if (!nums.length) return; closeLayer(); setTimeout(() => S.start(c, nums), 60); return; }
    closeLayer();
    setTimeout(() => {
      if (a === 'movie') S.start(c); else if (a === 'all') S.start(c, 'all'); else if (/^s\d+$/.test(a)) S.start(c, [+a.slice(1)]);
      else if (a === 'choose') S.choose(c);
      else if (a === 'cancel') ov('DELETE', '/api/v1/request/' + d.requestId).then(() => { S.toastMsg('Cancelled ' + d.title); S.loadMine(); }).catch(e => S.toastMsg("Couldn't cancel " + d.title, e.message));
      else if (a === 'like') ov('GET', `/api/v1/${d.mediaType}/${d.id}/recommendations?page=1`).then(j => { const cards = (j.results || []).map(r => rqMediaCard(Object.assign({ mediaType: d.mediaType }, r))); S.over = { eyebrow: 'MORE LIKE', title: d.title, cards }; S.show(); setFocus($$('.rc', room)[0] || null); }).catch(e => S.toastMsg(e.message));
      else if (a === 'plex') S.openInPlex(d);
    }, 60);
  };
  S.tab = i => { S.newTab = i; S.show(); };
  RQLeave = () => { if (S.undo()) return true; if (S.over) { S.over = null; S.show(); setFocus($$('.rc', room)[0] || null); return true; } return false; };
  RQInfo = i => { if (RQ === S && S.room === room) { S.info(i); const k = S.cur().key; if (RQ_FILT.includes(k) && S.shown && S.shown.length - i <= 18) S.more(k); } };
  S.pollT = setInterval(() => { if (cur !== 'Requests' || RQ !== S) { clearInterval(S.pollT); return; } if (S.cur().key === 'mine' && S.mineActive && !layers.length) S.loadMine(); }, 10000);
  if (!$('#rg', room)) return;
  S.show(); S.load();
  if (reqSearch) { const t = reqSearch; reqSearch = ''; S.idx = 0; S.show(); S.type(t); }
  const fr = $$('.rli', room)[S.idx]; if (fr) fr.setAttribute('data-first', '1');
}
let RQLeave = null, RQInfo = null;

/* ---------- Photos: the window, albums, and the slideshow ---------- */
let PH = null;
const photoPath = md => { const p = md.Media && md.Media[0] && md.Media[0].Part && md.Media[0].Part[0]; return (p && p.key) || md.thumb || ''; };
const isPhotoMd = md => md.type === 'photo' && md.Media && md.Media.length > 0;
const normPhoto = md => {
  if (isPhotoMd(md)) {
    const t = ((md.title || '') + ' ' + photoPath(md)).toLowerCase(); if (t.includes('screenshot')) return null;
    const m0 = md.Media[0];
    return { type: 'photo', id: md.ratingKey, name: md.title, path: photoPath(md), w: m0.width, h: m0.height, fav: md.userRating >= 10, date: md.originallyAvailableAt || (md.year ? String(md.year) : '') };
  }
  if (md.type === 'photo' || md.type === 'photoalbum' || (md.key || '').includes('/children')) return { type: 'album', id: md.ratingKey, name: md.title, path: md.thumb, count: md.leafCount != null ? md.leafCount : md.childCount };
  return null;
};
const photoCaption = it => { if (!it || !it.date) return ''; const d = it.date; if (d.length >= 7) { const mo = +d.slice(5, 7); const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']; if (mo >= 1 && mo <= 12) return names[mo - 1] + ' ' + d.slice(0, 4); } return d.slice(0, 4); };
const imgFit = (p, w, h) => p ? `${PX}/photo/:/transcode?width=${w}&height=${h}&minSize=0&upscale=1&url=${encodeURIComponent(p)}` : '';
const thousands = n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
const PREF = (k, d) => { try { return localStorage.getItem('hearth.' + k) || d; } catch (e) { return d; } };
const SETPREF = (k, v) => { try { localStorage.setItem('hearth.' + k, v); } catch (e) { /* ignore */ } };
const shiftDay = (day, d) => { const t = new Date(day + 'T12:00:00Z'); t.setUTCDate(t.getUTCDate() + d); return t.toISOString().slice(0, 10); };
async function photoQuery(op, a) {
  const sec = `/library/sections/${photoLib.key}/all`;
  const keep = mc => (mc.Metadata || mc.Directory || []).map(normPhoto).filter(Boolean);
  if (op === 'albums') { const mc = await pj(sec); return [].concat(mc.Directory || [], mc.Metadata || []).map(normPhoto).filter(x => x && x.type === 'album'); }
  if (op === 'random') return keep(await pj(sec, { type: 13, sort: 'random', 'X-Plex-Container-Start': 0, 'X-Plex-Container-Size': a.limit || 60 })).filter(x => x.type === 'photo');
  if (op === 'ordered') return keep(await pj(sec, { type: 13, sort: 'originallyAvailableAt:asc', 'X-Plex-Container-Start': a.start || 0, 'X-Plex-Container-Size': a.limit || 60 })).filter(x => x.type === 'photo');
  if (op === 'favourites') return keep(await pj(sec, { type: 13, 'userRating>>': 9, sort: 'originallyAvailableAt:asc', 'X-Plex-Container-Start': 0, 'X-Plex-Container-Size': 500 })).filter(x => x.type === 'photo');
  if (op === 'count') { const mc = await pj(sec, Object.assign({ type: 13, 'X-Plex-Container-Start': 0, 'X-Plex-Container-Size': 0 }, a || {})); return mc.totalSize != null ? mc.totalSize : (mc.size || 0); }
  if (op === 'onthisday') {
    const now = new Date(), mo = String(now.getMonth() + 1).padStart(2, '0'), dd = String(now.getDate()).padStart(2, '0'), out = [];
    const years = []; for (let y = now.getFullYear() - 25; y < now.getFullYear(); y++) years.push(y);
    const res = await Promise.all(years.map(y => { const day = `${y}-${mo}-${dd}`; return pj(sec, { type: 13, 'originallyAvailableAt>>': shiftDay(day, -1), 'originallyAvailableAt<<': shiftDay(day, 1), 'X-Plex-Container-Start': 0, 'X-Plex-Container-Size': 50 }).then(mc => keep(mc).filter(x => x.type === 'photo' && (x.date || '').slice(0, 10) === day)).catch(() => []); }));
    res.forEach(r => out.push(...r)); return out.slice(0, a && a.enough ? a.enough : 200);
  }
  if (op === 'album') {
    const kids = (await pj(`/library/metadata/${a.id}/children`)).Metadata || []; const out = [];
    for (const md of kids) { const it = normPhoto(md); if (!it) continue; if (it.type === 'photo') out.push(it); else if (out.length < 500) { try { for (const m2 of ((await pj(`/library/metadata/${it.id}/children`)).Metadata || [])) { const i2 = normPhoto(m2); if (i2 && i2.type === 'photo') out.push(i2); } } catch (e) { /* skip */ } } }
    return out;
  }
  return [];
}

async function roomPhotos(room, tok) {
  await libs();
  if (!photoLib) { room.innerHTML = '<div class="soon"><img src="img/lantern.png" alt=""><h2>No photos yet</h2><p>Add your photos folder to Plex as a Photos library. Each folder inside it becomes an album here.</p></div>'; return; }
  const win = document.createElement('div'); win.id = 'pwin'; win.innerHTML = '<div class="pw a"></div><div class="pw b"></div><div class="pshade"></div>'; stage.insertBefore(win, $('#bar'));
  room.innerHTML = `<div class="phr"><div class="peb"><i class="ic" style="--m:url(img/icons/d-layers.png)"></i><span id="pe">THE WINDOW</span></div><div class="ptt" id="pt">YOUR PHOTOS</div>
    <div class="pbtns2" id="pb"></div><div class="palh" id="pah" style="display:none">ALBUMS</div><div class="palrow scroll" id="pal"><div class="palin" id="pali"></div></div><div class="pnote" id="pn"></div></div>`;
  const S = PH = { win, front: 'b', photos: [], pos: -1, tok, sum: { total: 0, fav: 0, otd: 0 } };
  S.stop = () => { clearInterval(S.t); win.remove(); if (PH === S) PH = null; };
  const buttons = () => {
    const b = [['', 'home-play', 'Start the slideshow']]; if (S.sum.otd > 0) b.push(['@onthisday', 'home-cal', 'On this day']); if (S.sum.fav > 0) b.push(['@favourites', 'home-sort', 'Favourites · ' + S.sum.fav]);
    $('#pb', room).innerHTML = b.map(([id, i, t]) => `<div class="fx pill big" data-a="pshow" data-id="${id}" data-n="${esc(id === '@onthisday' ? 'On this day' : id === '@favourites' ? 'Favourites' : '')}">${ic(i)}<span>${esc(t)}</span></div>`).join('');
    if (!$('.fx.on', room) && cur === 'Photos' && !layers.length && !focusEl) setFocus($('#pb .fx', room));
  };
  const next = () => {
    if (!S.photos.length || cur !== 'Photos') return;
    S.pos = (S.pos + 1) % S.photos.length; const it = S.photos[S.pos];
    const back = S.front === 'a' ? $('.pw.b', win) : $('.pw.a', win), front = S.front === 'a' ? $('.pw.a', win) : $('.pw.b', win);
    const u = img(it.path, 1280, 720); const im = new Image();
    im.onload = () => { back.style.backgroundImage = `url("${u}")`; back.style.opacity = 1; front.style.opacity = 0; S.front = S.front === 'a' ? 'b' : 'a'; $('#pt', room).textContent = (photoCaption(it) || 'Your photos').toUpperCase(); };
    im.src = u;
  };
  buttons(); setFocus($('#pb .fx', room)); autoF = focusEl;
  photoQuery('count').then(n => { S.sum.total = n; if (n) $('#pe', room).textContent = 'THE WINDOW · ' + thousands(n) + ' PHOTOS'; else $('#pn', room).textContent = 'Add your photos folder to Plex as a Photos library.'; }).catch(e => { $('#pn', room).textContent = "Can't reach Plex: " + e.message; });
  photoQuery('count', { 'userRating>>': 9 }).then(n => { S.sum.fav = n; buttons(); }).catch(() => {});
  photoQuery('onthisday', { enough: 1 }).then(l => { S.sum.otd = l.length; buttons(); }).catch(() => {});
  photoQuery('albums').then(list => {
    if (!list.length) return; $('#pah', room).style.display = 'block';
    $('#pali', room).innerHTML = list.map((a, i) => `<div class="fx ptile" data-a="pshow" data-id="${a.id}" data-n="${esc(a.name)}"><div class="pti" data-bg="${img(a.path, 272, 172)}"></div><div class="ptn">${esc(a.name)}</div><div class="pts">${a.count == null ? 'Album' : a.count === 1 ? '1 photo' : thousands(a.count) + ' photos'}</div></div>`).join('');
  }).catch(() => {});
  photoQuery('random', { limit: 30 }).then(all => { S.photos = all.filter(p => !p.w || !p.h || p.w >= p.h); if (!S.photos.length) S.photos = all; if (S.photos.length) { next(); S.t = setInterval(next, 12000); } }).catch(() => {});
}

function openSlideshow(albumId, albumName) {
  const L = openLayer('slide', `<div class="sl"><div class="sla" id="sla"><div class="slb"></div><div class="slp"></div><div class="slp2"></div></div><div class="sla" id="slb"><div class="slb"></div><div class="slp"></div><div class="slp2"></div></div>
    <div class="slshade"></div><div class="sclk"><div class="sct" id="sct"></div><img class="sctw" src="img/twig.png" alt=""><div class="scd" id="scd"></div></div>
    <div class="scap"><div class="sca" id="sca"></div><div class="scc" id="scc"></div><div class="scs" id="scs"></div></div>
    <div class="snp" id="snp"></div><div class="spause" id="spause">❚❚  Paused</div><div class="sstat" id="sstat">Opening the window…</div>
    <div class="shint" id="shint">◀ ▶ Photos &nbsp; OK Pause &nbsp; ▼ Options &nbsp; Back Close</div><div class="sopt" id="sopt"></div></div>`, {
    onKey(e) {
      const k = e.key;
      if (L.opt) { if (k === 'Escape' || k === 'Backspace') { L.closeOpt(); return true; } return false; }
      if (k === 'ArrowRight') { L.step(1); return true; }
      if (k === 'ArrowLeft') { L.step(-1); return true; }
      if (k === 'Enter' || k === ' ') { L.setPaused(!L.paused); return true; }
      if (k === 'ArrowDown') { L.openOpt(); return true; }
      return false;
    }
  });
  const el = L.el; L.queue = []; L.nextI = 0; L.history = []; L.back = 0; L.offset = 0; L.paused = false; L.front = 1; L.loading = false; L.id = albumId; L.name = albumName || '';
  L.seconds = +PREF('photoSeconds', '8') || 8; L.order = PREF('photoOrder', 'shuffle');
  const layersEl = [$('#sla', el), $('#slb', el)];
  $('#sca', el).textContent = L.name ? L.name.toUpperCase() : 'ALL PHOTOS';
  const portrait = it => it && it.w && it.h && it.h > it.w * 1.05;
  const tick = () => { const n = new Date(); $('#sct', el).textContent = n.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }); $('#scd', el).textContent = n.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' }); };
  tick(); L.ct = setInterval(tick, 20000);
  L.fetch = async () => {
    if (L.loading) return; L.loading = true;
    try {
      let list;
      if (L.id === '@favourites') list = await photoQuery('favourites');
      else if (L.id === '@onthisday') { if (!L.queue.length) $('#sstat', el).textContent = 'Looking back through the years…'; list = await photoQuery('onthisday', {}); }
      else if (L.id) list = await photoQuery('album', { id: L.id });
      else if (L.order === 'order') { list = await photoQuery('ordered', { start: L.offset, limit: 60 }); if (!list.length && L.offset > 0) { L.offset = 0; list = await photoQuery('ordered', { start: 0, limit: 60 }); } else L.offset += 60; }
      else list = await photoQuery('random', { limit: 60 });
      if (!list.length && !L.queue.length) { $('#sstat', el).textContent = L.id === '@onthisday' ? 'No photos from this day in past years.' : 'No photos found. Press Back.'; L.loading = false; return; }
      if (L.id && L.id !== '@favourites' && L.id !== '@onthisday' && L.order !== 'order') list.sort(() => Math.random() - .5);
      else if (!L.id && L.order !== 'order') { /* already random from Plex */ }
      L.queue = L.queue.slice(L.nextI).concat(list); L.nextI = 0;
      if (L.fresh === undefined) { L.fresh = true; L.show(1); }
    } catch (e) { $('#sstat', el).textContent = "Can't get photos from Plex (" + e.message + '). Press Back.'; }
    L.loading = false;
  };
  L.peek = () => {
    if (L.nextI >= L.queue.length) return null;
    const a = L.queue[L.nextI]; if (portrait(a) && L.nextI + 1 < L.queue.length && portrait(L.queue[L.nextI + 1])) return [a, L.queue[L.nextI + 1]];
    return [a];
  };
  L.show = dir => {
    let slide;
    if (dir < 0) { if (L.back + 1 >= L.history.length) return; L.back++; slide = L.history[L.history.length - 1 - L.back]; }
    else if (L.back > 0) { L.back--; slide = L.history[L.history.length - 1 - L.back]; }
    else { slide = L.peek(); if (!slide) { L.fetch(); return; } L.nextI += slide.length; L.history.push(slide); if (L.history.length > 30) L.history.shift(); if (L.queue.length - L.nextI < 12) L.fetch(); }
    L.draw(slide);
  };
  L.step = d => { L.show(d); L.restartTimer(); };
  L.draw = slide => {
    const to = 1 - L.front, a = layersEl[to], b = layersEl[L.front];
    const pair = slide.length === 2;
    const ps = $$('.slp', a).concat($$('.slp2', a)); const p1 = $('.slp', a), p2 = $('.slp2', a), bk = $('.slb', a);
    const u1 = pair ? img(slide[0].path, 960, 1080) : imgFit(slide[0].path, 1920, 1080);
    const pre = new Image();
    const go_ = () => {
      p1.style.backgroundImage = `url("${u1}")`; p1.className = 'slp' + (pair ? ' half' : '');
      if (pair) { p2.style.backgroundImage = `url("${img(slide[1].path, 960, 1080)}")`; p2.style.display = 'block'; } else p2.style.display = 'none';
      bk.style.backgroundImage = pair ? '' : `url("${img(slide[0].path, 96, 54)}")`;
      a.style.opacity = 1; b.style.opacity = 0; L.front = to; $('#sstat', el).textContent = '';
      const it = slide[0]; $('#scc', el).textContent = pair ? '' : photoCaption(it); $('#scs', el).textContent = !pair && it.fav ? '★ FAVOURITE' : ''; L.cur = slide;
    };
    pre.onload = go_; pre.onerror = () => { L.show(1); }; pre.src = u1;
  };
  L.restartTimer = () => { clearInterval(L.at); if (!L.paused) L.at = setInterval(() => L.show(1), L.seconds * 1000); };
  L.setPaused = p => { L.paused = p; $('#spause', el).style.display = p ? 'block' : 'none'; L.restartTimer(); };
  L.npTick = setInterval(() => { const t = M.cur && M.cur(); const np = $('#snp', el); if (!np) return; np.innerHTML = t && M.playing ? `<em>NOW PLAYING</em><span>${esc(t.title)}</span>` : ''; }, 2000);
  L.openOpt = () => {
    const secs = [5, 8, 12, 20, 30], cur_ = L.cur && L.cur[0];
    $('#sopt', el).innerHTML = `<h4>Options</h4><div class="fx chip" data-a="soptsec">Time per photo: ${L.seconds} s</div><div class="fx chip" data-a="soptorder">Order: ${L.order === 'order' ? 'Oldest first' : 'Shuffle'}</div>${cur_ && L.cur.length === 1 ? `<div class="fx chip ${cur_.fav ? 'live' : ''}" data-a="soptfav">${cur_.fav ? '★ Favourite (tap to remove)' : '☆ Make favourite'}</div>` : ''}<div class="fx chip" data-a="soptclose">Close</div>`;
    $('#sopt', el).style.display = 'flex'; L.opt = true; clearInterval(L.at); setFocus($('#sopt .fx', el));
  };
  L.closeOpt = () => { $('#sopt', el).style.display = 'none'; L.opt = false; L.restartTimer(); setFocus(null); };
  L.onBack = () => { if (L.opt) { L.closeOpt(); return true; } return false; };
  L.secs = [5, 8, 12, 20, 30];
  L.close = () => { clearInterval(L.at); clearInterval(L.ct); clearInterval(L.npTick); };
  L.fetch().then(() => L.restartTimer()); setFocus(null);
  return L;
}
/* ---------- Test room ---------- */
let testMode = 'auto';
async function roomTest(room, tok) {
  await libs();
  const nav = navigator;
  const rows = [
    ['Browser', nav.userAgent.replace(/\(.*?\)/, '').slice(0, 90)],
    ['Screen', `${screen.width}×${screen.height} @${devicePixelRatio}× · window ${innerWidth}×${innerHeight}`],
    ['Memory / cores', `${nav.deviceMemory || '?'} GB · ${nav.hardwareConcurrency || '?'} cores`],
    ['Android', (/Android ([\d.]+)/.exec(nav.userAgent) || [0, 'not shown'])[1]]
  ];
  const mc = navigator.mediaCapabilities;
  const probes = [['H.264 1080p', 'video/mp4; codecs="avc1.640028"', 1920, 1080], ['HEVC 1080p', 'video/mp4; codecs="hvc1.1.6.L120.90"', 1920, 1080], ['HEVC 4K', 'video/mp4; codecs="hvc1.1.6.L150.90"', 3840, 2160], ['VP9 1080p', 'video/webm; codecs="vp09.00.40.08"', 1920, 1080], ['AV1 1080p', 'video/mp4; codecs="av01.0.08M.08"', 1920, 1080]];
  const cap = [];
  for (const [n, t, w, h] of probes) {
    let r = '';
    try { const i = await mc.decodingInfo({ type: 'file', video: { contentType: t, width: w, height: h, bitrate: 8e6, framerate: 30 } }); r = i.supported ? (i.smooth ? 'yes, smooth' : 'yes, may stutter') + (i.powerEfficient ? ' · hardware' : ' · software') : 'no'; } catch (e) { r = TV.canPlayType(t) ? 'maybe' : 'no'; }
    cap.push([n, r]);
  }
  cap.push(['AC-3 / E-AC-3 audio', `${CAP.ac3 ? 'yes' : 'no'} / ${CAP.eac3 ? 'yes' : 'no'}`], ['HLS (this app\'s player)', (window.Hls && Hls.isSupported() ? 'yes, hls.js' : CAP.hlsNative ? 'yes, native' : 'NO')]);
  const tbl = a => `<div class="tbl">${a.map(([k, v]) => `<b>${esc(k)}</b><div class="${/^(yes|maybe)/i.test(v) ? "yes" : /^no( |$|\/)/i.test(v) ? 'no' : ''}">${esc(v)}</div>`).join('')}</div>`;
  let list = [];
  try {
    const all = await pj('/library/recentlyAdded', { 'X-Plex-Container-Size': 50 });
    list = (all.Metadata || []).filter(m => (m.type === 'movie' || m.type === 'episode') && !hiddenItem(m)).slice(0, 10);
  } catch (e) { /* offline */ }
  if (tok !== renderTok) return;
  let picT = 'no titles to test with';
  if (list[0]) {
    const t0 = performance.now();
    try { const r = await fetch(img(cardOf(list[0]).pic, 320, 180)); const b = await r.blob(); picT = `HTTP ${r.status} · ${(b.size / 1024) | 0} KB · ${((performance.now() - t0) / 1000).toFixed(1)} s`; }
    catch (e) { picT = 'failed: ' + e.message; }
  }
  cap.push(['Poster picture test', picT]);
  const modes =[['auto', 'Automatic'], ['direct', 'Direct play'], ['hls1080', 'Converted 1080p'], ['hls720', 'Converted 720p'], ['hlsforce', 'Always convert']];
  room.innerHTML = `<div class="scroll"><div class="hd" style="margin-top:20px">This projector</div>${tbl(rows)}${hd('What it can decode')}${tbl(cap)}
    ${hd('Play a test', 'pick how, then a title')}<div class="row" id="tmodes" style="gap:14px;margin-bottom:26px">${modes.map(([m, n]) => `<div class="fx chip ${m === testMode ? 'live' : ''}" data-a="tmode" data-m="${m}">${n}</div>`).join('')}</div>
    <div class="row">${list.map(m => cardHTML(m).replace('data-a="play"', 'data-a="testplay"')).join('') || '<div class="msg" style="position:static;font-size:34px;padding:30px 0">Plex is not answering</div>'}</div>
    <div class="ms" style="margin-top:24px;font-size:22px;max-width:1300px">In the player: ▼ shows playback stats (dropped frames show if the picture stutters), ◀ ▶ skip, OK pauses, Back leaves. Send a photo of the stats.</div></div>`;
}

/* ---------- actions ---------- */
function act(el) {
  const d = el.dataset, a = d.a;
  if (a === 'room') { if (d.r !== cur) go(d.r); else setFocus($('#room .fx')); }
  else if (a === 'play') playItem(d.k, d.t, d.from != null ? { from: +d.from } : {}).catch(e => toast(e.message));
  else if (a === 'testplay') playItem(d.k, d.t, { mode: testMode, stats: true, from: 0 }).catch(e => toast(e.message));
  else if (a === 'tmode') { testMode = d.m; $$('#tmodes .chip').forEach(c => c.classList.toggle('live', c === el)); toast('Mode: ' + el.textContent); }
  else if (a === 'detail') openDetail(d.k, d.t).catch(e => toast(e.message));
  else if (a === 'open') openItem(+d.i);
  else if (a === 'ltab') { const S = LR.S; S.tab = +d.i; S.genreOpen = null; LR.load(); }
  else if (a === 'lbtn') { const it = LR.cur; if (!it) return; if (d.b === 'detail') openItem(LR.items.indexOf(it)); else playItem(it.ratingKey, it.type, {}).catch(e => toast(e.message)); }
  else if (a === 'lchip') {
    const S = LR.S, k = d.k;
    if (k === 'sort') { S.sort = (S.sort + 1) % SORTS.length; LR.load(); }
    else if (k === 'unw') { S.unw = !S.unw; LR.load(); }
    else if (k === 'clear') { S.sort = 0; S.unw = false; S.genre = null; S.decade = ''; LR.load(); }
    else if (k === 'genre') pj(`/library/sections/${LR.lib.key}/genre`).then(mc => { const g = mc.Directory || []; LR.pickList('Genre', ['Any genre'].concat(g.map(x => x.title)), i => { S.genre = i ? { key: g[i - 1].key, title: g[i - 1].title } : null; LR.load(); }); }).catch(e => toast(e.message));
    else LR.pickList('Decade', ['Any decade', '2020s', '2010s', '2000s', '1990s', '1980s', '1970s', '1960s', '1950s'], i => { S.decade = i ? String(2030 - i * 10) : ''; LR.load(); });
  }
  else if (a === 'lletter') { const i = LR.firstAt[+d.i]; if (i >= 0) { const g = $$('.pc2', $('#room'))[i]; $('#lg').scrollTop = Math.floor(i / 9) * 291; setFocus(g); } }
  else if (a === 'pickopt') { const L = layers[layers.length - 1]; const cb = L.cb; closeLayer(); cb(+d.i); }
  else if (a === 'dact') {
    const L = layers[layers.length - 1], k = d.d;
    if (k === 'cc') {
      const sl = subsOf(L.full), cur = L.subSel !== undefined ? L.subSel : defSub(L.full);
      pickSheet('Subtitles', ['Off'].concat(sl.map(sLabel)), i => { L.subSel = i ? sl[i - 1].id : 0; L.render(); setFocus($$('.ib', L.el)[L.acts.findIndex(x => x[2] === 'cc')]); }, 1 + sl.findIndex(x => x.id === cur));
    } else if (k === 'audio') {
      const al = audOf(L.full), cur = L.audSel !== undefined ? L.audSel : defAud(L.full);
      pickSheet('Audio', al.map(sLabel), i => { L.audSel = al[i].id; L.render(); setFocus($$('.ib', L.el)[L.acts.findIndex(x => x[2] === 'audio')]); }, al.findIndex(x => x.id === cur));
    } else if (k === 'more') {
      const md = L.md, m0 = L.full && L.full.Media && L.full.Media[0], pt = m0 && m0.Part && m0.Part[0];
      const row = (n, v) => v ? `<div class="mr"><em>${esc(n)}</em><span>${esc(v)}</span></div>` : '';
      const names = a => (a || []).map(x => x.tag).join(', ');
      const size = pt && pt.size ? (pt.size / 1073741824).toFixed(1) + ' GB' : '';
      const html = row('Studio', md.studio) + row('Directed by', names(md.Director)) + row('Written by', names(md.Writer)) + row('Genres', names(md.Genre)) + row('Country', names(md.Country)) + row('Added', md.addedAt ? new Date(md.addedAt * 1000).toLocaleDateString() : '') + row('File', pt && pt.file ? pt.file.split('/').pop() : '') + row('Size', size) + row('Video', m0 ? `${m0.width}x${m0.height} ${m0.videoCodec} ${m0.bitrate || ''} kbps` : '') + row('Container', m0 && m0.container);
      openLayer('sheet more', `<div class="in" style="flex-direction:column"><h2>More</h2><div class="mlist scroll" style="position:relative;flex:1;overflow:auto">${html}</div><div class="fx chip" data-a="back">Close</div></div>`);
    } else if (k === 'resume') playTarget(L); else if (k === 'restart') playTarget(L, 0);
    else if (k.startsWith('trailer:')) playItem(k.slice(8), 'clip', { from: 0 }).catch(e => toast(e.message));
    else if (k === 'watch' || k === 'unwatch') fetch(`${PX}/:/${k === 'watch' ? 'scrobble' : 'unscrobble'}?key=${L.md.ratingKey}&identifier=com.plexapp.plugins.library`).then(() => { toast(k === 'watch' ? 'Marked watched' : 'Marked unwatched'); L.load(); }).catch(() => toast('Plex did not answer'));
  }
  else if (a === 'ep') { const L = layers[layers.length - 1]; L.epSel = +d.i; playTarget(L, null, L.eps[+d.i]); }
  else if (a === 'season') { const L = layers[layers.length - 1]; L.sIdx = +d.i; L.loadEps().then(() => { L.drawTabs(); L.drawEps(); setFocus($$('.stab', L.el)[L.sIdx]); }); }
  else if (a === 'shuffle') { const L = layers[layers.length - 1]; const e = L.eps[Math.random() * L.eps.length | 0]; playTarget(L, 0, e); }
  else if (a === 'pskip') layers[layers.length - 1].doSkip();
  else if (a === 'pupplay') layers[layers.length - 1].goNext();
  else if (a === 'pupno') { const L = layers[layers.length - 1]; clearInterval(L.upT); $('#pup', L.el).style.display = 'none'; setFocus(null); }
  else if (a === 'pchap') layers[layers.length - 1].pickChap();
  else if (a === 'clip') playItem(d.k, 'clip', { from: 0 }).catch(e => toast(e.message));
  else if (a === 'skey') { const c = d.c; if (c === '⌫') SR.set(SR.text.slice(0, -1)); else if (c === '⌧') SR.set(''); else SR.set(SR.text + c); }
  else if (a === 'spick') SR.set(d.t);
  else if (a === 'srecent') SR.set(d.t);
  else if (a === 'sopen') searchOpen(+d.i);
  else if (a === 'srq') { rememberSearch(SR.term); reqSearch = SR.rows[+d.i].title; go('Requests'); }
  else if (a === 'sask') { rememberSearch(SR.term); reqSearch = SR.term; go('Requests'); }
  else if (a === 'rail') { RQ.idx = +d.i; RQ.over = null; RQ.show(); setFocus($$('.rc', $('#room'))[0] || $('#room .rsrow') || $('#room .key') || null); }
  else if (a === 'rqcard') RQ.open(RQ.shown[+d.i]);
  else if (a === 'rtab') RQ.tab(+d.i);
  else if (a === 'rqkey') { const c = d.c; if (c === '⌫') RQ.type(RQ.text.slice(0, -1)); else if (c === '⌧') RQ.type(''); else RQ.type(RQ.text + c); }
  else if (a === 'rqpick') RQ.pick(layers[layers.length - 1], el);
  else if (a === 'rqfilter') RQ.sheet();
  else if (a === 'rqfc') RQ.fchip(el);
  else if (a === 'rqfdone') closeLayer();
  else if (a === 'pshow') openSlideshow(d.id, d.n);
  else if (a === 'soptsec') { const L = layers[layers.length - 1]; L.seconds = L.secs[(L.secs.indexOf(L.seconds) + 1) % L.secs.length]; SETPREF('photoSeconds', L.seconds); el.textContent = 'Time per photo: ' + L.seconds + ' s'; }
  else if (a === 'soptorder') { const L = layers[layers.length - 1]; L.order = L.order === 'order' ? 'shuffle' : 'order'; SETPREF('photoOrder', L.order); el.textContent = 'Order: ' + (L.order === 'order' ? 'Oldest first' : 'Shuffle') + ' (next batch)'; }
  else if (a === 'soptfav') { const L = layers[layers.length - 1]; const it = L.cur && L.cur[0]; if (!it) return; const want = it.fav ? -1 : 10; fetch(`${PX}/:/rate?key=${it.id}&identifier=com.plexapp.plugins.library&rating=${want}`).then(() => { it.fav = !it.fav; el.textContent = it.fav ? '★ Favourite (tap to remove)' : '☆ Make favourite'; el.classList.toggle('live', it.fav); $('#scs', L.el).textContent = it.fav ? '★ FAVOURITE' : ''; }).catch(() => toast('Plex did not answer')); }
  else if (a === 'soptclose') layers[layers.length - 1].closeOpt();
  else if (a === 'mood') openMood(d.m);
  else if (a === 'album' || a === 'malb') albumMenu(d.k, d.t).catch(e => toast(e.message));
  else if (a === 'dlg') dlgPick(el);
  else if (a === 'mtab') { MR.tab = +d.i; SETPREF0('musicTab', MR.tab); $$('.mtabs .mword').forEach((w, i) => w.classList.toggle('cur', i === MR.tab)); mShowTab(renderTok); }
  else if (a === 'mlet') { const t = $$('#mscroll .mt2')[+d.i]; if (t) setFocus(t); }
  else if (a === 'mplayk' || a === 'mshufk') albumKids(d.k, 'album').then(k => M.playList(k, 0, a === 'mshufk')).catch(e => toast(e.message));
  else if (a === 'mshuf') M.setShuffle(!M.shuffle);
  else if (a === 'mmore') musicOptions();
  else if (a === 'qjump') { const i = +d.i; closeThen(() => M.jump(i)); }
  else if (a === 'amood') { const v = clipCache && clipCache.v; const it = v && v.list[+d.i]; if (it) openMood(it.mood); }
  else if (a === 'mdim') layers[layers.length - 1].cycleDim();
  else if (a === 'mvprev') M.prev();
  else if (a === 'mvtoggle') M.toggle();
  else if (a === 'mvnext') M.next();
  else if (a === 'mvshuf') M.setShuffle(!M.shuffle);
  else if (a === 'mvrep') M.cycleRepeat();
  else if (a === 'mvmode') layers[layers.length - 1].setMode(d.m);
  else if (a === 'mvlook') lookMenu(layers[layers.length - 1]);
  else if (a === 'mvfire') fireMenu(layers[layers.length - 1]);
  else if (a === 'mvlib') closeThen(() => { if (cur !== 'Music') go('Music'); });
  else if (a === 'mtoggle') M.toggle();
  else if (a === 'mnext') M.next();
  else if (a === 'mprev') M.prev();
  else if (a === 'mshuffle') M.shuffleAll().catch(e => toast(e.message));
  else if (a === 'mtrack') { const L = layers[layers.length - 1]; M.playList(L.kids, +d.n, false); toast('Playing'); }
  else if (a === 'sheetplay') { const L = layers[layers.length - 1]; M.playList(L.kids, 0, false); toast('Playing'); }
  else if (a === 'sheetshuf') { const L = layers[layers.length - 1]; M.playList(L.kids, 0, true); toast('Shuffled'); }
  else if (a === 'msound') { const L = layers[layers.length - 1]; L.setSound(!L.soundOn); }
  else if (a === 'mtimer') layers[layers.length - 1].cycleTimer();
  else if (a === 'mleave' || a === 'back') closeLayer();
  else if (a === 'pseek') { const L = layers[layers.length - 1]; L.seek(+d.d); }
  else if (a === 'ppp') layers[layers.length - 1].toggle();
  else if (a === 'pstats') layers[layers.length - 1].toggleStats();
  else if (a === 'pcc') layers[layers.length - 1].pickSub();
  else if (a === 'paud') layers[layers.length - 1].pickAud();
  else if (a === 'pmopt') { const L = layers[layers.length - 1]; const cb = L.menuCb; L.closeMenu(); setFocus($('.pbtns .fx', L.el)); if (cb) cb(+d.i); }
}

/* ---------- start ---------- */
drawBar();
go('Home');
})();
