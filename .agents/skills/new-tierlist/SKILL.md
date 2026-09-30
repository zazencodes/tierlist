---
name: new-tierlist
description: Create a new tier list (S/A/B/C/D/F ranking) and populate it with image tiles, or with text cards when the user pastes text items or links. Use when the user asks to make, start, or create a tier list or ranking of things.
---

# New tier list

1. Work out the title and the full set of items from the chat. If the user gave a category but not items (e.g. "Pixar movies"), choose a sensible, complete set yourself.
2. Pick the style. Images are preferred: use `image` unless the user pastes text items (usually with links), or the items are abstract ideas with no sensible picture. In those cases use `text`.
   `./tl.js new "<Title>" [--style text]`. This creates `lists/<slug>/` and makes it current. Pass `--tiers "S,A,B,C"` only if the user asks for custom tiers.
3. **Text lists:** turn each item into a card and pipe a JSON array into `./tl.js add-cards`:
   ```sh
   ./tl.js add-cards <<'JSON'
   [{"name": "Model routing inside AI agents", "icon": "fluent-emoji-flat:robot", "tag": "Strong",
     "summary": "Full description text from the paste.",
     "links": [{"label": "OpenRouter Jev Router", "url": "https://..."}]}]
   JSON
   ```
   `name` is required. Keep it short, since it is what shows on the tile. `icon`, `tag`, `summary`, `links` and `tier` are optional. Include `tag`, `summary` and `links` only when the source has them. Keep the summary text as given and use the link text from the paste as the label. Then skip to step 5.

   **Icons:** give every card an Iconify icon (`set:name`). It is the card's main visual, so pick icons that make the items easy to tell apart at a glance, not generic decoration. Search with `./tl.js icons <query> [set]` and use only names it returns. Good sets:
   - `fluent-emoji-flat`: colorful emoji, the default choice
   - `game-icons`: bold icons for abstract concepts
   - `simple-icons`: brand and product logos, when the item *is* a product
   - `tabler`, `lucide`, `phosphor`: clean line icons
4. **Image lists:** for each item, find a good image URL on the web (poster, logo, portrait, or product shot; square-ish and recognizable). Prefer direct image URLs from Wikipedia/Wikimedia (`upload.wikimedia.org`), official sites, or TMDB. Then:
   `./tl.js add "<Item Name>" "<imageUrl>"`
   Items start unranked. If the user already said where an item goes, pass the tier as a third arg.
   `add` fails loudly if the URL isn't a downloadable image. Try another source. If nothing works for an item, skip it and tell the user which items are missing.
5. Open it using the `open-tierlist` skill.
