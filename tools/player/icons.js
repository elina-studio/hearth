// Renders the player's line icons (white on transparent, 64x64) for Roku Posters (tint with blendColor).
// Same drawings as the pause screen mockups (mockups/player/src/gen_pause.py). Usage: node icons.js <outdir>
const {chromium}=require('playwright');
const I={
"play": "<path d=\"M8 5l11 7-11 7z\"/>",
"pause": "<path d=\"M8 5v14M16 5v14\"/>",
"back10": "<path d=\"M4 12a8 8 0 1 0 2.5-5.8\"/><path d=\"M4 4v4h4\"/><text x=\"12\" y=\"15.2\" font-size=\"7.5\" text-anchor=\"middle\" stroke-width=\"0\" fill=\"currentColor\" font-family=\"Arial\" font-weight=\"700\">10</text>",
"fwd30": "<path d=\"M20 12a8 8 0 1 1-2.5-5.8\"/><path d=\"M20 4v4h-4\"/><text x=\"12\" y=\"15.2\" font-size=\"7.5\" text-anchor=\"middle\" stroke-width=\"0\" fill=\"currentColor\" font-family=\"Arial\" font-weight=\"700\">30</text>",
"cc": "<rect x=\"3\" y=\"5\" width=\"18\" height=\"14\" rx=\"3\"/><path d=\"M10 10.5a2 2 0 1 0 0 3M16 10.5a2 2 0 1 0 0 3\"/>",
"search": "<circle cx=\"11\" cy=\"11\" r=\"6.5\"/><path d=\"M16 16l5 5\"/>",
"audio": "<path d=\"M4 9h4l5-4v14l-5-4H4z\"/><path d=\"M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12\"/>",
"chap": "<path d=\"M6 3h12v18l-6-4-6 4z\"/>",
"eps": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"5\" rx=\"1.5\"/><rect x=\"3\" y=\"11\" width=\"18\" height=\"5\" rx=\"1.5\"/><path d=\"M5 20h14\"/>",
"qual": "<path d=\"M4 7h10M18 7h2M4 17h4M12 17h8\"/><circle cx=\"16\" cy=\"7\" r=\"2\"/><circle cx=\"10\" cy=\"17\" r=\"2\"/>",
"info": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 11v6M12 7.5v.5\"/>",
"moon": "<path d=\"M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z\"/>",
"check": "<path d=\"M5 12.5l4.5 4.5L19 7.5\"/>",
"eye": "<path d=\"M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6z\"/><circle cx=\"12\" cy=\"12\" r=\"2.6\"/><path d=\"M15 15.5l3 3\"/>",
"aa": "<path d=\"M3 18l5-12 5 12M5 14h6\"/><path d=\"M15 12.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM20 11v7\"/>",
"timing": "<circle cx=\"12\" cy=\"13\" r=\"7.5\"/><path d=\"M12 9v4l2.5 2M9.5 3h5\"/>",
"next": "<path d=\"M6 5l9 7-9 7z\"/><path d=\"M18 5v14\"/>",
"restart": "<path d=\"M4 12a8 8 0 1 0 2.5-5.8\"/><path d=\"M4 4v4h4\"/>",
"film": "<rect x=\"3\" y=\"5\" width=\"18\" height=\"14\" rx=\"2\"/><path d=\"M7 5v14M17 5v14M3 9h4M3 15h4M17 9h4M17 15h4\"/>",
"star": "<path d=\"M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6-5.3-3-5.3 3 1.2-6L3.4 9.3l6-.7z\"/>",
"dots": "<circle cx=\"5\" cy=\"12\" r=\"1.2\"/><circle cx=\"12\" cy=\"12\" r=\"1.2\"/><circle cx=\"19\" cy=\"12\" r=\"1.2\"/>",
"clock": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 7v5l3 2\"/>"
};
(async()=>{const out=process.argv[2];const b=await chromium.launch();const p=await b.newPage({viewport:{width:64,height:64}});
for(const [n,d] of Object.entries(I)){
 await p.setContent(`<html><body style="margin:0;background:transparent;color:#fff"><svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${d.replace('fill="currentColor"','fill="#fff"')}</svg></body></html>`);
 await p.screenshot({path:`${out}/${n}.png`,omitBackground:true});}
// scrub head: a gold leaf-diamond with a soft glow (48x48)
await p.setViewportSize({width:48,height:48});
await p.setContent(`<html><body style="margin:0;background:transparent"><div style="position:absolute;left:13px;top:13px;width:22px;height:22px;background:#FFE7A0;transform:rotate(45deg);border-radius:2px 11px 2px 11px;box-shadow:0 0 12px #F0A03C"></div></body></html>`);
await p.screenshot({path:`${out}/scrub-head.png`,omitBackground:true});
await b.close()})();
