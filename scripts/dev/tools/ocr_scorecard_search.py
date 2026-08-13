import re, json, subprocess, urllib.parse, sys, os, time, unicodedata
exec(open('/tmp/ocr_pipeline.py').read().split('def fetch')[0])

def fetch(url, path):
    subprocess.run(["curl","-sL","-A",UA,"-m","45","-o",path,url],capture_output=True,text=True)
    return os.path.exists(path) and os.path.getsize(path)>3000

def norm(s):
    s=unicodedata.normalize('NFD',s); s=''.join(c for c in s if unicodedata.category(c)!='Mn')
    return re.sub(r'[^a-z0-9]+',' ', s.lower().replace('đ','d'))

STOP={'golf','club','course','resort','country','san','the','and','links','villas','city','vietnam','viet','nam','brg','star'}
GENERIC={'blue','stone','grand','sands','valley','hill','hills','royal','legend','ocean','lake','king','queen','green','pine','sky','west','east','north','south','diamond','golden','glory','montana','paradise','phoenix','dragon','champion'}
VN=re.compile(r'\.vn\b|vietnam|viet-?nam', re.I)

def ident(club):
    return [w for w in norm(club).split() if w not in STOP and len(w)>2]

def owns(url, title, toks):
    """Every identity token, not most of them. 'Blue' alone matched East Potomac
    in Washington DC; 'grand' matched a course in Australia. And when the only
    tokens left are words every club uses, the source has to be Vietnamese as
    well, or the name proves nothing."""
    hay = norm(url) + ' ' + norm(title)
    if not toks or not all(t in hay for t in toks):
        return False
    if all(t in GENERIC for t in toks) and not VN.search(url):
        return False
    return True

def candidates3(club):
    toks=ident(club); seen,out=set(),[]
    for q in [f"{club} golf scorecard", f"scorecard {club} golf", f"{club} bảng điểm sân golf",
              f"{club} score card par index"]:
        for r in ddg_images(q):
            u=r['image']; t=r.get('title','')
            if u in seen: continue
            if not (CARD.search(u) or CARD.search(t)): continue
            if not owns(u,t,toks): continue
            w,h=r.get('width') or 0, r.get('height') or 0
            if w<500 or h<200: continue
            seen.add(u); out.append((w*h,u,t))
    return sorted(out,reverse=True)[:5], toks

tok=token()
todo=[l.strip().split('|') for l in open('/tmp/todo.txt') if l.strip()]
seen=set(); targets=[]
for cid,fac,cname in todo:
    if fac in seen: continue
    seen.add(fac); targets.append((cid,fac,cname))
results={}
for cid,fac,cname in targets:
    club=re.sub(r'\s*\(.*?\)','',fac)
    cands,toks=candidates3(club)
    if not cands:
        print(f"{fac:42s} no image proving it is this club  (tokens={toks})", flush=True); continue
    got=None
    for _,u,t in cands:
        p="/tmp/card3.img"
        if os.path.exists(p): os.remove(p)
        if not fetch(u,p): continue
        d=ocr(tok,cid,p,tries=4)
        if d: got=(u,d); break
    if got:
        u,d=got
        print(f"{fac:42s} OK par={d['checks']['parTotalRead']} {u[:78]}", flush=True)
        results[cid]={'facility':fac,'course':cname,'url':u,'data':d}
    else:
        print(f"{fac:42s} {len(cands)} own image(s), none agreed with printed total", flush=True)
    time.sleep(0.4)
json.dump(results, open('/tmp/ocr_results3.json','w'), ensure_ascii=False)
print(f"\naccepted: {len(results)}")
