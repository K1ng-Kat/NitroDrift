"""Author a repeating four-storey curtain wall and a matched night-light mask."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
import random

out=Path(__file__).resolve().parents[1]/"NitroDrift/Assets.scnassets/City"
rng=random.Random(81013)
im=Image.new("RGB",(512,512))
night=Image.new("RGB",im.size)
draw,glow=ImageDraw.Draw(im),ImageDraw.Draw(night)
for floor in range(4):
    y=floor*128
    for bay in range(5):
        x=round(bay*512/5); stop=round((bay+1)*512/5)
        tint=rng.randint(-12,12); blind=rng.choice((0,10,24,40,62))
        for dy in range(124):
            grad=math.sin(math.pi*dy/124)*15+dy*.18
            rgb=tuple(round(c+tint+grad) for c in (61,96,117))
            draw.line((x+2,y+dy,stop-2,y+dy),fill=rgb)
        draw.rectangle((x+4,y+68,stop-5,y+70),fill=(68,87,94))
        if blind:
            draw.rectangle((x+5,y+4,stop-5,y+blind),fill=(118+tint,137+tint,139+tint))
            for k in range(8,blind,4):
                draw.line((x+6,y+k,stop-6,y+k),fill=(97+tint,122+tint,130+tint))
        for shift in (0,1):
            draw.line((x+shift,y,x+shift, y+125),fill=(47,60,67))
        draw.line((x+3,y+3,x+3,y+124),fill=(157,177,184))
        if rng.random()<.45:
            glow.rectangle((x+6,y+6,stop-7,y+114),fill=rng.choice(((174,145,96),(130,150,155),(92,99,102))))
            glow.rectangle((x+8,y+85,stop-8,y+114),fill=(57,50,43))
            glow.line((x+43,y+7,x+43,y+114),fill=(32,36,38),width=2)
    draw.rectangle((0,y+120,511,y+127),fill=(52,64,69))
    draw.line((0,y+122,511,y+122),fill=(134,145,146))
im.save(out/"facade-day.jpg",quality=93,subsampling=0)
night.save(out/"facade-lit.png",optimize=True)
