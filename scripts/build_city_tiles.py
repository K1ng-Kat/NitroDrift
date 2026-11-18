"""Build the Quayside architectural meshes in metres, Y up, with repeating facade UVs."""
from collections import defaultdict
from pathlib import Path
import math
import random
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parents[1] / "NitroDrift/Assets.scnassets/City"
COLORS = {
    "glass": (.16,.37,.53), "silverglass": (.38,.54,.61), "limestone": (.79,.73,.60),
    "slate": (.26,.32,.36), "steel": (.19,.24,.28), "brass": (.52,.36,.18),
    "trunk": (.38,.29,.19), "foliage": (.11,.33,.19), "leaflit": (.28,.47,.21),
    "water": (.045,.39,.40), "lamps": (.98,.83,.49)
}

def sub(a,b): return tuple(p-q for p,q in zip(a,b))
def add(a,b): return tuple(p+q for p,q in zip(a,b))
def scale(a,t): return tuple(p*t for p in a)
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return scale(a, 1/math.sqrt(sum(x*x for x in a)))
def f(value): return f"{value:.4f}".rstrip('0').rstrip('.') or "0"


class Model:
    def __init__(self):
        self.faces = defaultdict(list)

    def face(self, mat, verts, uv=None):
        normal = unit(cross(sub(verts[1],verts[0]),sub(verts[2],verts[0])))
        if uv is None: uv = [(p[0]/8,p[2]/8) for p in verts]
        vertices = [(p,normal,t) for p,t in zip(verts,uv)]
        for i in range(1,len(verts)-1):
            self.faces[mat].extend((vertices[0],vertices[i],vertices[i+1]))

    def prism(self, mat, ring, y0, y1, inset=1.0):
        # Ring is clockwise viewed from above; projected distances give continuous UVs.
        cx = sum(p[0] for p in ring)/len(ring)
        cz = sum(p[1] for p in ring)/len(ring)
        top = [(cx+(x-cx)*inset,y1,cz+(z-cz)*inset) for x,z in ring]
        bottom = [(x,y0,z) for x,z in ring]
        along = 0
        for i in range(len(ring)):
            j=(i+1)%len(ring)
            width=math.dist(ring[i],ring[j])
            self.face(mat,[bottom[i],top[i],top[j],bottom[j]],[(along/10,y0/12),(along/10,y1/12),((along+width)/10,y1/12),((along+width)/10,y0/12)])
            along+=width
        self.face(mat,list(reversed(top)))

    def box(self, mat, x,y,z,w,h,d):
        self.prism(mat,[(x-w/2,z-d/2),(x+w/2,z-d/2),(x+w/2,z+d/2),(x-w/2,z+d/2)],y-h/2,y+h/2)

    def beam(self, mat, a,b,width,depth=None):
        along=unit(sub(b,a))
        axis=(0,1,0) if abs(along[1])<.88 else (0,0,1)
        side=scale(unit(cross(along,axis)),width/2)
        up=scale(unit(cross(along,side)),(depth or width)/2)
        ends=[]
        for p in (a,b):
            ends.append([add(add(p,scale(side,s)),scale(up,t)) for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]])
        for i in range(4):
            j=(i+1)%4
            self.face(mat,[ends[0][i],ends[0][j],ends[1][j],ends[1][i]])
        self.face(mat,ends[1])
        self.face(mat,list(reversed(ends[0])))

    def save(self, name):
        def el(parent, tag, value=None, **attrs):
            e=ET.SubElement(parent,tag,attrs)
            if value is not None:e.text=value
            return e
        doc=ET.Element("COLLADA",xmlns="http://www.collada.org/2005/11/COLLADASchema",version="1.4.1")
        info=el(doc,"asset")
        for tag in ("created","modified"):el(info,tag,"2026-11-18T00:00:00Z")
        el(info,"unit",name="meter",meter="1");el(info,"up_axis","Y_UP")
        fx=el(doc,"library_effects");mats=el(doc,"library_materials");geos=el(doc,"library_geometries")
        stage=el(el(doc,"library_visual_scenes"),"visual_scene",id="city")
        for mat,flat in self.faces.items():
            effect=el(fx,"effect",id=mat+"FX")
            phong=el(el(el(effect,"profile_COMMON"),"technique",sid="common"),"phong")
            el(el(phong,"diffuse"),"color"," ".join(f(c) for c in COLORS[mat])+" 1")
            el(el(mats,"material",id=mat+"Mat",name=mat),"instance_effect",url="#"+mat+"FX")
            mesh=el(el(geos,"geometry",id=mat+"Mesh"),"mesh")
            data=list(dict.fromkeys(flat)); ids={v:i for i,v in enumerate(data)}
            for idx,channel,axes in [(0,"position","XYZ"),(1,"normal","XYZ"),(2,"uv","ST")]:
                sid=mat+channel
                source=el(mesh,"source",id=sid)
                el(source,"float_array"," ".join(f(c) for v in data for c in v[idx]),id=sid+"Data",count=str(len(data)*len(axes)))
                acc=el(el(source,"technique_common"),"accessor",source="#"+sid+"Data",count=str(len(data)),stride=str(len(axes)))
                for axis in axes:el(acc,"param",name=axis,type="float")
            el(el(mesh,"vertices",id=mat+"Verts"),"input",semantic="POSITION",source="#"+mat+"position")
            tri=el(mesh,"triangles",count=str(len(flat)//3),material=mat)
            # Channels share a single index because vertices are split at texture/normal seams.
            for semantic,target in [("VERTEX","Verts"),("NORMAL","normal"),("TEXCOORD","uv")]:
                attrs={"set":"0"} if semantic=="TEXCOORD" else {}
                el(tri,"input",semantic=semantic,source="#"+mat+target,offset="0",**attrs)
            el(tri,"p"," ".join(str(ids[v]) for v in flat))
            obj=el(stage,"node",id=mat+"Node",name=mat)
            bind=el(el(el(obj,"instance_geometry",url="#"+mat+"Mesh"),"bind_material"),"technique_common")
            el(bind,"instance_material",symbol=mat,target="#"+mat+"Mat")
        el(el(doc,"scene"),"instance_visual_scene",url="#city")
        OUT.mkdir(parents=True,exist_ok=True)
        ET.ElementTree(doc).write(OUT/(name+".dae"),encoding="utf-8",xml_declaration=True)
        print(name,sum(len(v)//3 for v in self.faces.values()),"triangles")


def footprint(x,z,w,d,kind):
    if kind==1:
        return [(x+.5*w*math.cos(a*math.pi/8),z+.5*d*math.sin(a*math.pi/8)) for a in range(16)]
    b=min(w,d)*(.20 if kind==2 else .065)
    return [(x-w/2+b,z-d/2),(x+w/2-b,z-d/2),(x+w/2,z-d/2+b),(x+w/2,z+d/2-b),
            (x+w/2-b,z+d/2),(x-w/2+b,z+d/2),(x-w/2,z+d/2-b),(x-w/2,z-d/2+b)]


def block(variant):
    m=Model()
    for i,(x,z) in enumerate([(-34,-39),(32,-39),(-31,39),(35,39)]):
        kind=(i+variant)%4
        w=(32,29,39,34)[kind];d=(29,33,27,31)[kind]
        floors=(18,32,12,25)[(i+variant*2)%4];height=5+floors*3.05
        base=footprint(x,z,w+5,d+4,kind)
        m.prism("limestone",base,0,.65);m.prism("glass",base,.65,4.7);m.prism("slate",base,4.7,5.1)
        # Setbacks and a chamfered curtain wall give buildings a distinct outline at speed.
        tiers=[(5,height,1.0)] if kind==1 else [(5,height*.62,1.0),(height*.62,height,.84)]
        for lo,hi,s in tiers:
            ring=footprint(x,z,w*s,d*s,kind)
            m.prism("silverglass" if kind==1 or kind==3 else "glass",ring,lo,hi)
            for floor in range(1,int((hi-lo)/3.05)+1,2 if kind in (0,1) else 1):
                y=lo+floor*3.05
                m.prism("limestone" if kind in (1,2) else "slate",footprint(x,z,w*s+.55,d*s+.55,kind),y-.14,y+.15)
            for px,pz in ring[::2 if kind==1 else 1]:
                m.box("slate",px,(lo+hi)/2,pz,.28,hi-lo,.28)
        m.prism("limestone",footprint(x,z,w*.76,d*.76,kind),height,height+1)
        m.prism("slate",footprint(x+1,z,w*.48,d*.43,kind),height+1,height+3.7,.90)
        if kind==1:
            m.beam("steel",(x,height+3.7,z),(x,height+15,z),.28)
        for side in (-1,1):
            for f in (-.36,-.19,0,.19,.36):
                m.box("limestone",x+w*f,2.6,z+side*(d/2+2.2),.43,4.0,.45)
            m.box("slate",x,4.43,z+side*(d/2+3.8),w*.68,.22,4.6)
    m.save("CityBlock"+str(variant))


def bridge():
    m=Model()
    for z in (-29,-46,-63,-80,-97,-114):
        arch=[]
        for k in range(25):
            t=k/24; theta=math.pi*(1-t)
            arch.append((14.45*math.cos(theta),5.9+8.4*math.sin(theta),z))
        for a,b in zip(arch,arch[1:]):
            m.beam("steel",a,b,.38,.64)
            m.beam("brass",add(a,(0,.31,0)),add(b,(0,.31,0)),.43,.09)
        if z!=-114:
            for idx in (3,8,12,16,21):
                a=arch[idx];b=add(a,(0,0,-17))
                m.beam("steel",a,b,.27,.31)
            for k in (4,15):
                m.beam("steel",arch[k],add(arch[k+5],(0,0,-17)),.14,.21)
                m.beam("steel",arch[k+5],add(arch[k],(0,0,-17)),.14,.21)
        for side in (-1,1):
            x=side*14.45
            tall=z in (-29,-114)
            h=11.3 if tall else 6.4
            m.box("limestone",x,.38,z,3.1,.76,3.4)
            m.box("limestone",x,h/2,z,2.3,h,2.6)
            for y in (1.1,h-.28,h+.08):m.box("slate" if y<2 else "limestone",x,y,z,2.75,.22,2.95)
            if tall:
                m.box("slate",x,h*.58,z+1.32,1.25,5.35,.10)
                for dx in (-.77,.77):m.box("brass",x+dx,h*.58,z+1.39,.09,5.8,.11)
                m.beam("brass",(x-.77,h*.58+2.9,z+1.39),(x,h*.58+3.76,z+1.39),.1,.1)
                m.beam("brass",(x,h*.58+3.76,z+1.39),(x+.77,h*.58+2.9,z+1.39),.1,.1)
    for side in (-1,1):
        x=side*12.95
        for za,zb in [(-136,-14),(14,62)]:
            bays=round((zb-za)/5.5); step=(zb-za)/bays
            m.box("limestone",x,.26,(za+zb)/2,.52,.52,zb-za)
            m.box("limestone",x,1.63,(za+zb)/2,.56,.22,zb-za)
            for k in range(bays+1):
                z=za+k*step
                m.box("limestone",x,.9,z,.63,1.8,.6)
                if k%4==0:
                    m.box("slate",x,1.94,z,.68,.14,.65)
                    m.beam("brass",(x,2,z),(x,2.65,z),.08)
                    m.box("lamps",x,2.79,z,.22,.29,.22)
                if k==bays:continue
                for j in range(5):
                    p=z+j*step/5;q=z+(j+1)*step/5
                    m.beam("steel",(x,.53,p),(x,1.51,q),.055)
                    m.beam("steel",(x,1.51,p),(x,.53,q),.055)
        # Continuous canal strips are inside blocks and below the promenade.
        m.box("water",side*76.3,.012,-75,123.4,.018,43)
        for z in (-97.4,-52.6):
            m.box("limestone",side*76.4,.53,z,122.2,1.06,.7)
            m.box("slate",side*76.4,1.13,z,122.2,.17,1.0)
    m.save("QuaysideBridge")


def palm():
    m=Model(); rng=random.Random(141)
    for k in range(13):
        y=k*.48; x=.012*k*k
        ring=footprint(x,0,.58-.016*k,.56-.015*k,1)
        m.prism("trunk",ring,y,y+.52,.93)
    tip=(.012*12*12,6.15,0)
    for k in range(13):
        a=k*2.400+rng.uniform(-.08,.08); length=rng.uniform(2.7,4.1)
        direction=(math.cos(a),0,math.sin(a)); sideways=(-direction[2],0,direction[0])
        def rib(t):
            return add(add(tip,scale(direction,t*length)),(0,2.2*math.sin(t*math.pi*.92)-1.5*t,0))
        for j in range(8):
            m.beam("leaflit",rib(j/8),rib((j+1)/8),.028)
        for j in range(1,18):
            t=j/19;p=rib(t);base=rib(t+.035)
            for side in (-1,1):
                wide=(.22+.62*math.sin(math.pi*t))*(1-.24*t)
                end=add(add(add(base,scale(sideways,side*wide)),scale(direction,wide*.54)),(0,-wide*.65,0))
                mid=add(add(p,scale(sideways,side*wide*.47)),(0,.08,0))
                m.face("leaflit" if (k+j)%4==0 else "foliage",[p,mid,end])
                m.face("foliage",[mid,base,end])
    m.save("QuaysidePalm")


if __name__=="__main__":
    for variant in range(3):block(variant)
    bridge()
    palm()
