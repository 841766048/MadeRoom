from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[2]
p=root/'ios/MadeRoom/Resources/EditorialAssets'
im=Image.open(root/'design/high-fidelity-images/05-community-v3.png')
m=json.loads((p/'manifest.json').read_text())
for n,b in [('comment-post',(428,167,493,226)),('comment-tessa',(429,295,474,339)),('comment-maya',(467,390,500,423)),('comment-elena',(430,522,474,566)),('comment-priya',(430,738,474,782))]:
 im.crop(b).save(p/(n+'.png'))
 m=[x for x in m if x['name']!=n]
 m.append(dict(name=n,source='05-community-v3.png',boardBox=b,role='Content photo only'))
(p/'manifest.json').write_text(json.dumps(m,indent=2))
