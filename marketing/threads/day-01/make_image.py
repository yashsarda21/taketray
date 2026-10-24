import json, random, sys
R='/Users/sardap/Documents/github/reel-helper'
T=f'file://{R}/app/assets/sample/thumbs/'
d=json.load(open(f'{R}/app/assets/sample/sample_data.json'))
clips=[c for c in d['clips'] if c['orient']=='v']
by={k:[c for c in clips if k in c['reels']] for k in ['r1','r2','r3']}
random.seed(7)
pool=[c for c in clips if set(c['reels'])&{'r1','r2','r3'}]
random.shuffle(pool)
grid=pool[:18]
def dur(s): return f"{s//60}:{s%60:02d}"
cells=''.join(f'<div class="cell"><img src="{T}{c["id"]}.jpg"><span>{dur(c["dur"])}</span></div>' for c in grid)
icon=open(f'{R}/design/handoff/icons/tray/preview.svg').read()
trays=[('r1','London Food'),('r2','London Cinematic'),('r3','Day 1 Vlog')]
def tray(k,name):
    cs=by[k][:3]; rot=[-10,0,9]; x=[16,66,116]
    imgs=''.join(f'<img src="{T}{c["id"]}.jpg" style="left:{x[i]}px;transform:rotate({rot[i]}deg);z-index:{[1,3,2][i]}">' for i,c in enumerate(cs))
    return f'<div class="tray"><div class="stand">{imgs}<div class="base"></div></div><b>{name}</b><small>{len(by[k])} clips</small></div>'
html=f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:J;src:url(file://{R}/app/assets/fonts/PlusJakartaSans-Variable.ttf);font-weight:200 800}}
*{{box-sizing:border-box;margin:0}}
body{{width:1080px;height:1350px;overflow:hidden;background:#0E0F12;font-family:J,sans-serif;color:#F1F2F6;position:relative;padding:76px 72px 0}}
.kick{{display:flex;align-items:center;gap:14px;font-size:24px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#9AA3B2}}
.kick i{{width:13px;height:13px;border-radius:50%;background:#FF5A4E;box-shadow:0 0 0 6px rgba(255,90,78,.18)}}
h1{{margin-top:22px;font-size:66px;line-height:1.08;font-weight:800;letter-spacing:-2.4px}}
h1 em{{font-style:normal;color:#FAA800}}
.roll{{position:relative;margin-top:44px}}
.lbl{{display:flex;justify-content:space-between;font-size:22px;font-weight:700;color:#7E8796;margin-bottom:14px;letter-spacing:.3px}}
.grid{{display:grid;grid-template-columns:repeat(6,1fr);gap:6px;border-radius:22px;overflow:hidden;
  -webkit-mask-image:linear-gradient(#000 55%,transparent 100%)}}
.cell{{position:relative;aspect-ratio:1/1;overflow:hidden;background:#1b1d22}}
.cell img{{width:100%;height:100%;object-fit:cover;display:block}}
.cell span{{position:absolute;right:8px;bottom:7px;font-size:17px;font-weight:700;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.8)}}
.flow{{display:flex;align-items:center;gap:18px;margin:-34px 0 0;position:relative;z-index:2}}
.flow .chip{{display:flex;align-items:center;gap:12px;background:#FAA800;color:#1C1300;font-weight:800;font-size:25px;padding:14px 24px 14px 18px;border-radius:40px;box-shadow:0 12px 30px rgba(250,168,0,.25)}}
.flow .chip svg{{width:30px;height:30px}}
.flow .line{{flex:1;height:2px;background:repeating-linear-gradient(90deg,#FAA800 0 10px,transparent 10px 20px);opacity:.6}}
.trays{{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:34px}}
.tray{{background:#17191E;border:1px solid rgba(255,255,255,.07);border-radius:30px;padding:24px 22px 22px;display:flex;flex-direction:column}}
.stand{{position:relative;height:170px}}
.stand img{{position:absolute;bottom:34px;width:84px;height:132px;object-fit:cover;border-radius:12px;border:3px solid #0E0F12;transform-origin:50% 100%}}
.base{{position:absolute;left:0;right:0;bottom:0;height:54px;background:#FAA800;clip-path:polygon(0 0,100% 0,90% 100%,10% 100%);border-radius:6px;z-index:5}}
.base::after{{content:"";position:absolute;left:12%;right:12%;top:12px;height:3px;border-radius:2px;background:#C98400}}
.tray b{{margin-top:20px;font-size:27px;font-weight:800;letter-spacing:-.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
.tray small{{margin-top:4px;font-size:21px;font-weight:600;color:#8D96A5}}
.foot{{position:absolute;left:72px;right:72px;bottom:62px;display:flex;align-items:center;gap:18px}}
.foot .ic{{width:64px;height:64px;border-radius:18px;overflow:hidden}}
.foot .ic svg{{width:100%;height:100%;display:block}}
.foot b{{font-size:34px;font-weight:800;letter-spacing:-.8px}}
.foot span{{margin-left:auto;font-size:22px;font-weight:700;color:#9AA3B2;border:1.5px solid rgba(255,255,255,.14);padding:11px 20px;border-radius:30px}}
</style></head><body>
<div class="kick"><i></i>Building in public · Day 1</div>
<h1>100 clips from one trip.<br><em>Which one was for which reel?</em></h1>
<div class="roll">
<div class="lbl"><span>Camera roll · London</span><span>104 videos</span></div>
<div class="grid">{cells}</div>
</div>
<div class="flow"><div class="line"></div><div class="chip"><svg viewBox="0 0 24 24" fill="none" stroke="#1C1300" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11V6a2 2 0 0 1 4 0v5"/><path d="M13 10a2 2 0 0 1 4 0v3"/><path d="M17 12a2 2 0 0 1 4 0v3a7 7 0 0 1-7 7h-1.5a6 6 0 0 1-5-2.7L4.6 16a1.9 1.9 0 0 1 3-2.3L9 15"/></svg>One tap per clip</div><div class="line"></div></div>
<div class="trays">{''.join(tray(k,n) for k,n in trays)}</div>
<div class="foot"><div class="ic">{icon}</div><b>TakeTray</b><span>Android app · in the works</span></div>
</body></html>'''
open(sys.argv[1],'w').write(html)
