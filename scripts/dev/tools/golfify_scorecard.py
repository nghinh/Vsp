import re, html, subprocess, json, time

def fetch(slug):
    p=subprocess.run(["curl","-s","-A","Mozilla/5.0","-m","40","https://www.golfify.io/courses/"+slug],
                     capture_output=True,text=True)
    t=re.sub(r'<style.*?</style>','',p.stdout,flags=re.S); t=re.sub(r'<script.*?</script>','',t,flags=re.S)
    return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',t)))

def parse(slug):
    t=fetch(slug); i=t.find('Full Scorecard')
    if i<0: return None
    seg=t[i:]
    m=re.search(r'Hole\s+(.*?)\s+1\s+\d', seg)
    if not m: return None
    hdr=re.sub(r'\(\s*F\s*\)','F', m.group(1)); cols=hdr.split()
    if 'SI' not in cols or 'Par' not in cols: return None
    si_i=cols.index('SI')+1; par_i=cols.index('Par')+1; ncol=len(cols)+1
    toks=seg[m.start():].split()
    rows=[]; k=0; want=1
    while k < len(toks) and want <= 18:
        if toks[k]==str(want) and k+ncol<=len(toks):
            chunk=toks[k:k+ncol]
            try:
                vals=[int(x) for x in chunk]
                rows.append(vals); want+=1; k+=ncol; continue
            except ValueError:
                pass
        k+=1
    if not rows: return None
    return {'slug':slug,'cols':cols,'tee':cols[0],
            'rows':[[r[0], r[1], r[si_i], r[par_i]] for r in rows]}

SLUGS="""hoiana-shores-golf-club bana-hills-golf-course montgomerie-links-vietnam
laguna-lang-golf-club the-bluffs-ho-tram-strip dalat-palace-club thanh-lanh-valley-golf-and-resort
legend-danang-golf-resort-nicklaus west-lakes-golf-club phoenix-golf-resort-dragon""".split()
out={}
for s in SLUGS:
    try: r=parse(s)
    except Exception: r=None
    if r:
        n=len(r['rows']); par=[x[3] for x in r['rows']]; si=[x[2] for x in r['rows']]; yd=[x[1] for x in r['rows']]
        flat=len(set(par))==1 and len(set(yd))==1
        ok=[x[0] for x in r['rows']]==list(range(1,n+1)) and len(set(si))==n and 1<=min(si) and max(si)<=2*n \
           and all(3<=p<=6 for p in par) and all(80<=y<=800 for y in yd)
        st='PLACEHOLDER' if flat else ('OK' if ok else 'CHECK')
        print(f"{s:40s} {n}h par={sum(par)} yd={sum(yd)} tee={r['tee']:12s} {st}")
        if st=='OK': out[s]=r
    else: print(f"{s:40s} FAILED")
    time.sleep(0.3)
json.dump(out, open('/tmp/gf_cards3.json','w'))
print('\nusable:', len(out))
