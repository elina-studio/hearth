// Render each SVG in a folder to PNG at its own size, keeping transparency.
//   node tools/ambiance/shot.js svg_dir png_dir
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const [src, out] = process.argv.slice(2);
  fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch();
  for (const f of fs.readdirSync(src).filter(f => f.endsWith('.svg'))) {
    const svg = fs.readFileSync(path.join(src, f), 'utf8');
    const [, w, h] = svg.match(/width="(\d+)" height="(\d+)"/);
    const p = await b.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await p.waitForTimeout(200);
    await p.screenshot({ path: path.join(out, f.replace('.svg', '.png')), omitBackground: true });
    await p.close();
  }
  await b.close();
})();
