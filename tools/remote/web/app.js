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
function fit() {
  K = Math.min(innerWidth / 1920, innerHeight / 1080);
  stage.style.transform = `translate(${(innerWidth - 1920 * K) / 2}px,${(innerHeight - 1080 * K) / 2}px) scale(${K})`;
}
addEventListener('resize', fit); fit();
function tick() {
  const d = new Date();
  $('#clk').textContent = d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  $('#dat').textContent = d.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
}
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
  return `<div class="fx card" data-a="play" data-k="${md.ratingKey}" data-t="${md.type}"><div class="img" style="background-image:url('${img(c.pic, 480, 270)}')"><div class="ph">${esc(c.title)}</div>${c.prog ? `<div class="braid"><i style="width:${c.prog}%"></i></div>` : ''}</div><div class="t">${esc(c.title)}</div><div class="s">${esc(c.sub)}</div></div>`;
}
function albumHTML(md) {
  const t = md.type === 'artist' ? 'Artist' : md.type === 'playlist' ? `${md.leafCount || ''} songs` : (md.parentTitle || '');
  const pic = md.thumb || md.composite;
  return `<div class="fx alb" data-a="album" data-k="${md.ratingKey}" data-t="${md.type}"><div class="im" style="background-image:url('${img(pic, 360, 360)}')"></div><div class="t">${esc(md.title)}</div><div class="s">${esc(t)}</div></div>`;
}
const hd = (t, small) => `<div class="hd">${esc(t)}${small ? `<small>${esc(small)}</small>` : ''}</div>`;

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
function setFocus(el) {
  if (focusEl) focusEl.classList.remove('on');
  focusEl = el;
  if (el) { el.classList.add('on'); reveal(el); }
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
  el.className = 'layer ' + cls; el.innerHTML = html;
  $('#layers').appendChild(el);
  const L = Object.assign({ el, prev: focusEl }, handlers || {});
  layers.push(L);
  history.pushState({ n: layers.length }, '');
  firstFocus(el);
  return L;
}
function closeLayer() { if (layers.length) history.back(); }
addEventListener('popstate', () => {
  const L = layers.pop();
  if (!L) return;
  try { L.close && L.close(); } catch (e) { /* fine */ }
  L.el.remove();
  if (L.prev && document.contains(L.prev)) setFocus(L.prev); else firstFocus(layers.length ? layers[layers.length - 1].el : $('#room'));
});
history.replaceState({ n: 0 }, '');

/* ---------- keys ---------- */
addEventListener('keydown', e => {
  const top = layers[layers.length - 1];
  if (top && top.onKey && top.onKey(e) === true) { e.preventDefault(); return; }
  const k = e.key;
  if (k.startsWith('Arrow')) { e.preventDefault(); move(k); }
  else if (k === 'Enter' || k === ' ') { if (focusEl) { e.preventDefault(); act(focusEl); } }
  else if (k === 'Escape' || k === 'Backspace' || k === 'BrowserBack' || k === 'GoBack') { e.preventDefault(); back(); }
  else if (k === 'MediaPlayPause') { M.toggle(); }
  else if (k === 'MediaTrackNext') { M.next(); }
  else if (k === 'MediaTrackPrevious') { M.prev(); }
});
function back() {
  if (layers.length) { closeLayer(); return; }
  if (cur !== 'Home') go('Home');
}
document.addEventListener('click', e => { const el = e.target.closest('[data-a]'); if (el) { setFocus(el); act(el); } });
document.addEventListener('mouseover', e => { const el = e.target.closest('.fx'); if (el && el !== focusEl && (!layers.length || layers[layers.length - 1].el.contains(el))) setFocus(el); });

