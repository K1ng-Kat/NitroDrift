"""Reproject the sky from a Radiance HDR panorama to the six SceneKit background faces."""
import math
from pathlib import Path
import sys
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "NitroDrift/Assets.scnassets/Environment"


def read_hdr(file):
    with Path(file).open("rb") as f:
        while True:
            line=f.readline()
            if not line: raise ValueError("Missing Radiance dimensions")
            if line.startswith(b"-Y "): break
        _,height,_,width=line.split(); w,h=int(width),int(height)
        data=np.empty((h,w,4),dtype=np.uint8)
        for j in range(h):
            if f.read(4)!=bytes((2,2,w>>8,w&255)): raise ValueError("Expected scanline RLE")
            for c in range(4):
                i=0
                while i<w:
                    code=f.read(1)[0]; count=code-128 if code>128 else code
                    if not count or i+count>w: raise ValueError("Invalid run")
                    values=f.read(1 if code>128 else count)
                    data[j,i:i+count,c]=values[0] if code>128 else np.frombuffer(values,dtype=np.uint8)
                    i+=count
    return np.ldexp(data[:,:,:3].astype(np.float32)+.5,data[:,:,3:].astype(np.int16)-136)


def bake(src):
    image=read_hdr(src); height,width=image.shape[:2]
    u,v=np.meshgrid((np.arange(512)+.5)/256-1,(np.arange(512)+.5)/256-1)
    one=np.ones_like(u)
    faces=[("px",one,-v,-u),("nx",-one,-v,u),("py",u,one,v),
           ("ny",u,-one,-v),("pz",u,-v,one),("nz",-u,-v,-one)]
    for name,x,y,z in faces:
        elev=np.arcsin(y/np.sqrt(x*x+y*y+z*z))
        # Sample above the original tree line, fading to city haze near the water.
        latitude=np.deg2rad(46)+np.maximum(0,elev)*(44/90)
        sx=(np.arctan2(z,x)/(2*math.pi)+.27)%1*width
        sy=np.clip((.5-latitude/math.pi)*height,0,height-1)
        ix=np.floor(sx).astype(int); iy=np.floor(sy).astype(int)
        fx=(sx-ix)[:,:,None]; fy=(sy-iy)[:,:,None]
        nextx=(ix+1)%width; nexty=np.minimum(iy+1,height-1)
        hdr=(image[iy,ix]*(1-fx)+image[iy,nextx]*fx)*(1-fy)+(image[nexty,ix]*(1-fx)+image[nexty,nextx]*fx)*fy
        brightness=hdr @ np.array([.2126,.7152,.0722])
        cloud=np.clip((np.log2(np.maximum(.01,brightness))+.9)/3.4,0,1)[:,:,None]
        t=np.clip(np.sin(elev),0,1)[:,:,None]
        clear=(1-t)*np.array([179,211,226])+t*np.array([61,132,191])
        mist=np.clip(np.sin(np.maximum(elev,0))*6.2,0,1)[:,:,None]
        sky=clear+(np.array([239,245,244])-clear)*cloud*mist*.83
        Image.fromarray(np.uint8(np.clip(sky,0,255))).save(OUT/f"day-sky-{name}.jpg",quality=93,subsampling=0)


if __name__=="__main__": bake(sys.argv[1])
