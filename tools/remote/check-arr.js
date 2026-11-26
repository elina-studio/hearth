// Runs INSIDE the overseerr container. Prints no keys.
const fs = require('fs');
const http = require('http');
let file = process.env.SETTINGS || '/app/config/settings.json';
if (!fs.existsSync(file)) file = '/config/settings.json';
const s = JSON.parse(fs.readFileSync(file, 'utf8'));
function get(h, p, k) {
  return new Promise((res) => {
    const r = http.get({ host: h.host, port: h.port, path: p, headers: { 'X-Api-Key': k }, timeout: 8000 }, (x) => {
      let b = ''; x.on('data', (d) => (b += d)); x.on('end', () => { let j = null; try { j = JSON.parse(b); } catch (e) {} res({ code: x.statusCode, j: j }); });
    });
    r.on('error', (e) => res({ code: 'ERR ' + e.code, j: null }));
    r.on('timeout', () => { r.destroy(); res({ code: 'TIMEOUT', j: null }); });
  });
}
async function one(kind, e) {
  console.log('\n' + kind + ' "' + e.name + '" -> ' + e.hostname + ':' + e.port + (e.isDefault ? ' (default)' : '') + (e.is4k ? ' (4K)' : ''));
  const h = { host: e.hostname, port: e.port };
  const st = await get(h, '/api/v3/system/status', e.apiKey);
  console.log('  connection + key: ' + st.code + (st.j && st.j.version ? ' (v' + st.j.version + ')' : ''));
  if (st.code !== 200) { console.log('  PROBLEM: Overseerr cannot talk to ' + kind + '. Fix the key/host in Overseerr > Settings > Services.'); return; }
  const qp = await get(h, '/api/v3/qualityprofile', e.apiKey);
  const ids = (qp.j || []).map((q) => q.id);
  console.log('  quality profiles on ' + kind + ': ' + (qp.j || []).map((q) => q.id + '=' + q.name).join(', '));
  console.log('  Overseerr uses profile ' + e.activeProfileId + ': ' + (ids.indexOf(e.activeProfileId) >= 0 ? 'OK' : 'PROBLEM, not found'));
  const rf = await get(h, '/api/v3/rootfolder', e.apiKey);
  const rfs = rf.j || [];
  const paths = rfs.map((r) => r.path);
  console.log('  Overseerr uses folder ' + e.activeDirectory + ': ' + (paths.indexOf(e.activeDirectory) >= 0 ? 'OK' : 'PROBLEM, not found (Sonarr has: ' + paths.join(', ') + ')'));
  rfs.forEach((r) => console.log('  free space ' + r.path + ': ' + Math.round((r.freeSpace || 0) / 1e9) + ' GB'));
  if (kind === 'Sonarr') console.log('  language profile ' + e.activeLanguageProfileId + ', anime profile ' + e.activeAnimeProfileId);
  const hl = await get(h, '/api/v3/health', e.apiKey);
  (hl.j || []).forEach((x) => console.log('  health ' + x.type + ': ' + x.message));
}
(async () => {
  console.log('Overseerr settings: ' + file + ', sonarr entries: ' + (s.sonarr || []).length + ', radarr entries: ' + (s.radarr || []).length);
  for (const e of s.sonarr || []) await one('Sonarr', e);
  for (const e of s.radarr || []) await one('Radarr', e);
  try {
    const log = fs.readFileSync(file.replace('settings.json', 'logs/overseerr.log'), 'utf8').split('\n');
    const bad = log.filter((l) => /error|fail/i.test(l) && /sonarr|radarr|request|media/i.test(l));
    console.log('\nLast Overseerr log errors about requests:');
    bad.slice(-8).forEach((l) => console.log('  ' + l.replace(/apikey=[^&"\s]+/gi, 'apikey=hidden').slice(0, 400)));
  } catch (e) { console.log('\n(no log file read: ' + e.code + ')'); }
})();
