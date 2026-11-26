// Runs inside the overseerr container: retry every Failed request. Prints no keys.
const fs = require('fs');
const http = require('http');
let f = process.env.SETTINGS || '/app/config/settings.json';
if (!fs.existsSync(f)) f = '/config/settings.json';
const key = JSON.parse(fs.readFileSync(f, 'utf8')).main.apiKey;
const port = process.env.OPORT || 5055;
function call(method, p) {
  return new Promise((res) => {
    const r = http.request({ host: '127.0.0.1', port: port, path: p, method: method, headers: { 'X-Api-Key': key } }, (x) => {
      let b = ''; x.on('data', (d) => (b += d)); x.on('end', () => { let j = null; try { j = JSON.parse(b); } catch (e) {} res({ code: x.statusCode, j: j }); });
    });
    r.on('error', (e) => res({ code: 'ERR ' + e.code, j: null }));
    r.end();
  });
}
(async () => {
  const list = await call('GET', '/api/v1/request?take=100&filter=failed&sort=added');
  if (list.code !== 200) { console.log('Could not list requests: ' + list.code); return; }
  const rs = list.j.results || [];
  console.log('Failed requests: ' + rs.length);
  for (const q of rs) {
    const r = await call('POST', '/api/v1/request/' + q.id + '/retry');
    const t = (q.media && (q.media.tmdbId)) || '';
    console.log('  request ' + q.id + ' (' + q.type + ' tmdb ' + t + '): retry -> ' + r.code);
  }
  console.log('Check the TV Requests room in a minute; it should show Waiting or Downloading instead of Failed.');
})();
