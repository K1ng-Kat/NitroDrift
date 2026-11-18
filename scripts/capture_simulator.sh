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
    local quality="$1" weather="$2" auto="$3" stem="$4"
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    rm -f "$container/tmp/nd-frame-ready" "$container/tmp/nd-cadence.json"
    xcrun simctl launch "$device" "$bundle" -streetWeather "$weather" -streetTimeOfDay Daylight \
        -graphicsQuality "$quality" -easyDrive "$auto" -screenRefractionEnabled YES -ndAutomatedDrive
    wait_for "$container/tmp/nd-frame-ready"
    xcrun simctl io "$device" screenshot "$out/$stem.png"
    wait_for "$container/tmp/nd-cadence.json"
    cp "$container/tmp/nd-cadence.json" "$out/$stem.json"
    cat "$out/$stem.json"
}
capture cinematic Dry NO daylight-chase
capture balanced Dry YES easy-drive
capture ultra Rain YES ultra-rain
