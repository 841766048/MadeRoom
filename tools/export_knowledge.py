"""Export the original editorial copy without changing user-authored state."""
import json, re, hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'content'
OUT.mkdir(exist_ok=True)
if (OUT/'image-manifest.json').exists():
    raise SystemExit('Export already exists. Refusing to overwrite IDs or verified cloud mappings.')
def save(name, value):
    (OUT/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')
def strings(source):
    return re.findall(r'"((?:[^"\\]|\\.)*)"', source)
files=['DiscoverScreens.swift','SearchDesignScreen.swift','CommunityScreens.swift','MakingScreens.swift']
archive=[]
for filename in files:
    for line_no,line in enumerate((ROOT/'MadeRoom/UI'/filename).read_text().splitlines(),1):
        texts=[s.replace('\\n','\n') for s in strings(line) if re.search(r'[A-Za-z]{2} ',s) and '\\(' not in s]
        if texts: archive.append({'sourceFile':filename,'line':line_no,'texts':texts})
items=[
 ('woven-wall-hanging','Woven wall hanging','A modern texture for any space.','weave','tutorial',90),
 ('clay-catchall','Clay catchall','A small piece, a calmer day.','pottery','idea',None),
 ('woven-storage-baskets','Woven storage baskets','Simple, useful, beautiful.','search-baskets','idea',120),
 ('weaving-basics','Weaving basics','Learn the fundamentals at home.','search-basics','idea',60),
 ('woven-placemats','Woven placemats','A weekend make for your table.','search-placemats','idea',180),
 ('softer-reading-corner','A softer reading corner','Cozy textures, natural materials and handmade details to help you slow down and feel at home.','space-reading','collection',None),
 ('woven-reading-corner','My woven reading corner','A cozy corner made brighter with a handwoven throw. This simple weave completely changed the feel of my reading nook.','reading-room','inspiration',None),
 ('one-shelf-handmade','One shelf, handmade','Create a handmade piece and style it on a shelf in your home. Pottery, a weave, a candle — anything you make.','challenge-shelf','challenge',None)
]
records=[]
for id,title,summary,asset,kind,minutes in items:
    records.append(dict(id=id,title=title,summary=summary,language='en',kind=kind,estimatedMinutes=minutes,imageIds=[asset],materials=[],steps=[],tips=[],sources=[]))
records[0].update(materials=['Cotton rope','Wool yarn','Wooden dowel','Scissors'],steps=['Cut your cords','Prepare the dowel','Tie the first row','Add more rows','Trim the fringe','Finish and hang'],tips=['Keep each knot loose enough to adjust. Check the row before tightening, then trim the fringe after hanging.'])
save('knowledge-existing.json',dict(schemaVersion=1,language='en',items=records,originalCopyArchive=archive))
source=(ROOT/'MadeRoom/UI/CommentsDesignScreen.swift').read_text()
comments=[]
for m in re.finditer(r'commentRow\(id: "([^"]+)", name: "([^"]+)", asset: "([^"]+)", age: "([^"]+)", text: "([^"]+)", likes: (\d+)(, author: true)?\)',source):
    id,name,asset,age,text,likes,author=m.groups()
    comments.append(dict(id=id,knowledgeId='woven-reading-corner',parentId=id[5:] if author else None,authorDisplayName=name,authorUid=None,text=text,language='en',avatarImageId=asset,legacyAgeLabel=age,createdAt=None,seedLikeCount=int(likes),isDemo=True,syncStatus='local-only'))
save('comments-seed.json',dict(schemaVersion=1,comments=comments))
assets={}
for p in (ROOT/'MadeRoom/Resources/EditorialAssets').glob('*.png'):
    refs=[r['id'] for r in records if p.stem in r['imageIds']]
    assets[p.stem]=dict(id=p.stem,localPath=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),byteCount=p.stat().st_size,contentType='image/png',storagePath=f'editorial/v1/{p.stem}.png',knowledgeIds=refs,uploadStatus='pending',downloadURL=None)
save('image-manifest.json',dict(schemaVersion=1,projectId='made-room-20261009',bucket=None,images=list(assets.values())))
print(f'Exported {len(records)} existing records, {len(comments)} seed comments, {len(assets)} image mappings.')
