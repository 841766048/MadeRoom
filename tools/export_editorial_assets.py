from pathlib import Path
from PIL import Image,ImageDraw
import json
p=Path(__file__).resolve().parents[2];d=p/'design/figma-import';o=p/'ios/MadeRoom/Resources/EditorialAssets';r={s['id']:s for s in json.loads((d/'regions.json').read_text())}
assets={'room-hero':('D01',[4,107,336,192]),'weave':('D04',[3,81,337,266]),'reading-room':('C03',[4,123,335,316]),'space-reading':('S01',[18,172,291,214]),'space-entry':('S01',[18,472,291,176]),'pottery':('D01',[16,396,84,68]),'weaving':('D01',[131,396,78,66]),'plant':('D01',[248,396,76,67]),'maker':('C03',[17,490,35,36]),'studio':('D04',[21,600,78,77]),'cotton':('D04',[24,744,62,57]),'yarn':('D04',[106,744,64,57]),'dowel':('D04',[190,744,61,57]),'scissors':('D04',[274,744,62,57])}
assets.update({'knot-hands':('M04',[20,150,298,280]),'weaving-maker':('C08',[1,77,337,165]),'challenge-shelf':('C09',[1,198,337,263])})
assets.update({
 'profile-cover':('P01',[3,109,327,184]),'profile-avatar':('P01',[15,299,103,103]),
 'profile-mug':('P01',[15,548,95,102]),'profile-pillow':('P01',[119,548,95,102]),'profile-daisies':('P01',[224,548,94,102]),
 'profile-hanging-plant':('P01',[15,657,95,113]),'profile-bowls':('P01',[119,657,95,113]),'profile-flowers':('P01',[224,657,94,113]),
 'saved-reading':('P02',[16,180,300,117]),'saved-weekend':('P02',[16,450,300,113]),
 'saved-books':('P02',[25,354,68,66]),'saved-mug':('P02',[103,354,63,66]),'saved-lamp':('P02',[176,354,62,66]),'saved-plant':('P02',[248,354,66,66]),
 'saved-plate':('P02',[25,622,67,70]),'saved-crochet':('P02',[103,622,64,70]),'saved-blue-mug':('P02',[177,622,64,70]),'saved-fabric':('P02',[250,622,65,70]),
 'activity-lena':('P03',[16,180,51,51]),'activity-tessa':('P03',[16,295,51,51]),'activity-yuna':('P03',[16,547,51,51]),'activity-marisol':('P03',[16,725,51,51]),
 'activity-mug':('P03',[249,181,49,51]),'activity-space':('P03',[244,382,54,60]),'activity-plant':('P03',[244,548,54,55]),'activity-flowers':('P03',[247,727,51,50]),
 'profile-edit-avatar':('P04',[94,164,146,146])
})
manifest=[]
for name,(sid,b) in assets.items():
 s=r[sid];x,y,w,h=s['sourceBox'];bx,by,bw,bh=b;im=Image.open(p/'design/high-fidelity-images'/s['board']).crop((x+bx,y+by,x+bx+bw,y+by+bh)).convert('RGB');
 if name == 'profile-edit-avatar':
  im=im.convert('RGBA');mask=Image.new('L',im.size,255);ImageDraw.Draw(mask).ellipse((97,88,147,138),fill=0);im.putalpha(mask)
 im.save(o/(name+'.png'));manifest.append({'name':name,'role':'Editorial photograph or illustration only; no interface controls','source':s['board'],'screen':sid,'box':b})
(o/'manifest.json').write_text(json.dumps(manifest,indent=2))
canvas=Image.new('RGB',(800,((len(assets)+3)//4)*170),'#eeeeee');draw=ImageDraw.Draw(canvas)
for i,name in enumerate(assets):
 im=Image.open(o/(name+'.png'));im.thumbnail((185,145));xx=(i%4)*200;yy=(i//4)*170;canvas.paste(im,(xx,yy+18));draw.text((xx+2,yy+2),name,fill='black')
canvas.save(p/'ios/docs/editorial-assets-audit.png')
