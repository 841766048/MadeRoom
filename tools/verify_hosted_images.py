"""Verify every hosted image before removing only its local runtime copy."""
import argparse, concurrent.futures, hashlib, json, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'content/image-manifest.json'
m=json.loads(p.read_text())
def verify(im):
    if im['id'].startswith('auth-'): return im
    url=im['downloadURL']
    if not url.startswith('https://made-room-20261009.web.app/editorial/'): raise ValueError(url)
    with urllib.request.urlopen(url,timeout=60) as response:
        data=response.read()
        assert response.status==200
        assert response.headers.get_content_type()=='image/png'
    assert hashlib.sha256(data).hexdigest()==im['sha256'], im['id']
    im['uploadStatus']='verified'
    return im
args=argparse.ArgumentParser();args.add_argument('--remove-runtime-copies',action='store_true');opt=args.parse_args()
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    verified=list(pool.map(verify,m['images']))
m['images']=verified;p.write_text(json.dumps(m,indent=2)+'\n')
if opt.remove_runtime_copies:
    for im in verified:
        if im['uploadStatus']!='verified': continue
        local=ROOT/im['localPath']
        assert local.parent==ROOT/'MadeRoom/Resources/EditorialAssets'
        if local.exists():
            assert hashlib.sha256(local.read_bytes()).hexdigest()==im['sha256']
            local.unlink()
        staged=ROOT/'.firebase-public'/im['hostingPath']
        if staged.exists(): staged.unlink()
print('Verified',sum(i['uploadStatus']=='verified' for i in verified),'hosted images.')
