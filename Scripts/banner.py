#!/usr/bin/env python3
"""Builds the README banner: six styles in a grid, each playing its own loop
from the media recordings (Scripts/.work/media, made by render-media.sh).
A style whose loop is shorter rests at home until the longest ends, so all
six start again together.

usage: banner.py [--pace 3] [--width 440] [--fps 25]
writes assets/banner-light.gif and assets/banner-dark.gif
"""
import argparse, json, os, shutil, subprocess, tempfile
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("--pace", type=float, default=1.0)
ap.add_argument("--width", type=int, default=440, help="width of one cell, px")
ap.add_argument("--fps", type=int, default=25)
a = ap.parse_args()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "Scripts", ".work", "media")
GRID = [["jelly", "glass"], ["fluid", "swing"], ["thermostat", "mood"]]
HEIGHT = dict(ruler=78, glass=52, jelly=106, elastic=52, fluid=92, squiggle=44, thermostat=250,
              swing=92, mood=250, tape=122, effort=150, emoji=100)
BOX_TOP, MARGIN, S = 220, 28, 3
PAGE = {"light": (255, 255, 255), "dark": (13, 17, 23)}
GAP = 8


def loop_bounds(raw):
    """The second whole loop, from the flip square's changes."""
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", raw, "-vf",
                          f"fps=60,crop=2:2:{20 * S}:{50 * S},format=gray", "-f", "rawvideo", "-"],
                         capture_output=True, check=True).stdout
    flips, last = [], None
    for f in range(len(out) // 4):
        v = out[f * 4]
        state = 0 if v < 80 else (1 if v > 170 else None)
        if state is None:
            continue
        if last is not None and state != last:
            flips.append(f / 60)
        last = state
    # Launch can flicker the square: a real loop is never shorter than
    # 2.5 s of scrubber time, so a flip that soon after the last is noise.
    kept = []
    for t in flips:
        if kept and t - kept[-1] < 2.5 * a.pace:
            kept[-1] = t
            continue
        kept.append(t)
    return kept[1], kept[2]


def frames(style, scheme):
    raw = os.path.join(MEDIA, f"{style}-{scheme}.mp4")
    start, end = loop_bounds(raw)
    top = (BOX_TOP - MARGIN) * S
    height = int((HEIGHT[style] + MARGIN * 2) * S) // 2 * 2
    w = a.width
    h = int(round(height * w / 1320 / 2)) * 2
    out = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", raw,
                          "-vf", f"setpts=(PTS-STARTPTS)/{a.pace},fps={a.fps},crop=1320:{height}:0:{top},"
                                 f"scale={w}:{h}:flags=lanczos,format=rgb24",
                          "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    n = len(out) // (w * h * 3)
    page = np.array(PAGE[scheme], dtype=np.int16)
    clips = []
    for i in range(n):
        f = np.frombuffer(out[i * w * h * 3:(i + 1) * w * h * 3], dtype=np.uint8).reshape(h, w, 3).copy()
        # Video compression nudges the page colour; snap it back so the cells
        # meet each other, and GitHub's page, without a seam.
        near = np.abs(f.astype(np.int16) - page).max(axis=2) <= 7
        f[near] = PAGE[scheme]
        clips.append(f)
    return clips


for scheme in ("light", "dark"):
    cells = [[frames(style, scheme) for style in row] for row in GRID]
    length = max(len(c) for row in cells for c in row)
    row_heights = [max(c[0].shape[0] for c in row) for row in cells]
    W = a.width * 2 + GAP
    H = sum(row_heights) + GAP * (len(GRID) - 1)
    with tempfile.TemporaryDirectory() as tmp:
        for i in range(length):
            canvas = np.zeros((H, W, 3), dtype=np.uint8)
            canvas[:, :] = PAGE[scheme]
            y = 0
            for r, row in enumerate(cells):
                for c, clip in enumerate(row):
                    frame = clip[min(i, len(clip) - 1)]      # rest at home once done
                    fh = frame.shape[0]
                    oy = y + (row_heights[r] - fh) // 2
                    ox = c * (a.width + GAP)
                    canvas[oy:oy + fh, ox:ox + a.width] = frame
                y += row_heights[r] + GAP
            Image.fromarray(canvas).save(os.path.join(tmp, f"{i:04d}.png"))
        target = os.path.join(ROOT, "assets", f"banner-{scheme}.gif")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(a.fps), "-i", os.path.join(tmp, "%04d.png"),
                        "-filter_complex",
                        "[0:v]split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];"
                        "[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
                        "-loop", "0", target], check=True)
    if shutil.which("gifsicle"):
        subprocess.run(["gifsicle", "-O3", "--batch", target], check=True)
    print(f"{os.path.getsize(target) / 1024:.0f} KB  {target}  {W}x{H}, {length} frames")
