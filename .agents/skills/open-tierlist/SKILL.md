---
name: open-tierlist
description: Open the Tier List ZC Mac app. Use when the user wants to view, open, rank, or drag around a tier list.
---

# Open tier list

From the repo root:

1. If the user named a list, make it current: `./tl.js use <slug>`.
2. Build the app if it's missing or anything in `mac/` changed since the last build:
   `bin="build/Tier List ZC.app/Contents/MacOS/TierList"; [ -e "$bin" ] && [ -z "$(find mac -newer "$bin")" ] || ./mac/build.sh`
3. `open "build/Tier List ZC.app"`.
4. The user drags items between tiers in the app. Changes save straight to `lists/<slug>/tierlist.json`.

An app that's already open keeps showing its current list. The user switches lists with the picker, or with ⌘R after `use`.
