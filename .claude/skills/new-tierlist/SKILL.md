---
name: new-tierlist
description: Create a new tier list (S/A/B/C/D/F ranking) and populate it with items and images. Use when the user asks to make, start, or create a tier list or ranking of things.
---

# New tier list

1. Work out the title and the full set of items from the chat. If the user gave a category but not items (e.g. "Pixar movies"), choose a sensible, complete set yourself.
2. `./tl.js new "<Title>"`. This creates `lists/<slug>/` and makes it current. Pass `--tiers "S,A,B,C"` only if the user asks for custom tiers.
3. For each item, find a good image URL on the web (poster, logo, portrait, or product shot; square-ish and recognizable). Prefer direct image URLs from Wikipedia/Wikimedia (`upload.wikimedia.org`), official sites, or TMDB. Then:
   `./tl.js add "<Item Name>" "<imageUrl>"`
   Items start unranked. If the user already said where an item goes, pass the tier as a third arg.
4. `add` fails loudly if the URL isn't a downloadable image. Try another source. If nothing works for an item, skip it and tell the user which items are missing.
5. Open it using the `open-tierlist` skill.
