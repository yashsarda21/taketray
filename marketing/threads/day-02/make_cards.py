"""Day 2 post cards (1080 x 1350): the first screen, and the A/B headline question."""
# Usage: node render_screens.js <dir with node_modules/playwright-core> <this folder>, then python3 make_cards.py <this folder>,
# then screenshot card1.html / card2.html at 1080 x 1350.
import sys
R = '/Users/sardap/Documents/github/reel-helper'
D = sys.argv[1]
icon = open(f'{R}/design/handoff/icons/tray/preview.svg').read()
base = f'''@font-face{{font-family:J;src:url(file://{R}/packages/taketray_ui/fonts/PlusJakartaSans-Variable.ttf);font-weight:200 800}}
*{{box-sizing:border-box;margin:0}}
body{{width:1080px;height:1350px;overflow:hidden;background:#0E0F12;font-family:J,sans-serif;color:#F1F2F6;position:relative}}
.glow{{position:absolute;border-radius:50%;background:radial-gradient(closest-side,rgba(250,168,0,.20),transparent)}}
.kick{{display:flex;align-items:center;gap:14px;font-size:24px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#9AA3B2}}
.kick i{{width:13px;height:13px;border-radius:50%;background:#FF5A4E;box-shadow:0 0 0 6px rgba(255,90,78,.18)}}
.ph{{position:absolute;border-radius:54px;overflow:hidden;border:9px solid #24272E;background:#000;box-shadow:0 40px 90px rgba(0,0,0,.55),0 0 0 1px rgba(255,255,255,.06)}}
.ph img{{display:block;width:100%;height:100%}}
.brand{{display:flex;align-items:center;gap:16px}}
.brand .ic{{width:60px;height:60px;border-radius:17px;overflow:hidden}}
.brand .ic svg{{width:100%;height:100%;display:block}}
.brand b{{font-size:32px;font-weight:800;letter-spacing:-.8px}}'''

one = f'''<!doctype html><html><head><meta charset="utf-8"><style>{base}
.glow{{width:1000px;height:1000px;left:420px;top:240px}}
.txt{{position:absolute;left:72px;top:96px;width:400px}}
h1{{margin-top:30px;font-size:84px;line-height:1;font-weight:800;letter-spacing:-3px}}
h1 em{{font-style:normal;color:#FAA800}}
p{{margin-top:30px;font-size:29px;line-height:1.42;color:#B4B9C4;font-weight:500}}
.steps{{margin-top:44px;display:flex;flex-direction:column;gap:18px}}
.steps div{{display:flex;align-items:center;gap:16px;font-size:26px;font-weight:700}}
.steps span{{width:44px;height:44px;border-radius:50%;background:#1D2026;border:1px solid rgba(255,255,255,.1);display:grid;place-items:center;font-size:21px;color:#FAA800;flex:none}}
.ph{{width:536px;height:1182px;right:64px;top:84px}}
.brand{{position:absolute;left:72px;bottom:84px}}
</style></head><body><div class="glow"></div>
<div class="txt"><div class="kick"><i></i>Day 2</div>
<h1>The first<br><em>screen.</em></h1>
<p>What you see the moment you open TakeTray.</p>
<div class="steps"><div><span>1</span>Film as usual</div><div><span>2</span>Clips land in the tray</div><div><span>3</span>Tap each into a reel</div></div></div>
<div class="ph"><img src="file://{D}/first-screen-dark.png"></div>
<div class="brand"><div class="ic">{icon}</div><b>TakeTray</b></div>
</body></html>'''

ab = f'''<!doctype html><html><head><meta charset="utf-8"><style>{base}
.glow{{width:1200px;height:900px;left:-60px;top:420px}}
.top{{position:absolute;left:64px;right:64px;top:84px}}
h1{{margin-top:24px;font-size:64px;line-height:1.08;font-weight:800;letter-spacing:-2.3px}}
h1 em{{font-style:normal;color:#FAA800}}
.ph{{width:440px;height:978px;top:318px}}
.a{{left:64px}} .b{{right:64px}}
.lab{{position:absolute;top:288px;z-index:3;width:64px;height:64px;border-radius:50%;background:#FAA800;color:#1C1300;display:grid;place-items:center;font-size:32px;font-weight:800;box-shadow:0 0 0 8px #0E0F12}}
.la{{left:252px}} .lb{{right:252px}}
</style></head><body><div class="glow"></div>
<div class="top"><div class="kick"><i></i>Day 2 · Help me pick</div>
<h1>Which line makes you<br>tap <em>Get started</em>?</h1></div>
<div class="lab la">A</div><div class="lab lb">B</div>
<div class="ph a"><img src="file://{D}/first-screen-dark.png"></div>
<div class="ph b"><img src="file://{D}/first-screen-dark-B.png"></div>
</body></html>'''

open(f'{D}/card1.html', 'w').write(one)
open(f'{D}/card2.html', 'w').write(ab)
