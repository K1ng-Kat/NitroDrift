"""Check mesh references, bounds, normals, UVs and drive-through bridge clearance."""
from pathlib import Path
import math
import xml.etree.ElementTree as ET

NS={"c":"http://www.collada.org/2005/11/COLLADASchema"}
folder=Path(__file__).resolve().parents[1]/"NitroDrift/Assets.scnassets/City"
for name in ("CityBlock0","CityBlock1","CityBlock2","QuaysideBridge","QuaysidePalm"):
    root=ET.parse(folder/(name+".dae")).getroot()
    ids=[e.get("id") for e in root.iter() if e.get("id")]
    assert len(ids)==len(set(ids))
    for e in root.iter():
        for attr in ("url","target","source"):
            ref=e.get(attr,"")
            if ref.startswith("#"):assert ref[1:] in ids,ref
    total=0
    for mesh in root.findall(".//c:mesh",NS):
        channels={}
        for source in mesh.findall("c:source",NS):
            arr=source.find("c:float_array",NS); a=list(map(float,arr.text.split()))
            acc=source.find("c:technique_common/c:accessor",NS)
            assert len(a)==int(arr.get("count"))==int(acc.get("count"))*int(acc.get("stride"))
            assert all(math.isfinite(v) for v in a)
            channels[source.get("id")]=int(acc.get("count"))
            if source.get("id").endswith("normal"):
                assert all(abs(sum(t*t for t in a[k:k+3])-1)<.001 for k in range(0,len(a),3))
            if not source.get("id").endswith("position"):continue
            for x,y,z in zip(a[::3],a[1::3],a[2::3]):
                if name.startswith("CityBlock"): assert max(abs(x),abs(z))<=62 and y>=0
                if name=="QuaysideBridge" and abs(x)<=10.9: assert y>=4.7
        tri=mesh.find("c:triangles",NS);ix=list(map(int,tri.find("c:p",NS).text.split()))
        assert len(ix)==int(tri.get("count"))*3
        assert set(channels.values())=={next(iter(channels.values()))}
        assert 0<=min(ix)<=max(ix)<next(iter(channels.values()))
        total+=int(tri.get("count"))
    assert total>0
    print(name,total)
