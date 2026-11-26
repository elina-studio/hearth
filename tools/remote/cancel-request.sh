#!/bin/bash
# Cancels the Overseerr request for one title (and removes it from Sonarr/Radarr if it was already added). Prints no keys.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/cancel-request.sh) "Boarding School Juliet"
NAS="Elina@192.168.254.41"
TITLE="$1"
[ -z "$TITLE" ] && { echo "Give the title in quotes, e.g. \"Boarding School Juliet\""; exit 1; }
# read, not $(cat <<EOF): the bash on a Mac (3.2) can't parse some script text inside $( )
IFS= read -r -d '' JS <<'JSEND'
// Runs INSIDE the overseerr container (it has node and the settings.json). Prints no keys.
// Env: TITLE = show or movie name; OVERSEERR_CONFIG (test only) = settings.json path; OVERSEERR_URL (test only).
const fs = require('fs');
const title = (process.env.TITLE || '').trim();
const paths = [process.env.OVERSEERR_CONFIG, '/app/config/settings.json', '/config/settings.json'].filter(Boolean);
const file = paths.find((p) => fs.existsSync(p));
if (!file) { console.log('Could not find settings.json in the container'); process.exit(2); }
const cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
const key = cfg.main && cfg.main.apiKey;
const base = process.env.OVERSEERR_URL || 'http://localhost:5055';
async function call(method, url, k) {
  const r = await fetch(url, { method, headers: { 'X-Api-Key': k, Accept: 'application/json' } });
  const t = await r.text();
  let j = null; try { j = JSON.parse(t); } catch (e) {}
  return { status: r.status, json: j };
}
(async () => {
  const s = await call('GET', base + '/api/v1/search?query=' + encodeURIComponent(title), key);
  if (s.status !== 200) { console.log('Overseerr search failed: ' + s.status); process.exit(3); }
  const hits = (s.json.results || []).filter((x) => x.mediaType === 'tv' || x.mediaType === 'movie');
  const name = (x) => (x.name || x.title || '').toLowerCase();
  let exact = hits.filter((x) => name(x) === title.toLowerCase());
  if (exact.length === 0) {
    console.log('No exact title match for "' + title + '". Closest results:');
    hits.slice(0, 5).forEach((x) => console.log('  ' + x.mediaType + ': ' + (x.name || x.title)));
    process.exit(4);
  }
  let all = [];
  for (let skip = 0; skip < 1000; skip += 100) {
    const r = await call('GET', base + '/api/v1/request?take=100&skip=' + skip + '&filter=all', key);
    if (r.status !== 200) { console.log('Overseerr request list failed: ' + r.status); process.exit(5); }
    const res = r.json.results || [];
    all = all.concat(res);
    if (res.length < 100) break;
  }
  let removed = 0;
  for (const h of exact) {
    const mine = all.filter((q) => q.media && q.media.tmdbId === h.id && q.type === h.mediaType);
    if (mine.length === 0) console.log('No Overseerr request for "' + (h.name || h.title) + '" (' + h.mediaType + ').');
    for (const q of mine) {
      const d = await call('DELETE', base + '/api/v1/request/' + q.id, key);
      console.log('Cancelled Overseerr request #' + q.id + ' for "' + (h.name || h.title) + '": HTTP ' + d.status);
      if (d.status < 300) removed++;
    }
    // Sonarr / Radarr: only if it was already added there
    if (mine.length === 0) continue;
    const det = await call('GET', base + '/api/v1/' + h.mediaType + '/' + h.id, key);
    const ids = (det.json && det.json.externalIds) || {};
    const list = (h.mediaType === 'tv' ? cfg.sonarr : cfg.radarr) || [];
    for (const a of list) {
      const root = (process.env.ARR_URL || (a.useSsl ? 'https://' : 'http://') + a.hostname + ':' + a.port) + (a.baseUrl || '');
      const api = root + '/api/v' + (h.mediaType === 'tv' ? '3/series' : '3/movie');
      try {
        const g = await call('GET', api + '?' + (h.mediaType === 'tv' ? 'tvdbId=' + ids.tvdbId : 'tmdbId=' + h.id), a.apiKey);
        const found = Array.isArray(g.json) ? g.json[0] : null;
        if (g.status !== 200) { console.log((h.mediaType === 'tv' ? 'Sonarr' : 'Radarr') + ' ' + a.name + ' answered HTTP ' + g.status + ', left alone.'); continue; }
        if (!found) { console.log((h.mediaType === 'tv' ? 'Sonarr' : 'Radarr') + ' ' + a.name + ': not added there, nothing to remove.'); continue; }
        const gb = ((found.statistics && found.statistics.sizeOnDisk) || found.sizeOnDisk || 0);
        const x = await call('DELETE', api + '/' + found.id + '?deleteFiles=false', a.apiKey);
        console.log('Removed from ' + (h.mediaType === 'tv' ? 'Sonarr' : 'Radarr') + ' ' + a.name + ': HTTP ' + x.status + (gb ? ' (files on disk kept: ' + Math.round(gb / 1e6) + ' MB)' : ''));
      } catch (e) { console.log((h.mediaType === 'tv' ? 'Sonarr' : 'Radarr') + ' ' + a.name + ' not reachable (' + e.message + '), left alone.'); }
    }
  }
  console.log(removed > 0 ? 'Done.' : 'Nothing was cancelled.');
})().catch((e) => { console.log('Failed: ' + e.message); process.exit(1); });
JSEND
B=$(printf %s "$JS" | base64 | tr -d '\n')
T=$(printf %s "$TITLE" | base64 | tr -d '\n')
ssh -t "$NAS" "sudo -v && sudo /usr/local/bin/docker exec -e TITLE=\"\$(echo $T | base64 -d)\" overseerr node -e \"\$(echo $B | base64 -d)\""
