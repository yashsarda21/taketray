// Captures TakeTray prototype screens (design/prototype, read-only) as 1080x2400 PNGs.
const {chromium}=require('./node_modules/playwright-core');
const out=process.argv[2];
require('fs').mkdirSync(out,{recursive:true});
const URL='file:///Users/sardap/Documents/github/reel-helper/design/prototype/index.html';
const STYLE='.ph{border-radius:0!important;box-shadow:none!important;outline:0!important}';
// The shipped app calls the first reel status "Collecting" (decisions D-08); the prototype still says "Recording".
const FIXTXT=()=>{const w=document.createTreeWalker(document.querySelector('#proto-phone')||document.body,NodeFilter.SHOW_TEXT);let n;while((n=w.nextNode())){if(/Recording/.test(n.nodeValue))n.nodeValue=n.nodeValue.replace(/Recording/g,'Collecting');}};
(async()=>{const b=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const p=await b.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:3});
// 1. welcome (chosen B · Tray), dark, from the screen-02 gallery
await p.goto(URL+'#screen-02');
await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(2500);
await p.addStyleTag({content:STYLE});
const phs=await p.$$('.view:not([hidden]) .ph');
await phs[1].scrollIntoViewIfNeeded();await p.waitForTimeout(300);
await phs[1].screenshot({path:`${out}/welcome-dark.png`});
// 2. live prototype, dark theme
await p.goto(URL+'#prototype');
await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(2500);
await p.addStyleTag({content:STYLE});
await p.click('#pf-rm');await p.click('[data-ptheme="dark"]');await p.waitForTimeout(800);
const ph=await p.$('#proto-phone');
await ph.scrollIntoViewIfNeeded();
const shot=async(n)=>{await p.waitForTimeout(900);await p.evaluate(FIXTXT);await ph.scrollIntoViewIfNeeded();await ph.screenshot({path:`${out}/${n}.png`});console.log('shot',n);};
await p.click('#proto-phone .navbar .it:has-text("Reels")');
await shot('home');
const rect=async(sel,txt)=>{const h=await p.evaluateHandle(([sel,txt])=>{const ph=document.querySelector('#proto-phone');const els=[...ph.querySelectorAll(sel)].filter(e=>!txt||e.textContent.includes(txt));return els[0]||null;},[sel,txt]);const e=h.asElement();if(!e)return null;const bb=await e.boundingBox();const pb=await ph.boundingBox();return {x:bb.x-pb.x,y:bb.y-pb.y,w:bb.width,h:bb.height};};
const rects={};
await p.click('#proto-phone .navbar .it:has-text("To tag")');
await shot('totag');
rects.sceneHeader=await rect('*','9:20–9:31 am');
rects.tiles=await rect('[data-a="playFrom"]','9:20 am');
rects.tagScene=await rect('[data-a="tagScene"]','');
rects.startTagging=await rect('[data-a="startTagging"]','');
// scroll To tag down a little for a second view
await p.click('#proto-phone [data-a="startTagging"]');
await shot('player-1');
rects.chipFood=await rect('.rchip','London Food');
rects.chipCine=await rect('.rchip','London Cinematic');
rects.same=await rect('.same','');
require('fs').writeFileSync(out+'/rects.json',JSON.stringify(rects,null,1));
// tag into London Food (chip)
const chip=async(name)=>{const c=await p.$(`#proto-phone .rchip:has-text("${name}")`);await c.click();};
await chip('London Food');
await shot('player-2-snack');
await p.waitForTimeout(3500);
await chip('London Cinematic');
await shot('player-3-snack');
await b.close();})();
