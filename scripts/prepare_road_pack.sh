#!/bin/bash
# Build once per revision of the scanned source maps and baking recipe.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cache="${ND_ART_CACHE:-${HOME}/Library/Caches/NitroDriftArt}"
encoder_rev=30aabb3f42406df45a910d8496f9bee17eeba9bb
fingerprint="$(cat "$root/scripts/bake_roads.py" "$root"/NitroDrift/Assets.scnassets/Surfaces/asphalt_*.jpg | shasum -a 256 | cut -c1-24)"
pack="$cache/roads-v1-$fingerprint"
mkdir -p "$pack"
if [[ ! -f "$pack/.complete" ]]; then
    tools="$cache/tools-$encoder_rev"
    mkdir -p "$tools"
    if [[ ! -x "$tools/astcenc" ]]; then
        if [[ ! -d "$tools/src/.git" ]]; then
            git clone --quiet --depth 1 --branch 5.3.0 https://github.com/ARM-software/astc-encoder.git "$tools/src" >&2
        fi
        [[ "$(git -C "$tools/src" rev-parse HEAD)" == "$encoder_rev" ]]
        src="$tools/src/Source"
        sed -e 's/@astcencoder_VERSION@/5.3.0/g' -e 's/@astcencoder_YEAR@/2025/g' \
            "$src/astcenccli_version.h.in" > "$tools/astcenccli_version.h"
        case "$(uname -m)" in
            arm64|aarch64) simd=(-DASTCENC_NEON=1 -DASTCENC_SSE=0 -DASTCENC_AVX=0) ;;
            *) simd=(-msse4.1 -mpopcnt -DASTCENC_SSE=41 -DASTCENC_AVX=0 -DASTCENC_NEON=0) ;;
        esac
        # Compile for the build host, including when Xcode sets an iPhone SDK.
        (unset SDKROOT MACOSX_DEPLOYMENT_TARGET IPHONEOS_DEPLOYMENT_TARGET
         /usr/bin/c++ -O3 -std=c++14 -ffp-contract=off -pthread "${simd[@]}" -DASTCENC_SVE=0 \
             -I"$tools" -I"$src" "$src"/astcenc*.cpp -o "$tools/astcenc.new")
        mv "$tools/astcenc.new" "$tools/astcenc"
    fi
    if [[ ! -x "$tools/python/bin/python3" ]]; then python3 -m venv "$tools/python"; fi
    if ! "$tools/python/bin/python3" -c 'import PIL' >/dev/null 2>&1; then
        "$tools/python/bin/python3" -m pip install 'Pillow==11.3.0' >&2
    fi
    "$tools/python/bin/python3" "$root/scripts/bake_roads.py" "$pack" --encoder "$tools/astcenc" \
        --workers "${ND_BAKE_WORKERS:-2}" --threads "${ND_BAKE_THREADS:-2}" >&2
    touch "$pack/.complete"
fi
echo "$pack"
