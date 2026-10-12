from pathlib import Path
from PIL import Image
import json
p=Path(__file__).resolve().parents[2]
o=p/'ios/MadeRoom/Resources/EditorialAssets'
m=json.loads((o/'manifest.json').read_text())
for name,f,box in [('make-finished','03-finish-spaces-v1.png',(49,256,348,563)),('make-note','12-project-tools-v2.png',(51,292,357,392)),('make-edit','12-project-tools-v2.png',(447,111,771,240))]:
 Image.open(p/'design/high-fidelity-images'/f).crop(box).save(o/(name+'.png'))
 m=[a for a in m if a['name']!=name]
 m.append(dict(name=name,source=f,boardBox=box,role='Independent content photograph only'))
(o/'manifest.json').write_text(json.dumps(m,indent=2))
