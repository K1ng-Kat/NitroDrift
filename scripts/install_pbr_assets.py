#!/usr/bin/env python3
"""Install CC0 PBR asphalt from official Poly Haven.
Only official metadata / CDN hosts, 1K JPEG/PNG textures and a 12MB cap.
"""
import argparse
import json
import pathlib
import tempfile
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "NitroDrift" / "Assets.scnassets" / "Surfaces"
API = "https://api.polyhaven.com/files/aerial_asphalt_01"
HOSTS = {"dl.polyhaven.org"}
USER_AGENT = "NitroDrift-Asset-Installer/1.0"
LIMIT = 12 * 1024 * 1024


def download(url, size=LIMIT):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=40) as response:
        if response.status != 200:
            raise RuntimeError("HTTP " + str(response.status))
        data = response.read(size + 1)
    if len(data) > size:
        raise RuntimeError("Download exceeds safety limit")
    return data


def entries(node, parents=()):
    if isinstance(node, list):
        for child in node:
            yield from entries(child, parents)
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            yield parents, node["url"]
        for name, child in node.items():
            if isinstance(child, (dict, list)):
                yield from entries(child, parents + (str(name).lower(),))


def pick(node):
    roles = {}
    for parent, url in entries(node):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in HOSTS:
            continue
        extension = pathlib.Path(parsed.path).suffix.lower()
        if extension not in (".jpg", ".png", ".jpeg"):
            continue
        fingerprint = " ".join(parent) + " " + parsed.path.lower()
        if "1k" not in fingerprint:
            continue
        if any(s in fingerprint for s in ("diffuse", "_diff_", "albedo", "color")):
            role = "diffuse"
        elif any(s in fingerprint for s in ("nor_gl", "normal", "norgl")):
            if "nor_dx" in fingerprint or "directx" in fingerprint:
                continue
            role = "normal"
        elif "rough" in fingerprint:
            role = "roughness"
        else:
            continue
        rank = (10 if extension in (".jpg", ".jpeg") else 0) + (5 if role == "normal" and "nor_gl" in fingerprint else 0)
        if role not in roles or rank > roles[role][0]:
            roles[role] = (rank, url, ".jpg" if extension == ".jpeg" else extension)
    return roles


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()
    try:
        assets = pick(json.loads(download(API, 3 * 1024 * 1024)))
        if set(assets) != {"diffuse", "normal", "roughness"}:
            raise RuntimeError("Official API did not return all three 1K maps: " + str(sorted(assets)))
        OUT.mkdir(parents=True, exist_ok=True)
        for role in ("diffuse", "normal", "roughness"):
            _, url, ext = assets[role]
            dest = OUT / ("asphalt_" + role + ext)
            if dest.is_file() and dest.stat().st_size > 2048:
                print("Already installed:", dest.name)
                continue
            blob = download(url)
            if not (blob.startswith(b"\xff\xd8\xff") or blob.startswith(b"\x89PNG\r\n\x1a\n")):
                raise RuntimeError("Downloaded file is not JPEG/PNG: " + role)
            with tempfile.NamedTemporaryFile(dir=OUT, delete=False) as file:
                file.write(blob)
                temporary = pathlib.Path(file.name)
            temporary.replace(dest)
            print("Installed:", dest.name, len(blob), "bytes")
        print("All three CC0 PBR road maps installed.")
    except Exception as exc:
        print("Asset installation failed:", exc)
        if args.strict:
            raise SystemExit(1)
        print("The game's procedural offline fallback remains available.")


if __name__ == "__main__":
    main()
