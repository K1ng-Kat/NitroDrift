#!/bin/bash
set -euo pipefail
# Xcode Run and Release exports both install the same offline city.
pack="${ND_ROAD_PACK:-}"
if [[ -z "$pack" ]]; then
    pack="$(bash "$SRCROOT/scripts/prepare_road_pack.sh")"
fi
dest="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/RoadPack"
mkdir -p "$dest"
python3 - "$pack" "$dest" <<'PY'
from pathlib import Path
import shutil, sys, struct
source,target=map(Path,sys.argv[1:])
w,h=1024,5120
mips=[]
while True:
    mips.append(((w+3)//4)*((h+3)//4)*16)
    if w==h==1: break
    w,h=max(1,w//2),max(1,h//2)
header=struct.pack("<4sIIII",b"NDR1",1,1024,5120,len(mips))
size=len(header)+sum(mips)*2
for axis in ("ns","ew"):
    for road in range(7):
        for span in range(6):
            path=source/f"{axis}-{road}-{span}.ndroad"
            with path.open("rb") as f:
                if f.read(len(header))!=header or path.stat().st_size!=size:
                    raise ValueError(f"Invalid road texture {path}")
            out=target/path.name
            if not out.exists() or (out.stat().st_mtime_ns,out.stat().st_size)!=(path.stat().st_mtime_ns,size):
                shutil.copy2(path,out)
assert 84*size>=1024**3
print(f"Bundled 84 roads ({84*size:,} bytes)")
PY
