const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
(async () => {
  const pages = JSON.parse(fs.readFileSync(path.join(__dirname, 'icons.json')));
  const out = path.join(__dirname, '../../images/music/icons'); fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 48, height: 48 } });
  for (const [n, html] of Object.entries(pages)) { await p.setContent(html); await p.screenshot({ path: path.join(out, n + '.png'), omitBackground: true }); }
  await b.close();
})();
