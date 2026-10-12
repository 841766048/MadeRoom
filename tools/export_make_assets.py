from PIL import Image
from pathlib import Path
import json
p=Path(__file__).resolve().parents[2]
o=p/'ios/MadeRoom/Resources/EditorialAssets'
items={'make-shelf':('02-making-v2.png',(370,100,503,220)), 'make-weave':('02-making-v2.png',(204,295,306,399)), 'make-clay':('02-making-v2.png',(204,428,306,531)), 'make-vase':('02-making-v2.png',(372,560,489,647)), 'make-empty':('10-states-v2.png',(54,181,359,421)), 'make-basket':('10-states-v2.png',(38,704,144,780)), 'make-flowers':('10-states-v2.png',(158,704,264,780)), 'make-pillow':('10-states-v2.png',(279,704,369,780))}
m=json.loads((o/'manifest.json').read_text())
for n,(f,b) in items.items():
 Image.open(p/'design/high-fidelity-images'/f).crop(b).save(o/(n+'.png'))
 m=[a for a in m if a['name']!=n];m.append(dict(name=n,source=f,boardBox=b,role='Independent content photograph or illustration; no UI controls'))
(o/'manifest.json').write_text(json.dumps(m,indent=2))
