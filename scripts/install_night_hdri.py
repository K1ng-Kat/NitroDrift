#!/usr/bin/env python3
"""Bundle a photographed, CC0 nighttime city lighting environment.

Poly Haven Shanghai Bund HDRI (author Greg Zaal). Downloads the official 1K
Radiance HDR through the API, tone maps into a small iOS-friendly JPEG.
The original high dynamic range EXR/HDR is not carried into the shipping JPEG.
"""
import json
import pathlib
import tempfile
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "NitroDrift" / "Assets.scnassets" / "Environment"
API = "https://api.polyhaven.com/files/shanghai_bund"


def read_url(url, cap=12 * 1024 * 1024):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ("api.polyhaven.com", "dl.polyhaven.org"):
        raise RuntimeError("Non-official HTTPS asset endpoint")
    request = urllib.request.Request(url, headers={"User-Agent": "NitroDrift-CC0-HDRI/1.0"})
    with urllib.request.urlopen(request, timeout=50) as response:
        payload = response.read(cap + 1)
    if len(payload) > cap:
        raise RuntimeError("HDRI exceeds maximum expected size")
    return payload


def walk(obj, keys=()):
    if isinstance(obj, dict):
        if isinstance(obj.get("url"), str):
            yield keys, obj["url"]
        for name, value in obj.items():
            if isinstance(value, (dict, list)):
                yield from walk(value, keys + (str(name).lower(),))
    elif isinstance(obj, list):
        for item in obj:
            yield from walk(item, keys)


def main():
    import cv2
    import numpy as np

    files = json.loads(read_url(API, 2 * 1024 * 1024))
    candidates = []
    for keys, url in walk(files):
        path = urllib.parse.urlparse(url).path.lower()
        if "1k" in " ".join(keys) + " " + path and path.endswith(".hdr"):
            candidates.append(url)
    if not candidates:
        raise RuntimeError("Official Poly Haven API has no 1K Radiance HDR")
    blob = read_url(candidates[0])
    if not (blob.startswith(b"#?RADIANCE") or blob.startswith(b"#?RGBE")):
        raise RuntimeError("Not a valid Radiance HDR header")

    with tempfile.NamedTemporaryFile(suffix=".hdr") as file:
        file.write(blob)
        file.flush()
        image = cv2.imread(file.name, cv2.IMREAD_UNCHANGED)
    if image is None or image.dtype != np.float32:
        raise RuntimeError("OpenCV could not decode Radiance HDR")
    image = np.nan_to_num(np.maximum(image, 0.0), nan=0.0, posinf=1.0, neginf=0.0)
    exposure = max(0.05, float(np.percentile(image, 99.4)))
    scaled = image / exposure * 1.65
    mapped = np.power(scaled / (1.0 + scaled), 1.0 / 2.2)
    rgb8 = np.uint8(np.clip(mapped * 255, 0, 255))

    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / "night_city.jpg"
    if not cv2.imwrite(str(dest), rgb8, [cv2.IMWRITE_JPEG_QUALITY, 92]):
        raise RuntimeError("Could not write JPG")
    print("Bundled Poly Haven Shanghai Bund CC0 environment:", dest.name,
          rgb8.shape[1], "x", rgb8.shape[0], dest.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
