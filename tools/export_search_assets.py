from PIL import Image
from pathlib import Path
import json
p=Path(__file__).resolve().parents[2]
o=p/'ios/MadeRoom/Resources/EditorialAssets'
im=Image.open(p/'design/high-fidelity-images/01-discover-v1.png')
m=json.loads((o/'manifest.json').read_text())
for name,box in [('search-wall',(420,204,525,290)),('search-baskets',(420,309,525,390)),('search-basics',(420,407,525,496)),('search-placemats',(420,516,525,599))]:
 im.crop(box).save(o/(name+'.png'))
 m=[x for x in m if x['name']!=name]
 m.append(dict(name=name,source='01-discover-v1.png',boardBox=box,role='Independent content photo only'))
(o/'manifest.json').write_text(json.dumps(m,indent=2))
