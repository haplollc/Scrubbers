#!/bin/zsh
# Records the demo app's scripted walk through every style on an iPhone Pro
# Max simulator and renders the video in assets/demo.mp4: the 9:16 band the
# stage confines itself to, at 1080 x 1920 and 60 fps, scored by sound.py from
# the haptic ticks and moments the stage logs (simulator recordings are silent).
#
# usage: Scripts/record-demo.sh [simulator name or UDID]
# PACE=3 records everything three times slower and speeds it back up, for a
# full frame rate on a busy machine.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${1:-iPhone 17 Pro Max}"
PACE="${PACE:-1}"
SECS=$(( 38 * PACE ))
WORK="$PWD/Scripts/.work"
mkdir -p "$WORK" assets

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
xcodebuild -project Demo/ScrubbersDemo.xcodeproj -scheme ScrubbersDemo -configuration Release \
  -destination "id=$UDID" -derivedDataPath "$WORK/DemoDerivedData" -quiet build
APP=$(find "$WORK/DemoDerivedData/Build/Products" -name ScrubbersDemo.app -maxdepth 2 | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl ui "$UDID" appearance light

RAW="$WORK/demo-raw.mp4"
xcrun simctl terminate "$UDID" com.haplo.ScrubbersDemo 2>/dev/null || true
rm -f "$RAW"
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" >/dev/null 2>&1 &
REC=$!
sleep 1.5
SIMCTL_CHILD_SCRUBBERS_DEMO=1 SIMCTL_CHILD_SCRUBBERS_PACE=$PACE xcrun simctl launch "$UDID" com.haplo.ScrubbersDemo >/dev/null
sleep "$SECS"
kill -INT $REC; wait $REC 2>/dev/null || true

# The band: 9:16 of the width, centred on the screen.
read W H <<< $(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0:s=' ' "$RAW")
SCALE=$(( W / 440 ))
BAND=$(( W * 16 / 9 / 2 * 2 )); TOP=$(( (H - BAND) / 2 ))
# Start on the stage's first steady frame: its tick barcode's black frame
# (24 squares of 13 pt on a 4 pt frame, centred, (H - band) / 4 above the bottom).
TRIM=$(python3 - "$RAW" $SCALE $W $H <<'PY'
import subprocess, sys
raw, s, w, h = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
wp, hp = w / s, h / s
x = int(((wp - 320) / 2 + 1.5) * s)
y = int((hp - (hp - wp * 16 / 9) / 4 - 21 + 10.5) * s)
out = subprocess.run(["ffmpeg", "-v", "error", "-i", raw, "-vf", f"fps=30,crop=2:2:{x}:{y},format=gray",
                      "-f", "rawvideo", "-"], capture_output=True).stdout
print(next((f / 30 + 0.45 for f in range(len(out) // 4) if out[f * 4] < 60), 0))
PY
)
# Speed back up, cut the band, and hold the last frame (a recording stops
# when the screen does).
ffmpeg -v error -y -ss "$TRIM" -i "$RAW" \
  -vf "setpts=(PTS-STARTPTS)/$PACE,fps=60,crop=$W:$BAND:0:$TOP,scale=1080:1920:flags=lanczos,tpad=stop_mode=clone:stop_duration=1.6,format=yuv420p" \
  -c:v libx264 -preset slow -crf 17 -movflags +faststart -an "$WORK/demo-silent.mp4"
python3 Scripts/sound.py "$RAW" "$WORK/demo-silent.mp4" assets/demo.mp4 --scale $SCALE --trim "$TRIM" --speed "$PACE" --fps 120
