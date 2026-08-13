import re, json, subprocess, urllib.parse, sys, time, os
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"
API="https://vps-api.vnteki.com"

def token():
    r=subprocess.run(["curl","-s","-X","POST",f"{API}/auth/login","-H","Content-Type: application/json",
        "-d",'{"identifier":"admin@vsp.local","password":"Admin2026"}'],capture_output=True,text=True).stdout
    return json.loads(r)["accessToken"]

def ddg_images(q):
    qe=urllib.parse.quote(q)
    h=subprocess.run(["curl","-s","-A",UA,"-m","20",f"https://duckduckgo.com/?q={qe}&iax=images&ia=images"],capture_output=True,text=True).stdout
    m=re.search(r'vqd=([0-9-]+)',h)
    if not m: return []
    r=subprocess.run(["curl","-s","-A",UA,"-m","25","-H","Referer: https://duckduckgo.com/",
        f"https://duckduckgo.com/i.js?l=us-en&o=json&q={qe}&vqd={m.group(1)}&f=,,,&p=1"],capture_output=True,text=True).stdout
    try: return json.loads(r).get('results',[])
    except Exception: return []

CARD=re.compile(r'score.?card|bang.?diem|the.?diem', re.I)
def candidates(club):
    seen, out = set(), []
    for q in [f"{club} golf scorecard", f"scorecard {club} golf", f"{club} bảng điểm sân golf"]:
        for r in ddg_images(q):
            u=r['image']
            if u in seen: continue
            if not (CARD.search(u) or CARD.search(r.get('title',''))): continue
            w,h=r.get('width') or 0, r.get('height') or 0
            if w<500 or h<200: continue
            seen.add(u); out.append((w*h,u))
    return [u for _,u in sorted(out, reverse=True)][:5]

def ocr(tok, course_id, path, tries=5):
    best=None
    for _ in range(tries):
        r=subprocess.run(["curl","-s","-X","POST",f"{API}/courses/{course_id}/scorecard-corrections/extract",
            "-H",f"Authorization: Bearer {tok}","-F",f"image=@{path};type=image/jpeg"],capture_output=True,text=True).stdout
        try: d=json.loads(r)
        except Exception: continue
        c=d.get('checks') or {}
        if c.get('parTotalAgrees'):
            return d
        if best is None and d.get('holes'): best=d
    return None

def fetch(url, path):
    r=subprocess.run(["curl","-sL","-A",UA,"-m","40","-o",path,"-w","%{http_code} %{size_download}"],capture_output=True,text=True)
    # url passed separately to avoid shell parsing
    return r
