#!/usr/bin/env python3
"""Bundle redistributable CC0 racing vehicles as native USDZ scene assets.

Sources are listed on Grab3D's model pages and distributed as CC0 1.0.
Downloaded once in GitHub Actions and saved with project; runtime is offline.
"""
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import zipfile, io, tempfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "NitroDrift" / "Assets.scnassets" / "Vehicles"
MODELS = {
    "StreetGT": ("sports-car", "https://grab3d.com/dl/sports-car/sports-car.usdz"),
    "ApexR": ("1990s-sports-car", "https://grab3d.com/dl/1990s-sports-car/1990s-sports-car.usdz"),
    "VortexX": ("1980s-sports-car", "https://grab3d.com/dl/1980s-sports-car/1980s-sports-car.usdz"),
}

for local_name, (slug, url) in MODELS.items():
    target = DEST / (local_name + ".usdz")
    if target.is_file() and target.stat().st_size > 70_000:
        print("Already bundled:", target.name)
        continue
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "grab3d.com" or not parsed.path.endswith(".usdz"):
        raise SystemExit("Untrusted model URL")
    request = Request(url, headers={"User-Agent": "Mozilla/5.0 (NitroDrift CC0 asset installer)"})
    with urlopen(request, timeout=50) as response:
        payload = response.read(16 * 1024 * 1024 + 1)
        content_type = response.headers.get("Content-Type", "")
    if len(payload) > 16 * 1024 * 1024 or len(payload) < 70_000:
        raise SystemExit("Invalid model size for " + slug)
    if not zipfile.is_zipfile(io.BytesIO(payload)):
        raise SystemExit("Not a USDZ ZIP archive: " + slug)
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        members = archive.namelist()
        if not any(name.endswith((".usdc", ".usd", ".usda")) for name in members):
            raise SystemExit("USDZ contains no USD scene: " + slug)
        if any("../" in name or name.startswith("/") for name in members):
            raise SystemExit("USDZ contains suspicious member names")
    DEST.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=DEST, delete=False) as tmp:
        tmp.write(payload)
        temp_file = Path(tmp.name)
    temp_file.replace(target)
    print("Bundled:", target.name, len(payload), "bytes", content_type)
print("CC0 sports car models bundled successfully.")
