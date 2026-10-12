"""Recreate the deploy-only directory from verified Hosting assets; no private data."""
from pathlib import Path
import hashlib,json,urllib.request,concurrent.futures
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'content/image-manifest.json').read_text())
assert m['projectId']=='made-room-20261009'
def stage(im):
 if im['uploadStatus']!='verified': return
 assert im['downloadURL'].startswith('https://made-room-20261009.web.app/editorial/')
 target=root/'.firebase-public'/im['hostingPath']
 assert '..' not in Path(im['hostingPath']).parts
 data=target.read_bytes() if target.exists() else urllib.request.urlopen(im['downloadURL'],timeout=60).read()
 assert hashlib.sha256(data).hexdigest()==im['sha256']
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(stage,m['images']))
print('Public editorial assets staged and hash-checked. No comments or user data included.')

# Publish only the image lookup fields used by the app, never local source paths.
catalog=root/'.firebase-public/catalog'
catalog.mkdir(parents=True,exist_ok=True)
(catalog/'image-manifest.json').write_text(json.dumps({'images':[{k:im[k] for k in ['id','sha256','downloadURL']} for im in m['images'] if im['uploadStatus']=='verified']},ensure_ascii=False))
