#!/bin/zsh
# Records every style in the demo app on an iPhone simulator, light and dark,
# and cuts one seamless loop of each into assets/styles/<style>-<scheme>.gif.
#
# usage: Scripts/render-media.sh [simulator name or UDID] [style ...]
#        (default: iPhone 17 Pro Max, every style)
# PACE=3 records everything three times slower and speeds it back up, for a
# full frame rate on a busy machine.
# needs: Xcode, ffmpeg, python3 (gifsicle optional)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v ffmpeg >/dev/null || { echo "needs ffmpeg (brew install ffmpeg)"; exit 1; }
SIM="${1:-iPhone 17 Pro Max}"
shift $(( $# > 0 ? 1 : 0 ))
STYLES=("$@")
(( ${#STYLES} )) || STYLES=(ruler glass jelly elastic fluid squiggle thermostat swing mood tape effort emoji)
WORK="$PWD/Scripts/.work"
PACE="${PACE:-1}"
mkdir -p "$WORK/media" assets/styles

if [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then
  UDID="$SIM"
else
  UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == name and 'iOS' in runtime:
            print(d['udid']); sys.exit()
sys.exit('no available iOS simulator named ' + name)" "$SIM")
fi
xcrun simctl boot "$UDID" 2>/dev/null || true

echo "Building the demo app…"
xcodebuild -project Demo/ScrubbersDemo.xcodeproj -scheme ScrubbersDemo -configuration Release \
  -destination "id=$UDID" -derivedDataPath "$WORK/DemoDerivedData" -quiet build
APP=$(find "$WORK/DemoDerivedData/Build/Products" -name ScrubbersDemo.app -maxdepth 2 | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl ui "$UDID" appearance light

# Each control's height in points (DemoMetrics in DemoStage.swift).
typeset -A HEIGHT
HEIGHT=(ruler 78 glass 52 jelly 106 elastic 52 fluid 92 squiggle 44 thermostat 250 swing 92 mood 250 tape 122 effort 150 emoji 100)

for STYLE in $STYLES; do
  for SCHEME in light dark; do
    RAW="$WORK/media/$STYLE-$SCHEME.mp4"
    xcrun simctl terminate "$UDID" com.haplo.ScrubbersDemo 2>/dev/null || true
    rm -f "$RAW"
    xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" >/dev/null 2>&1 &
    REC=$!
    sleep 1.5
    SIMCTL_CHILD_SCRUBBERS_MEDIA=$STYLE SIMCTL_CHILD_SCRUBBERS_SCHEME=$SCHEME SIMCTL_CHILD_SCRUBBERS_PACE=$PACE \
      xcrun simctl launch "$UDID" com.haplo.ScrubbersDemo >/dev/null
    sleep $(( 17 * PACE ))
    kill -INT $REC; wait $REC 2>/dev/null || true
    python3 Scripts/gif.py "$RAW" "assets/styles/$STYLE-$SCHEME.gif" "${HEIGHT[$STYLE]}" --speed "$PACE"
  done
done
xcrun simctl terminate "$UDID" com.haplo.ScrubbersDemo 2>/dev/null || true
