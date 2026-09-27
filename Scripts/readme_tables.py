#!/usr/bin/env python3
"""Fills the style table and the credits in README.md from one list, so the
names, cases, summaries and sources can't drift apart. Run after adding or
renaming a style; it rewrites the blocks between the TABLE markers."""
import re, pathlib

STYLES = [
    ("ruler", "Ruler", "Ticks swell into a bell around the indicator",
     "[iOS Eras](https://github.com/haplollc/ios-eras), after [@colderoshay](https://x.com/colderoshay)'s “life of a button”"),
    ("glass", "Glass", "The thumb turns into a lens while held",
     "Apple's [Liquid Glass sliders](https://developer.apple.com/videos/play/wwdc2025/323/), iOS 26"),
    ("jelly", "Jelly", "Buckles into a wobbling hump when you push it",
     "Voicu Apostol's [Jelly Slider](https://dribbble.com/shots/26498172-Jelly-Slider) and Software Mansion's [real-time port](https://swmansion.com/blog/breaking-down-the-jelly-slider-9ab9239f6d80/)"),
    ("elastic", "Elastic", "Stretches past its ends and snaps back",
     "Apple's volume sliders and BuildUI's [Elastic Slider](https://buildui.com/recipes/elastic-slider)"),
    ("fluid", "Fluid", "The value pops out on a gooey neck",
     "Virgil Pana's [Fluid Slider](https://dribbble.com/shots/3868232-ios-Fluid-Slider-ui-ux), open-sourced by [Ramotion](https://github.com/Ramotion/fluid-slider)"),
    ("squiggle", "Squiggle", "A wave that flattens while you hold it",
     "Android 13's [squiggly seek bar](https://www.androidpolice.com/android-13-squiggly-media-playback-bar/) and Material 3 Expressive"),
    ("thermostat", "Thermostat", "A dial that floods warm or cool as you turn it",
     "The [Nest Learning Thermostat](https://support.google.com/googlenest/answer/9243193?hl=en)"),
    ("swing", "Swing", "A value tag that leans and swings with weight",
     "The keyframers' [Diamond Slider](https://freefrontend.com/code/tilting-diamond-range-slider-effect-2026-03-30/) and Temani Afif's [jiggly tooltip](https://www.bram.us/2024/06/06/css-only-custom-range-slider-with-motion/)"),
    ("mood", "Mood", "Drag a feeling from spiky to round to blooming",
     "Apple's [State of Mind](https://www.apple.com/newsroom/2023/06/apple-provides-powerful-insights-into-new-areas-of-health/) logging in Health"),
    ("tape", "Tape", "A scale that coasts under a fixed needle",
     "Health-app weight pickers, the Photos adjustment ruler and [SlidingRuler](https://github.com/Pyroh/SlidingRuler)"),
    ("effort", "Effort", "Stepped bars that hop as you climb",
     "The [effort rating](https://60fps.design/shots/apple-fitness-watch-effort-slider) in Apple's Fitness app"),
    ("emoji", "Emoji", "An emoji thumb that grows with the value",
     "Instagram's [emoji slider sticker](https://about.instagram.com/blog/announcements/introducing-the-emoji-slider-sticker)"),
]

def gif(style, title, summary):
    return (f'<picture><source media="(prefers-color-scheme: dark)" srcset="assets/styles/{style}-dark.gif">'
            f'<img src="assets/styles/{style}-light.gif" width="360" alt="{title}: {summary.lower()}"></picture>')

table = ["| | Style | In code | After |", "|:---:|---|---|---|"]
for style, title, summary, source in STYLES:
    table.append(f"| {gif(style, title, summary)} | **{title}**<br><sub>{summary}</sub> | `.{style}` | {source} |")

credits = [f"- **{title}** (`.{style}`): {source}." for style, title, summary, source in STYLES if style != "ruler"]

readme = pathlib.Path(__file__).resolve().parent.parent / "README.md"
text = readme.read_text()
def fill(text, name, lines):
    block = f"<!-- {name}:START -->\n" + "\n".join(lines) + f"\n<!-- {name}:END -->"
    if f"<!-- {name}:START -->" in text:
        return re.sub(rf"<!-- {name}:START -->.*?<!-- {name}:END -->", lambda m: block, text, flags=re.S)
    return text.replace(f"{name}_TABLE", block)
text = fill(text, "STYLES", table)
text = fill(text, "CREDITS", credits)
readme.write_text(text)
print("README tables written")
