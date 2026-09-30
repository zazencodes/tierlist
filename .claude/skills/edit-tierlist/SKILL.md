---
name: edit-tierlist
description: Edit an existing tier list — add/remove/rename items, replace images, move items between tiers, change tiers, colors or title, or switch which list is current. Use when the user wants to change a tier list.
---

# Edit tier list

All commands act on the list named in `current`. Check it with `./tl.js lists` (the current list is starred). If the user means another list, run `./tl.js use <slug>` first.

Inspect: `./tl.js show`

Commands (items can be given by id or name):
- `./tl.js add "<Name>" "<imageUrl>" [tier]`: find the image on the web yourself, as in `new-tierlist`
- `./tl.js remove "<item>"`
- `./tl.js rename "<item>" "<New Name>"`
- `./tl.js image "<item>" "<imageUrl>"`
- `./tl.js place "<item>" <tier|unranked>`
- `./tl.js tiers "S,A,B,C,D"`: set tiers in order. Items in removed tiers go back to unranked.
- `./tl.js color <tier> "#hex"`
- `./tl.js title "<New Title>"`

An open browser picks up changes automatically. To delete a whole list, remove `lists/<slug>/`.