/* ---------- rooms ---------- */
const ROOMS = ['Home', 'Shows', 'Movies', 'Music', 'Requests', 'Ambiance', 'Photos', 'Search', 'Test'];
const LIVE = new Set(['Home', 'Music', 'Ambiance', 'Test']);
let cur = 'Home', renderTok = 0, autoF = null;
function drawBar() {
  $('#rooms').innerHTML = ROOMS.map(r => `<div class="fx rm ${r === cur ? 'cur' : ''}" data-a="room" data-r="${r}">${r}<i class="dot"></i></div>`).join('');
}
async function go(name, keepFocus) {
  cur = name; drawBar();
  const tok = ++renderTok;
  const room = $('#room'); room.innerHTML = '';
  let ok = true;
  try {
    if (name === 'Home') await roomHome(room, tok);
    else if (name === 'Music') await roomMusic(room, tok);
    else if (name === 'Ambiance') roomAmbiance(room);
    else if (name === 'Test') await roomTest(room, tok);
    else soon(room, name);
  } catch (e) { if (tok === renderTok) { room.innerHTML = `<div class="msg">Can't reach your library right now.<br>${esc(e.message)}</div>`; } }
  if (tok !== renderTok) return;
  if (!keepFocus) { const f = $('#room .fx') || $$('#bar .fx').find(x => x.dataset.r === name); setFocus(f); autoF = f; }
  else setFocus($$('#bar .fx').find(x => x.dataset.r === name));
}
function soon(room, name) {
  room.innerHTML = `<div class="soon"><img src="img/lantern.png" alt=""><h2>${esc(name)} is coming to the projector</h2><p>Home, Music, Ambiance and the video test are ready first. Movies, Shows, Requests, Photos and Search follow once playback is confirmed here.</p></div>`;
}

