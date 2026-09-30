# Tier List

Local drag-and-drop tier list app. The CLI is Node 24 with no dependencies; the app is Swift, built with the Command Line Tools.

- The app is Tier List ZC. `./mac/build.sh` builds it to `build/Tier List ZC.app` (it finds the repo from there); open it with `open "build/Tier List ZC.app"`. The UI is `public/index.html`, loaded from the repo at runtime, so ⌘R reloads it after editing. Only `mac/main.swift` changes need a rebuild.
- `./tl.js <command>` manages lists from the shell; run it with no args to see commands.
- Each list is a folder `lists/<slug>/` with `tierlist.json` and `images/`. Delete the folder to delete the list.
- Lists have a `style`: `image` (image tiles, added with `add`) or `text` (cards with an optional Iconify icon saved as `images/<id>.svg`, a title and a tag; click a card to see its summary and links; added with `add-cards`).
- Clicking a text card opens the right pane: the card's details on top, and its first link loaded below in a native browser with full JS and persistent logins. Other links load there too; ↗ opens the default browser, × or ⌘W closes the pane. The pane is HTML in `public/index.html`; the app lays the browser over its `#slot` element.
- `current` (repo root) holds the slug of the list being worked on. CLI edits apply to it; the UI opens it by default.
- The UI polls the JSON, so CLI edits show up in the open app within ~2s.
- Skills live in `.agents/skills/` (`.claude/skills` is a symlink to it): `new-tierlist`, `edit-tierlist`, `open-tierlist`.
