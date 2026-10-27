// Renders the Welcome (B · Tray) screen from the design hub at 3x: 1080 × 2400.
const {chromium}=require(process.argv[2]+'/node_modules/playwright-core');
const out=process.argv[3];
(async()=>{const b=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const p=await b.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:3,reducedMotion:'reduce'});
await p.goto('file:///Users/sardap/Documents/github/reel-helper/design/prototype/index.html#screen-02');
await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(3000);
await p.addStyleTag({content:'.ph{border-radius:0!important;box-shadow:none!important;outline:0!important}'});
const shot=async(i,name)=>{const e=(await p.$$('.view:not([hidden]) .ph'))[i];await e.scrollIntoViewIfNeeded();await p.waitForTimeout(200);
  const bb=await e.boundingBox();await p.screenshot({path:`${out}/${name}.png`,clip:{x:Math.round(bb.x),y:Math.round(bb.y),width:360,height:800}});};
await shot(0,'first-screen-light');await shot(1,'first-screen-dark');
await p.evaluate(()=>{const ph=document.querySelectorAll('.view:not([hidden]) .ph');for(const i of [0,1]){const h=ph[i].querySelector('.wel-body h1')||ph[i].querySelector('h1');h.innerHTML='Shoot now.<br>Sort later.';}});
await p.waitForTimeout(200);
await shot(1,'first-screen-dark-B');
await b.close();})();