/* ---------- Home ---------- */
const MOODS = [['hearth', 'Hearth'], ['rain', 'Rain'], ['fireflies', 'Fireflies'], ['lightsout', 'Lights out']];
async function roomHome(room, tok) {
  await libs();
  const mood = MOODS.map(([m, n]) => `<div class="fx mtile" data-a="mood" data-m="${m}" style="background-image:url(img/tile-${m}.jpg)"><b>${n}</b></div>`).join('');
  room.innerHTML = `<div class="scroll">
    <div class="hero" id="hero"><div class="kick" style="left:40px;top:24px;position:absolute">Loading</div></div>
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
    addRow('Recently added', 'new', out.slice(0, 20).map(cardHTML), 1);
  }).catch(() => {});
  if (musicLib) pj(`/library/sections/${musicLib.key}/albums`, { sort: 'addedAt:desc', 'X-Plex-Container-Size': 20 }).then(mc => {
    if (tok !== renderTok) return;
    addRow('Music · new albums', 'albums', (mc.Metadata || []).map(albumHTML), 2);
  }).catch(() => {});
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

/* ---------- Music engine ---------- */
const aud = new Audio(); aud.preload = 'auto';
const M = {
  queue: [], i: -1, playing: false,
  cur() { return this.queue[this.i]; },
  trackOf(md) {
    const media = (md.Media || [])[0], part = media && (media.Part || [])[0];
    const c = ((media && media.container) || '').toLowerCase(), codec = ((media && media.audioCodec) || '').toLowerCase();
    const okC = ['mp3', 'flac', 'mp4', 'm4a', 'aac', 'wav', 'ogg'].includes(c) && !['alac', 'wma', 'dts'].includes(codec);
    const sid = 'hm' + md.ratingKey;
    const url = !part ? '' : okC ? `${PX}${part.key}`
      : `${PX}/music/:/transcode/universal/start.mp3?path=${encodeURIComponent('/library/metadata/' + md.ratingKey)}&mediaIndex=0&partIndex=0&protocol=http&directPlay=0&directStream=0&session=${sid}`;
    return { id: md.ratingKey, title: md.title, artist: md.originalTitle || md.grandparentTitle || '', album: md.parentTitle || '', thumb: md.parentThumb || md.thumb || md.grandparentThumb, dur: (md.duration || 0) / 1000, url };
  },
  async playList(items, start, shuffle) {
    let q = items.filter(m => m.type === 'track').map(m => this.trackOf(m)).filter(t => t.url);
    if (!q.length) { toast('Nothing playable there'); return; }
    if (shuffle) { for (let i = q.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0;[q[i], q[j]] = [q[j], q[i]]; } start = 0; }
    this.queue = q; this.i = Math.max(0, start || 0); this.load(true);
  },
  load(play) {
    const t = this.cur(); if (!t) return;
    aud.src = t.url;
    if (play) { aud.play().then(() => { this.playing = true; this.paint(); }).catch(() => { toast('The browser blocked sound until you press a key'); this.playing = false; this.paint(); }); }
    try { localStorage.setItem('hearth.last', JSON.stringify(t)); } catch (e) { /* ignore */ }
    this.paint();
  },
  toggle() {
    if (!this.cur()) { this.shuffleAll(); return; }
    if (aud.paused) aud.play().then(() => { this.playing = true; this.paint(); }); else { aud.pause(); this.playing = false; this.paint(); }
  },
  next() { if (!this.queue.length) return; this.i = (this.i + 1) % this.queue.length; this.load(true); },
  prev() { if (!this.queue.length) return; if (aud.currentTime > 4) { aud.currentTime = 0; return; } this.i = (this.i - 1 + this.queue.length) % this.queue.length; this.load(true); },
  async shuffleAll() {
    await libs();
    if (!musicLib) { toast('No music library found'); return; }
    toast('Mixing something up…');
    const mc = await pj(`/library/sections/${musicLib.key}/all`, { type: 10, sort: 'random', 'X-Plex-Container-Size': 60 });
    await this.playList(mc.Metadata || [], 0, false);
  },
  paint() {
    const t = this.cur();
    const set = (id, fn) => { const e = document.getElementById(id); if (e) fn(e); };
    for (const p of ['mc', 'np']) {
      set(p + '-t', e => e.textContent = t ? t.title : 'Shuffle my music');
      set(p + '-s', e => e.textContent = t ? (t.artist + (t.album && p === 'np' ? ' · ' + t.album : '')) : 'OK to start a random mix');
      set(p + '-eb', e => e.textContent = t ? (this.playing ? 'Now playing' : 'Paused') : 'Music');
      set(p + '-pp', e => e.textContent = this.playing ? '❚❚' : '▶');
      set(p + '-art', e => e.style.backgroundImage = t ? `url('${img(t.thumb, 360, 360)}')` : '');
    }
  }
};
aud.addEventListener('ended', () => M.next());
aud.addEventListener('timeupdate', () => {
  const p = aud.duration ? aud.currentTime / aud.duration * 100 : 0;
  for (const id of ['mc-bar', 'np-bar']) { const e = document.getElementById(id); if (e) e.style.width = p + '%'; }
});
aud.addEventListener('error', () => { if (M.cur()) { toast('Skipping a song that wouldn\'t play'); setTimeout(() => M.next(), 600); } });
try { const l = JSON.parse(localStorage.getItem('hearth.last') || 'null'); if (l && l.url) { M.queue = [l]; M.i = 0; aud.src = l.url; } } catch (e) { /* ignore */ }

/* ---------- Music room ---------- */
async function roomMusic(room, tok) {
  await libs();
  if (!musicLib) { room.innerHTML = '<div class="msg">No music library in Plex yet.</div>'; return; }
  room.innerHTML = `<div class="scroll"><div class="np"><div class="al" id="np-art"></div><div>
    <div class="kick" id="np-eb" style="color:var(--rope)">Music</div><h1 id="np-t">Shuffle my music</h1><div class="sub" id="np-s"></div>
    <div class="pb"><i id="np-bar"></i></div>
    <div class="ctl2"><div class="fx chip live" data-a="mtoggle"><span id="np-pp">▶</span></div><div class="fx chip" data-a="mprev">⏮ Back</div><div class="fx chip" data-a="mnext">Next ⏭</div><div class="fx chip" data-a="mshuffle">Shuffle all</div></div></div></div><div id="mrows"></div></div>`;
  M.paint();
  const rows = $('#mrows');
  const add = (t, s, html) => { if (tok !== renderTok || !html.length) return; rows.insertAdjacentHTML('beforeend', hd(t, s) + `<div class="row">${html.join('')}</div>`); };
  const rec = await pj(`/library/sections/${musicLib.key}/albums`, { sort: 'addedAt:desc', 'X-Plex-Container-Size': 24 });
  add('Recently added', 'albums', (rec.Metadata || []).map(albumHTML));
  pj('/playlists', { playlistType: 'audio' }).then(mc => add('Playlists', 'playlists', (mc.Metadata || []).map(albumHTML))).catch(() => {});
  pj(`/library/sections/${musicLib.key}/albums`, { sort: 'titleSort', 'X-Plex-Container-Size': 120 }).then(mc => {
    if (tok !== renderTok) return;
    rows.insertAdjacentHTML('beforeend', hd('All albums', 'A to Z') + `<div class="grid">${(mc.Metadata || []).map(albumHTML).join('')}</div>`);
  }).catch(() => {});
}
async function openAlbum(id, type) {
  let kids, meta;
  if (type === 'playlist') { kids = (await pj(`/playlists/${id}/items`)).Metadata || []; meta = (await pj(`/playlists/${id}`)).Metadata?.[0] || {}; }
  else if (type === 'artist') { kids = (await pj(`/library/metadata/${id}/allLeaves`)).Metadata || []; meta = (await pj(`/library/metadata/${id}`)).Metadata?.[0] || {}; }
  else { kids = (await pj(`/library/metadata/${id}/children`)).Metadata || []; meta = (await pj(`/library/metadata/${id}`)).Metadata?.[0] || {}; }
  kids = kids.filter(t => !hiddenItem(t));
  const rows = kids.map((t, n) => `<div class="fx trk" data-a="mtrack" data-n="${n}"><b>${t.index || n + 1}</b><span>${esc(t.title)}</span><em>${t.duration ? Math.floor(t.duration / 60000) + ':' + String(Math.floor(t.duration / 1000) % 60).padStart(2, '0') : ''}</em></div>`).join('');
  const L = openLayer('sheet', `<div class="in"><div class="cov" style="background-image:url('${img(meta.thumb || meta.composite, 720, 720)}')"></div>
    <div style="position:relative;flex:1"><h2>${esc(meta.title || '')}</h2><div class="ar">${esc(meta.parentTitle || meta.leafCount && meta.leafCount + ' songs' || '')}</div>
    <div style="display:flex;gap:16px;margin-bottom:22px"><div class="fx chip live" data-a="sheetplay">▶ Play</div><div class="fx chip" data-a="sheetshuf">Shuffle</div></div>
    <div style="position:absolute;left:0;right:0;top:150px;bottom:0;overflow:hidden" class="tl-wrap"><div class="tl scroll" style="padding:6px 0 80px">${rows}</div></div></div></div>`);
  L.kids = kids;
}

/* ---------- Ambiance ---------- */
const AMB = [['hearth', 'Hearth', 'A log fire, crackling'], ['rain', 'Rain', 'On the glass, after dark'], ['fireflies', 'Fireflies', 'A summer night outside'], ['lightsout', 'Lights out', 'Embers, then dark in 30 min'], ['window', 'The Window', 'Your photos']];
function roomAmbiance(room) {
  room.innerHTML = `<div class="scroll"><div class="hd" style="margin-top:20px">Set the mood<small>music keeps playing underneath</small></div>
  <div class="row" style="gap:28px">${AMB.map(([m, n, s]) => `<div class="fx card" style="width:316px" data-a="mood" data-m="${m}"><div class="img" style="width:316px;height:387px;background-image:url(img/col-${m}.jpg)"></div><div class="t" style="font-size:30px">${n}</div><div class="s">${s}</div></div>`).join('')}</div></div>`;
}
const SOUND = { hearth: 'fire', rain: 'rain', fireflies: 'night', lightsout: 'fire', window: null };
const BG = { hearth: 'hearth-bg', rain: 'rain-bg', fireflies: 'night-bg', lightsout: 'hearth-bg' };
let clipCache = null;
function clipMood(name) {
  const n = (name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  for (const [p, m] of [['firefl', 'fireflies'], ['lightsout', 'lightsout'], ['embers', 'lightsout'], ['hearth', 'hearth'], ['fireplace', 'hearth'], ['campfire', 'hearth'], ['fire', 'hearth'], ['rain', 'rain']]) if (n.startsWith(p)) return m;
  return '';
}
async function clips() {
  if (clipCache) return clipCache;
  clipCache = {};
  await libs();
  if (!ambLib) return clipCache;
  try {
    const mc = await pj(`/library/sections/${ambLib.key}/all`, { 'X-Plex-Container-Size': 100 });
    for (const md of (mc.Metadata || [])) {
      const part = md.Media?.[0]?.Part?.[0]; if (!part) continue;
      const base = (part.file || '').split('/').pop().replace(/\.[^.]+$/, '');
      const m = clipMood(base) || clipMood(md.title); if (!m) continue;
      const tv = /-tv$/i.test(base);
      if (!clipCache[m] || (tv && !clipCache[m].tv)) clipCache[m] = { url: `${PX}${part.key}`, tv };
    }
  } catch (e) { /* no clips; stills are fine */ }
  return clipCache;
}
async function openMood(mood) {
  const info = AMB.find(a => a[0] === mood) || AMB[0];
  const L = openLayer('mood ui', `<div class="bg" id="mbg" style="background-image:url(img/${BG[mood] || 'night-bg'}.jpg)"></div><canvas id="mcv" width="1280" height="720"></canvas><div class="fade" id="mfade"></div>
    <div class="name">${info[1]}</div>
    <div class="strip" id="mstrip"><div class="fx chip live" data-a="msound">Sound on</div><div class="fx chip" data-a="mmusic">Music</div><div class="fx chip" data-a="mnextsong">Next song</div><div class="fx chip" data-a="mtimer">Timer: ${mood === 'lightsout' ? '30 min' : 'off'}</div><div class="fx chip" data-a="mleave">Back</div><div class="hint">Any key shows these · Back leaves</div></div>`, {
    onKey(e) {
      if (!L.ui) { L.show(); if (e.key.startsWith('Arrow') || e.key === 'Enter' || e.key === ' ') return true; }
      L.show(); return false;
    }
  });
  L.mood = mood; L.timer = mood === 'lightsout' ? 30 : 0; L.soundOn = true; L.ui = true;
  L.show = () => { L.el.classList.add('ui'); L.ui = true; clearTimeout(L.hideT); L.hideT = setTimeout(() => { L.el.classList.remove('ui'); L.ui = false; }, 5000); };
  L.show();
  L.sfx = null;
  const sn = SOUND[mood];
  if (sn) { L.sfx = new Audio(`sound/${sn}.mp3`); L.sfx.loop = true; L.sfx.volume = .7; L.sfx.play().catch(() => toast('Press a key to start the sound')); }
  const stopFns = [];
  if (mood === 'window') stopFns.push(await windowShow(L));
  else {
    stopFns.push(effect(mood, $('#mcv', L.el)));
    const c = (await clips())[mood];
    if (c) {
      const v = document.createElement('video'); v.src = c.url; v.loop = true; v.muted = true; v.autoplay = true; v.playsInline = true;
      v.addEventListener('playing', () => { $('#mbg', L.el).style.opacity = 0; });
      v.addEventListener('error', () => { v.remove(); });
      L.el.insertBefore(v, $('#mcv', L.el)); v.play().catch(() => {});
      stopFns.push(() => { v.pause(); v.removeAttribute('src'); v.load(); });
    }
  }
  const setTimer = () => {
    clearTimeout(L.tt);
    if (L.timer) L.tt = setTimeout(() => { $('#mfade', L.el).style.opacity = 1; if (L.sfx) { let v = L.sfx.volume; const f = setInterval(() => { v -= .05; if (v <= 0) { clearInterval(f); L.sfx.pause(); } else L.sfx.volume = v; }, 400); } aud.pause(); M.playing = false; M.paint(); }, L.timer * 60000);
  };
  setTimer(); L.setTimer = setTimer;
  L.close = () => { clearTimeout(L.tt); clearTimeout(L.hideT); if (L.sfx) { L.sfx.pause(); L.sfx = null; } stopFns.forEach(f => f && f()); };
  setFocus($('.fx', L.el));
}
function effect(mood, cv) {
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
async function windowShow(L) {
  await libs();
  const bg = $('#mbg', L.el);
  let urls = [];
  try {
    if (photoLib) {
      const mc = await pj(`/library/sections/${photoLib.key}/all`, { type: 13, sort: 'addedAt:desc', 'X-Plex-Container-Size': 150 });
      urls = (mc.Metadata || []).map(m => m.Media?.[0]?.Part?.[0]?.key).filter(Boolean).map(k => `${PX}/photo/:/transcode?width=1920&height=1080&minSize=1&url=${encodeURIComponent(k)}`);
    }
  } catch (e) { /* none */ }
  if (!urls.length) { bg.innerHTML = '<div class="msg">No photos found in Plex yet.</div>'; return () => {}; }
  for (let i = urls.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0;[urls[i], urls[j]] = [urls[j], urls[i]]; }
  let n = 0; bg.style.opacity = 1; bg.style.backgroundSize = 'cover';
  const next = () => { const im = new Image(); im.onload = () => { bg.style.backgroundImage = `url('${urls[n % urls.length]}')`; n++; }; im.src = urls[n % urls.length]; };
  next(); const iv = setInterval(next, 15000);
  return () => clearInterval(iv);
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
  return vOk && aOk && (media.videoProfile || '') !== 'high 10';
}
function hlsUrl(id, offsetSec, res, session, kbps, direct) {
  const q = new URLSearchParams({
    path: '/library/metadata/' + id, mediaIndex: 0, partIndex: 0, protocol: 'hls', fastSeek: 1, directPlay: 0, directStream: direct ? 1 : 0,
    subtitleSize: 100, audioBoost: 100, maxVideoBitrate: kbps, videoResolution: res, videoQuality: 100, offset: offsetSec | 0, location: 'lan', session,
    'X-Plex-Product': 'Plex Web', 'X-Plex-Platform': 'Chrome', 'X-Plex-Device': 'Windows', 'X-Plex-Client-Identifier': 'hearth-projector', 'X-Plex-Session-Identifier': session
  });
  return `${PX}/video/:/transcode/universal/start.m3u8?${q}`;
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
  const full = (await pj('/library/metadata/' + md.ratingKey)).Metadata?.[0] || md;
  const dur = (full.duration || 0) / 1000;
  let start = o.from != null ? o.from : ((full.viewOffset || 0) / 1000);
  if (dur && (start < 10 || start > dur * .95)) start = 0;
  let mode = o.mode || 'auto';
  if (mode === 'auto') mode = canDirect(media) ? 'direct' : 'hls1080';
  const session = 'hp' + Date.now().toString(36);
  const sub = full.type === 'episode' ? `${full.grandparentTitle} · S${full.parentIndex} E${full.index}` : (full.year || '');
  const L = openLayer('player', `<video id="pv" playsinline></video><div class="stats" id="pst"></div><div class="pov show" id="pov"><h3>${esc(full.type === 'episode' ? full.title : full.title)}</h3><div class="sub">${esc(sub)}</div><div class="tm"><span id="pcur">0:00</span><div class="tr"><i id="pbar"></i></div><span id="pdur">${fmt(dur)}</span></div></div><div class="msg" id="pmsg" style="display:none"></div>`, {
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
  L.hud = () => { const p = $('#pov', L.el); p.classList.add('show'); clearTimeout(L.ht); L.ht = setTimeout(() => { if (!v.paused) p.classList.remove('show'); }, 3500); };
  L.pos = () => L.base + (v.currentTime || 0);
  L.seek = d => { const t = Math.max(0, Math.min(dur - 2, L.pos() + d)); if (L.mode === 'direct' || L.hls || CAP.hlsNative) { if (L.mode === 'direct') v.currentTime = t; else v.currentTime = t - L.base; } L.hud(); };
  const msg = t => { const m = $('#pmsg', L.el); m.style.display = t ? 'flex' : 'none'; m.textContent = t || ''; };
  const load = (m, at) => {
    if (L.hls) { L.hls.destroy(); L.hls = null; }
    L.mode = m;
    if (m === 'direct') {
      L.base = 0; v.src = `${PX}${part.key}`;
      v.addEventListener('loadedmetadata', () => { if (at) v.currentTime = at; }, { once: true });
    } else {
      const res = m === 'hls720' ? '1280x720' : '1920x1080', kb = m === 'hls720' ? 4000 : 8000;
      const url = hlsUrl(full.ratingKey, at, res, session, kb, m !== 'hlsforce');
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
  L.rt = setInterval(() => report(v.paused ? 'paused' : 'playing'), 10000);
  v.addEventListener('ended', () => { fetch(`${PX}/:/scrobble?key=${full.ratingKey}&identifier=com.plexapp.plugins.library`).catch(() => {}); closeLayer(); });
  aud.pause(); M.playing = false; M.paint();
  L.close = () => { clearInterval(L.iv); clearInterval(L.rt); clearTimeout(L.ht); report('stopped'); if (L.hls) L.hls.destroy(); v.pause(); v.removeAttribute('src'); v.load(); if (L.mode !== 'direct') fetch(`${PX}/video/:/transcode/universal/stop?session=${session}`).catch(() => {}); };
  load(mode, mode === 'direct' ? start : start);
  L.hud(); setFocus(null);
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
  const modes = [['auto', 'Automatic'], ['direct', 'Direct play'], ['hls1080', 'Converted 1080p'], ['hls720', 'Converted 720p'], ['hlsforce', 'Always convert']];
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
  else if (a === 'mood') openMood(d.m);
  else if (a === 'album') openAlbum(d.k, d.t).catch(e => toast(e.message));
  else if (a === 'mtoggle') M.toggle();
  else if (a === 'mnext') M.next();
  else if (a === 'mprev') M.prev();
  else if (a === 'mshuffle') M.shuffleAll().catch(e => toast(e.message));
  else if (a === 'mtrack') { const L = layers[layers.length - 1]; M.playList(L.kids, +d.n, false); toast('Playing'); }
  else if (a === 'sheetplay') { const L = layers[layers.length - 1]; M.playList(L.kids, 0, false); toast('Playing'); }
  else if (a === 'sheetshuf') { const L = layers[layers.length - 1]; M.playList(L.kids, 0, true); toast('Shuffled'); }
  else if (a === 'msound') { const L = layers[layers.length - 1]; if (L.sfx) { L.soundOn = !L.soundOn; L.soundOn ? L.sfx.play() : L.sfx.pause(); el.textContent = L.soundOn ? 'Sound on' : 'Sound off'; el.classList.toggle('live', L.soundOn); } else toast('This mood has no sound'); }
  else if (a === 'mmusic') M.toggle();
  else if (a === 'mnextsong') M.next();
  else if (a === 'mtimer') { const L = layers[layers.length - 1]; const o = [0, 15, 30, 60]; L.timer = o[(o.indexOf(L.timer) + 1) % o.length]; el.textContent = 'Timer: ' + (L.timer ? L.timer + ' min' : 'off'); L.setTimer(); }
  else if (a === 'mleave') closeLayer();
}

/* ---------- start ---------- */
drawBar();
go('Home');
})();
