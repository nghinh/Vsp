import re, subprocess, json, time
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"
def get(u):
    return subprocess.run(["curl","-s","-A",UA,"-m","30",u],capture_output=True,text=True).stdout
root=get("https://www.golfsavers.com/vietnam")
regions=sorted({m for m in re.findall(r'href="(/vietnam/[a-z0-9-]+-golf-courses)"', root)})
print('regions:', len(regions), regions[:6])
courses=set()
for r in regions:
    h=get("https://www.golfsavers.com"+r)
    for m in re.findall(r'href="(/vietnam/[a-z0-9-]+-golf-courses/[a-z0-9-]+)"', h):
        courses.add(m)
    time.sleep(0.2)
print('course pages:', len(courses))
cards={}
for c in sorted(courses):
    h=get("https://www.golfsavers.com"+c)
    imgs=re.findall(r'(?:src|data-src|href)="([^"]*scorecard[^"]*\.(?:jpg|JPG|jpeg|png|PNG|webp))"', h)
    if imgs:
        u=imgs[0]
        if u.startswith('/'): u="https://www.golfsavers.com"+u
        cards[c]=u
    time.sleep(0.15)
json.dump(cards, open('/tmp/gs_cards.json','w'))
print('with scorecard image:', len(cards))
for k,v in sorted(cards.items())[:40]: print(f"  {k.split('/')[-1]:48s} {v[:70]}")
