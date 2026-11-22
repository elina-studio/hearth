const {chromium}=require('playwright');const fs=require('fs');
const DIR=__dirname, html=fs.readFileSync(DIR+'/m.html','utf8');
const i0=html.indexOf('const n=(t,s)=>'), i1=html.indexOf('const outs=');
const FN=html.slice(i0,i1);
const FPS=12, N=96;
(async()=>{
const b=await chromium.launch();const p=await b.newPage({viewport:{width:1920,height:1080}});
await p.clock.install();
await p.goto('file://'+DIR+'/m.html');
await p.evaluate(()=>document.fonts.ready);
await p.addStyleTag({content:'*{animation:none!important;transition:none!important}'});
await p.evaluate(FN=>{window.__fl=new Function(FN+';return flame;')();
  const s=document.querySelector('svg.splash'),mini=document.querySelector('svg.mini');document.body.innerHTML='';document.body.appendChild(s);document.body.appendChild(mini);
  document.body.style.cssText='margin:0;background:transparent;overflow:hidden';s.style.cssText='display:block;width:1920px;height:1080px';
  mini.style.cssText='position:absolute;left:0;top:0;height:144px;width:auto;display:none';
},FN);
const q=(sel)=>`document.querySelectorAll('svg.splash ${sel}')`;
const vis=async(map)=>p.evaluate(map=>{for(const [sel,v] of Object.entries(map))document.querySelectorAll(sel).forEach(e=>e.style.visibility=v?'visible':'hidden');},map);
const S='svg.splash ';
const all={[S+'rect[fill="url(#bgg)"]']:0,[S+'.sway']:0,[S+'#comets']:0,[S+'#quote']:0,[S+'#qorn']:0};
const box=async sel=>p.evaluate(sel=>{const r=document.querySelector(sel).getBoundingClientRect();return {x:Math.floor(r.x),y:Math.floor(r.y),w:Math.ceil(r.width)+2,h:Math.ceil(r.height)+2}},sel);
const meta={};
// bg
await vis({...all,[S+'rect[fill="url(#bgg)"]']:1});
await p.screenshot({path:DIR+'/out/bg.png'});
// glow
await vis({...all,[S+'.sway']:1,[S+'.sway *']:0,[S+'.glow']:1});
let gb={x:960-260,y:281+0.8*340-260-40,w:520,h:600}; // generous; trimmed later
await p.screenshot({path:DIR+'/out/glow_raw.png',omitBackground:true});
// lantern (no glow, flame, sparks)
await vis({...all,[S+'.sway']:1,[S+'.sway *']:1,[S+'.glow']:0,[S+'.flame']:0,[S+'.spark']:0});
await p.screenshot({path:DIR+'/out/lantern_raw.png',omitBackground:true});
// flame frames
await vis({...all,[S+'.sway']:1,[S+'.sway *']:0,[S+'.flame']:1,[S+'.flame *']:1,[S+'.spark']:0});
const fr=await box(S+'.flame');
const clip={x:fr.x-30,y:fr.y-90,width:fr.w+60,height:fr.h+110};
meta.flameClip=clip;
for(let f=0;f<N;f++){
  await p.evaluate(t=>{const g=.6+.4*(.5+.5*Math.sin(t*.31+1)*Math.sin(t*.17+2));const o=__fl(t,g,1),c=__fl(t-.12,g,.55);
    document.querySelectorAll('svg.splash .fouter').forEach(e=>e.setAttribute('d',o));document.querySelectorAll('svg.splash .fcore').forEach(e=>e.setAttribute('d',c));},3+f/FPS);
  await p.screenshot({path:DIR+`/frames/${String(f).padStart(3,'0')}.png`,clip,omitBackground:true});
}
// scrolls
await vis({...all,[S+'#qorn']:1,[S+'#qorn *']:1});
await p.evaluate(()=>{const qo=document.getElementById('qorn');qo.classList.add('on');qo.style.opacity=1;
  document.getElementById('qL').setAttribute('transform','translate(400,400) rotate(6)');document.getElementById('qR').setAttribute('transform','translate(1400,400) scale(-1,1) rotate(6)');});
meta.qL=await box('#qL');meta.qR=await box('#qR');meta.qLanchor=[400,400];meta.qRanchor=[1400,400];
await p.screenshot({path:DIR+'/out/scrolls_raw.png',omitBackground:true});
// spark positions
meta.sparks=await p.evaluate(()=>[...document.querySelectorAll('svg.splash .spark')].map(e=>({cx:+e.getAttribute('cx'),cy:+e.getAttribute('cy'),r:+e.getAttribute('r'),style:e.getAttribute('style')})));
// mini mark
await p.evaluate(()=>{document.querySelector('svg.splash').style.cssText='position:absolute;left:2500px;top:0;width:1920px;height:1080px';const m=document.querySelector('svg.mini');m.style.display='block';});
const MS='svg.mini ';
await vis({[MS+'.flame']:0});
await p.screenshot({path:DIR+'/out/mini_raw.png',omitBackground:true,clip:{x:0,y:0,width:100,height:144}});
meta.miniBox=await box('svg.mini');
await vis({[MS+'*']:0,[MS+'.flame']:1,[MS+'.flame *']:1,[MS+'.spark']:0});
const mf=await box(MS+'.flame');
const mclip={x:Math.max(0,mf.x-6),y:Math.max(0,mf.y-14),width:mf.w+12,height:mf.h+18};meta.miniFlameClip=mclip;
for(let f=0;f<N;f++){
  await p.evaluate(t=>{const g=.6+.4*(.5+.5*Math.sin(t*.31+1)*Math.sin(t*.17+2));const o=__fl(t,g,1),c=__fl(t-.12,g,.55);
    document.querySelectorAll('svg.mini .fouter').forEach(e=>e.setAttribute('d',o));document.querySelectorAll('svg.mini .fcore').forEach(e=>e.setAttribute('d',c));},3+f/FPS);
  await p.screenshot({path:DIR+`/mframes/${String(f).padStart(3,'0')}.png`,clip:mclip,omitBackground:true});
}
fs.writeFileSync(DIR+'/out/meta.json',JSON.stringify(meta,null,1));
await b.close();})();
