"""Bake panel-only paint, deck pinstripes and brake emission into the existing CC0 car UVs."""
import argparse, io, json, zipfile
from pathlib import Path
import numpy as np
from PIL import Image

VEHICLES=Path(__file__).resolve().parents[1]/"NitroDrift/Assets.scnassets/Vehicles"
COLORS={"electricBlue":(39,97,146),"inferno":(208,61,48),"pearl":(206,214,217),
        "venom":(105,160,77),"midnight":(54,66,83),"violet":(143,97,181)}


def body_mesh(file):
    from pxr import Usd, UsdGeom
    stage=Usd.Stage.Open(str(file))
    mesh=next(p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh) and p.GetName().endswith("_body"))
    names=("points","faceVertexIndices","primvars:st","primvars:st:indices")
    return {name:np.asarray(mesh.GetAttribute(name).Get()) for name in names}


def raster(mesh, n):
    points=np.asarray(mesh["points"],dtype=np.float32)
    uv=np.array(mesh["primvars:st"],dtype=np.float32)
    uv[:,1]=1-uv[:,1]
    uv=uv*n-.5
    pos=np.full((n,n,3),np.nan,dtype=np.float32)
    for inds,tex in zip(np.asarray(mesh["faceVertexIndices"]).reshape(-1,3),
                        np.asarray(mesh["primvars:st:indices"]).reshape(-1,3)):
        tri=uv[tex]
        lo=np.maximum(0,np.floor(tri.min(axis=0)).astype(int));hi=np.minimum(n-1,np.ceil(tri.max(axis=0)).astype(int))
        if lo[0]>hi[0] or lo[1]>hi[1]: continue
        a,b,c=tri;e=b-a;f=c-a;det=e[0]*f[1]-e[1]*f[0]
        if abs(det)<.0001: continue
        yy,xx=np.ogrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
        u=((xx-a[0])*f[1]-(yy-a[1])*f[0])/det
        v=((yy-a[1])*e[0]-(xx-a[0])*e[1])/det
        keep=(u>=-.0001)&(v>=-.0001)&(u+v<=1.0001)
        if not keep.any(): continue
        a,b,c=points[inds]
        view=pos[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
        view[keep]=a+u[keep,None]*(b-a)+v[keep,None]*(c-a)
    return pos


def bake(file,cache):
    if cache:
        mesh=json.loads((cache/f"nd-{file.stem}-mesh.json").read_text())
    else: mesh=body_mesh(file)
    with zipfile.ZipFile(file) as z:
        path=next(n for n in z.namelist() if "body" in n and "basecolor" in n)
        rgb=np.asarray(Image.open(io.BytesIO(z.read(path))).convert("RGB"),dtype=np.float32)
    n=rgb.shape[0]; r,g,b=rgb.transpose(2,0,1); x,y,z=raster(mesh,n).transpose(2,0,1)
    signal=g-r if file.stem=="ApexR" else r-g
    paint=np.clip((signal-(13 if file.stem=="ApexR" else 20))/28,0,1)
    # Retain chromatic lenses and the carbon, rubber, glazing and metal from the UV atlas.
    rear_lens=(y>1.50)&(z>.46)&(r>g*2.10)&(r>b*1.45)
    paint=np.where(rear_lens,0,paint)[...,None]
    clear=np.clip((r-g*1.55)/76,0,1)*rear_lens
    emission=np.stack([clear*240,clear*18,clear*10],axis=-1).astype("uint8")
    out=VEHICLES/"Finishes";out.mkdir(exist_ok=True)
    Image.fromarray(emission).save(out/f"{file.stem}-brakes.png",optimize=True)
    # Two tapered bands follow the actual deck/bonnet across UV seams.
    sweep=.46+.09*np.nan_to_num(y,nan=0)/2.2
    d=np.abs(np.abs(x)-sweep)
    stripe=np.where(np.isfinite(z)&(z>.72)&(np.abs(y)>.49),
                    np.clip((.027-d)*125,0,1)+np.clip((.009-np.abs(d-.06))*120,0,1),0)[...,None]
    luminance=.36*r+.50*g+.14*b
    reference=np.median(luminance[paint[:,:,0]>.8])
    light=np.clip(luminance/reference,.35,1.35)[...,None]
    for name,tint in COLORS.items():
        accent=np.array((34,48,63) if name=="pearl" else (202,214,218))
        finish_tint=np.array(tint,dtype=np.float32)
        if file.stem=="StreetGT":
            # Follow the rear bumper pressing and taper the sill accent along both doors.
            rear=np.clip((np.nan_to_num(y)-1.50)/.34,0,1)
            sill=np.clip((np.abs(np.nan_to_num(x))-.69)/.15,0,1)
            height=np.nan_to_num(z,nan=1.5)
            inset=np.maximum(rear*np.clip((.81-height)/.095,0,1),
                             sill*np.clip((.44-height)/.065,0,1))
            gunmetal=finish_tint*.22+np.array([7,11,17])
            finish_tint=finish_tint+(gunmetal-finish_tint)*inset[...,None]
        body=(finish_tint*(1-stripe)+accent*stripe)*light
        finish=rgb*(1-paint)+body*paint
        Image.fromarray(np.clip(finish,0,255).astype("uint8")).save(out/f"{file.stem}-{name}.jpg",quality=92,subsampling=0)
    print(file.stem,"body pixels",int((paint>.8).sum()),"illuminated lens pixels",int(rear_lens.sum()),flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--mesh-cache",type=Path);args=p.parse_args()
    for file in sorted(VEHICLES.glob("*.usdz")):bake(file,args.mesh_cache)
