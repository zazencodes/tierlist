---
name: open-tierlist
description: Start the tier list web UI and open it in the browser. Use when the user wants to view, open, rank, or drag around a tier list.
---

# Open tier list

1. Check whether the server is running: `curl -s localhost:4747/api/lists`. If not, run `npm start` in the background from the repo root.
2. `open "http://localhost:4747/?list=<slug>"` (leave out `?list=` to open the current list).
3. The user drags items between tiers in the browser. Changes save straight to `lists/<slug>/tierlist.json`.
