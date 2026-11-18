#!/usr/bin/env python3
"""Bake the 84 mapped street segments into streamable, mipmapped ASTC surfaces."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
from pathlib import Path
import math
import os
import random
import struct
import subprocess
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SCAN = ROOT / "NitroDrift/Assets.scnassets/Surfaces"
WIDTH, HEIGHT = 1024, 5120
HEADER = struct.Struct("<4sIIII")
BICUBIC = Image.Resampling.BICUBIC


@lru_cache(maxsize=1)
def source_maps():
    color, normal, rough = (Image.open(SCAN / f"asphalt_{name}.jpg").copy()
                            for name in ("diffuse", "normal", "roughness"))
    return (color.convert("RGB"), normal.convert("RGB"), rough.convert("L"))


def repeat_image(image, size, offset):
    result = Image.new(image.mode, size)
    for y in range(-offset[1], size[1], image.height):
        for x in range(-offset[0], size[0], image.width):
            result.paste(image, (x, y))
    return result


def street_images(axis, road, span):
    seed = (axis * 42 + road * 6 + span + 1) * 7919
    rng = random.Random(seed)
    size = WIDTH, HEIGHT
    offset = rng.randrange(512), rng.randrange(512)
    density = rng.choice((342, 384, 415, 452))
    tiles = [im.resize((density, density), Image.Resampling.LANCZOS) for im in source_maps()]
    color, normal, rough = [repeat_image(im, size, offset) for im in tiles]
    # Two different aggregates in resurfaced runs. The same mask affects color,
    # surface relief and roughness so repairs remain legible in low-angle light.
    repairs = Image.new("L", size)
    patch = ImageDraw.Draw(repairs)
    for _ in range(rng.randint(3, 9)):
        x, y = rng.randrange(35, WIDTH-100), rng.randrange(80, HEIGHT-630)
        w, h = rng.randrange(40, 240), rng.randrange(85, 660)
        patch.polygon([(x,y+4), (x+w-10,y), (x+w,y+h-5), (x+3,y+h)], fill=rng.randrange(180,246))
    edge = ImageChops.subtract(repairs.filter(ImageFilter.MaxFilter(3)), repairs)
    patch_color = ImageEnhance.Brightness(ImageChops.offset(color, 149, 301)).enhance(rng.uniform(0.69,0.89))
    color.paste(patch_color, mask=repairs)
    normal.paste(ImageChops.offset(normal,149,301), mask=repairs)
    rough.paste(116, mask=repairs)
    color.paste((41,43,46), mask=edge)

    # Vehicle paths put polished strips along a pair of wheel tracks per lane.
    rubber = Image.new("L", (WIDTH, 1))
    rubber.putdata([int(38 * max(math.exp(-((x-track)/18)**2) for track in
                    (142,209,350,417,608,675,816,883))) for x in range(WIDTH)])
    rubber = rubber.resize(size)
    color.paste((32,33,36), mask=rubber)
    rough.paste(68, mask=rubber)

    seams = Image.new("L", size)
    sd = ImageDraw.Draw(seams)
    for _ in range(rng.randint(8,17)):
        x, y = rng.randint(25, WIDTH-25), rng.randrange(HEIGHT-200)
        points = [(x,y)]
        for _ in range(rng.randint(6,18)):
            x += rng.randint(-12,14)
            y += rng.randint(3,17)
            points.append((x,y))
        sd.line(points, fill=rng.randrange(85,143), width=rng.choice([1,2,3]))
    color.paste((23,26,29), mask=seams)
    rough.paste(72, mask=seams)

    # All longitudinal dimensions are in metres over the 126 m between junctions.
    def col(m): return round((m+12)*WIDTH/24)
    def row(m): return round(m*HEIGHT/126)
    paint = Image.new("L", size)
    yd = ImageDraw.Draw(paint)
    for x in (-0.16, 0.16):
        yd.rectangle((col(x-.067), row(3), col(x+.067), row(123)), fill=226)
    grain = ImageOps.grayscale(color).point(lambda p: min(255, max(40, (p-35)*3+140)))
    yellow = ImageChops.multiply(paint, grain)
    color.paste((235,180,55), mask=yellow)
    white = Image.new("L", size)
    wd = ImageDraw.Draw(white)
    for x in (-10.9, 10.9):
        wd.rectangle((col(x-.07),row(2.5),col(x+.07),row(123.5)), fill=210)
    for x in (-5.35, 5.35):
        for m in range(9,121,12):
            wd.rectangle((col(x-.08),row(m),col(x+.08),row(m+4.5)), fill=225)
    for m in (4,122):
        for stripe in range(-10,11,2):
            wd.rectangle((col(stripe-.34), row(m-.83), col(stripe+.34), row(m+.83)), fill=200)
    white = ImageChops.multiply(white, grain)
    color.paste((213,215,208), mask=white)
    all_paint = ImageChops.lighter(white, yellow)
    normal.paste((128,128,252), mask=all_paint)
    rough.paste(117, mask=all_paint)

    # Cast-iron service covers and slotted curb drains are located per street.
    cd, rd, nd = ImageDraw.Draw(color), ImageDraw.Draw(rough), ImageDraw.Draw(normal)
    for _ in range(rng.randint(2,4)):
        x, y = col(rng.choice((-8.0,-2.65,2.65,8.0))+rng.uniform(-.6,.6)), row(rng.uniform(9,117))
        for radius, tint in [(17,(116,111,99)),(15,(42,44,45)),(13,(80,80,76))]:
            cd.ellipse((x-radius,y-radius,x+radius,y+radius), fill=tint)
        nd.ellipse((x-16,y-16,x+16,y+16),fill=(128,128,255),outline=(139,106,251),width=2)
        rd.ellipse((x-16,y-16,x+16,y+16),fill=95)
        for k in range(-8,9,4):
            cd.line((x+k-4,y-7,x+k+4,y+7), fill=(125,121,109),width=1)
            cd.line((x+k+4,y-7,x+k-4,y+7), fill=(46,47,43),width=1)
    for m in range(12,125,27):
        for x in (col(-11.5),col(11.5)):
            y=row(m+rng.uniform(-2,2))
            cd.rectangle((x-7,y-17,x+7,y+17),fill=(98,98,89),outline=(44,45,45))
            rd.rectangle((x-7,y-17,x+7,y+17),fill=80)
            nd.rectangle((x-7,y-17,x+7,y+17),fill=(128,128,255))
            for k in range(-13,14,4):
                cd.line((x-5,y+k,x+5,y+k),fill=(32,34,36),width=2)
    normal.putalpha(rough)
    return color, normal


def levels():
    w,h=WIDTH,HEIGHT
    while True:
        yield w,h
        if w==h==1: return
        w,h=max(1,w//2),max(1,h//2)


LEVELS = tuple(levels())
FILE_SIZE = HEADER.size + 2*sum(((w+3)//4)*((h+3)//4)*16 for w,h in LEVELS)


def bake(job, out, encoder, threads):
    axis, road, span = job
    destination = out / f"{'ns' if axis==0 else 'ew'}-{road}-{span}.ndroad"
    header = HEADER.pack(b"NDR1",1,WIDTH,HEIGHT,len(LEVELS))
    if destination.exists() and destination.stat().st_size==FILE_SIZE:
        with destination.open("rb") as f:
            if f.read(HEADER.size)==header: return
    with tempfile.TemporaryDirectory(dir=out) as work:
        temp = Path(work)
        color, surface = street_images(*job)
        with (temp/"street").open("wb") as stream:
            stream.write(header)
            for w,h in LEVELS:
                for image, mode in ((color,"-cs"),(surface,"-cl")):
                    # TGA writes RGBA without reassociating the roughness channel.
                    image.save(temp/"in.tga", format="TGA")
                    subprocess.run([encoder,mode,str(temp/"in.tga"),str(temp/"out.astc"),
                                    "4x4","-fastest","-j",str(threads),"-silent"],check=True)
                    encoded=(temp/"out.astc").read_bytes()
                    assert encoded[:4]==b'\x13\xab\xa1\x5c' and len(encoded)-16==((w+3)//4)*((h+3)//4)*16
                    stream.write(encoded[16:])
                if w>1 or h>1:
                    dims=(max(1,w//2),max(1,h//2))
                    color=color.resize(dims,Image.Resampling.BOX)
                    # Each data channel is independent, including roughness.
                    surface=Image.merge("RGBA",[channel.resize(dims,Image.Resampling.BOX) for channel in surface.split()])
        assert (temp/"street").stat().st_size==FILE_SIZE
        os.replace(temp/"street", destination)
        print(destination.name, flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output",type=Path)
    parser.add_argument("--encoder",default="astcenc")
    parser.add_argument("--workers",type=int,default=2)
    parser.add_argument("--threads",type=int,default=2)
    parser.add_argument("--sample",action="store_true")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    jobs=[(axis,road,span) for axis in range(2) for road in range(7) for span in range(6)]
    if args.sample: jobs=[(0,3,3)]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        list(pool.map(lambda job:bake(job,args.output,args.encoder,args.threads),jobs))
    paths=[args.output/f"{'ns' if a==0 else 'ew'}-{r}-{s}.ndroad" for a,r,s in jobs]
    size=sum(p.stat().st_size for p in paths)
    assert size==len(jobs)*FILE_SIZE
    print(f"{len(jobs)} streets, {size:,} bytes",flush=True)


if __name__=="__main__": main()
