#!/bin/bash
set -euo pipefail
app="$1"
out="$2"
mkdir -p "$out"
device="$(xcrun simctl list devices available --json | python3 -c '
import json,sys
phones=[d for runtime,devices in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in devices if d.get("isAvailable") and "iPhone" in d["name"]]
if not phones: sys.exit("An installed iPhone runtime is required for rendering checks")
print(next((d for d in phones if d["state"]=="Booted"),phones[0])["udid"])')"
xcrun simctl boot "$device" 2>/dev/null || xcrun simctl bootstatus "$device" -b
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
bundle=com.kingkat.NitroDrift
container="$(xcrun simctl get_app_container "$device" "$bundle" data)"
wait_for() {
    for ((i=0;i<240;i++)); do
        [[ -s "$1" ]] && return 0
        sleep 1
    done
    echo "Timed out waiting for $1" >&2
    xcrun simctl spawn "$device" log show --last 2m --predicate 'process == "NitroDrift"' | tail -65 >&2 || true
    return 1
}
capture() {
    local quality="$1" weather="$2" auto="$3" stem="$4" car="$5"
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    rm -f "$container/tmp/nd-frame-ready" "$container/tmp/nd-cadence.json"
    xcrun simctl launch "$device" "$bundle" -streetWeather "$weather" -streetTimeOfDay Daylight \
        -graphicsQuality "$quality" -carStyle "$car" -easyDrive "$auto" -screenRefractionEnabled YES -ndAutomatedDrive
    if ! wait_for "$container/tmp/nd-frame-ready"; then
        xcrun simctl io "$device" screenshot "$out/$stem-timeout.png" || true
        [[ ! -f "$container/tmp/nd-cadence.json" ]] || cp "$container/tmp/nd-cadence.json" "$out/$stem.json"
        return 1
    fi
    xcrun simctl io "$device" screenshot "$out/$stem.png"
    wait_for "$container/tmp/nd-cadence.json"
    cp "$container/tmp/nd-cadence.json" "$out/$stem.json"
    python3 - "$out/$stem.json" "$auto" <<'PY_CHECK'
import json, sys
from pathlib import Path
r=json.loads(Path(sys.argv[1]).read_text())
print(r)
ratio=r["viewportWidth"]/r["viewportHeight"]
native=max(r["nativeWidth"],r["nativeHeight"])/min(r["nativeWidth"],r["nativeHeight"])
assert ratio>1 and abs(ratio/native-1)<.06, "Scene does not fill the landscape display"
assert r["easyDrive"]==(sys.argv[2]=="YES"), "Requested driving mode was not selected"
assert r["peakKPH"]>=5, "Vehicle did not accelerate with the selected controls"
assert r["wheelPivots"]==4 and r["authoredCity"] and r["residentStreets"]>0
PY_CHECK
    # simctl on a portrait-oriented host can store landscape contents sideways.
    local width height
    width="$(sips -g pixelWidth "$out/$stem.png" | awk '/pixelWidth:/ {print $2}')"
    height="$(sips -g pixelHeight "$out/$stem.png" | awk '/pixelHeight:/ {print $2}')"
    if (( height > width )); then sips --rotate 270 "$out/$stem.png" >/dev/null; fi
}
capture cinematic Dry NO daylight-chase 0
capture balanced Dry YES easy-drive 1
capture ultra Rain YES ultra-rain 2

# Record native simulator output in its own drive, after the timing checks.
xcrun simctl terminate "$device" "$bundle"
rm -f "$container/tmp/nd-demo-ready" "$container/tmp/nd-demo-start"
xcrun simctl launch "$device" "$bundle" -streetWeather Dry -streetTimeOfDay Daylight \
    -graphicsQuality cinematic -carStyle 0 -easyDrive YES -ndAutomatedDrive -ndHandlingDemo
wait_for "$container/tmp/nd-demo-ready"
movie="$out/waterfront-drive.mov"
xcrun simctl io "$device" recordVideo --codec=h264 "$movie" &
recorder=$!
trap 'kill -INT "$recorder" 2>/dev/null || true' EXIT
sleep 1
touch "$container/tmp/nd-demo-start"
sleep 8
kill -INT "$recorder"
wait "$recorder" || [[ -s "$movie" ]]
trap - EXIT
test -s "$movie"
