"""Render the Street GT's perforated rear panel and stamped registration plate."""
from pathlib import Path
from math import cos, sin, pi
from PIL import Image, ImageDraw, ImageFont
out=Path(__file__).resolve().parents[1]/"NitroDrift/Assets.scnassets/Vehicles/Finishes"
im=Image.new("RGB",(512,128),(51,56,61)); d=ImageDraw.Draw(im)
for row,y in enumerate(range(-8,140,11)):
    for x in range(-14,531,14):
        cx=x+(row%2)*7
        pts=[(cx+6.2*cos(k*pi/3+pi/2),y+6.2*sin(k*pi/3+pi/2)) for k in range(6)]
        d.polygon(pts,fill=(20,24,28))
        d.line(pts[:4],fill=(73,80,83),width=1)
im.save(out/"StreetGT-honeycomb.jpg",quality=93)
im=Image.new("RGB",(512,136),(206,215,216));d=ImageDraw.Draw(im)
d.rounded_rectangle((3,3,508,132),radius=12,outline=(62,78,87),width=6)
# Original condensed block lettering keeps the plate independent of a local font installation.
glyph={"N":["10001","11001","10101","10011","10001"],"I":["111","010","010","010","111"],
       "T":["11111","00100","00100","00100","00100"],"R":["11110","10001","11110","10100","10010"],
       "O":["01110","10001","10001","10001","01110"],"D":["11110","10001","10001","10001","11110"],
       "F":["11111","10000","11110","10000","10000"]}
lettering="NITRO DRIFT";scale=8
width=sum((len(glyph[c][0])+1 if c!=" " else 2)*scale for c in lettering)-scale
left=(512-width)//2
for c in lettering:
    if c==" ":left+=2*scale;continue
    for j,row in enumerate(glyph[c]):
        for i,pixel in enumerate(row):
            if pixel=="1":d.rectangle((left+i*scale,41+j*10,left+(i+1)*scale-1,50+j*10),fill=(28,47,66))
    left+=(len(glyph[c][0])+1)*scale
for x in (19,493):
    for y in (17,119):
        d.ellipse((x-4,y-4,x+4,y+4),fill=(77,85,83));d.line((x-2,y,x+2,y),fill=(173,179,175))
im.save(out/"StreetGT-registration.png",optimize=True)
