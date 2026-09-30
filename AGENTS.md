# Tier List

Local drag-and-drop tier list app. Node 24, no dependencies.

- `npm start` serves the UI at http://localhost:4747 (`?list=<slug>` to pick a list).
- `./tl.js <command>` manages lists from the shell; run it with no args to see commands.
- Each list is a folder `lists/<slug>/` with `tierlist.json` and `images/`. Delete the folder to delete the list.
- `current` (repo root) holds the slug of the list being worked on. CLI edits apply to it; the UI opens it by default.
- The UI polls the JSON, so CLI edits show up in an open browser within ~2s.
- Skills live in `.agents/skills/` (`.claude/skills` is a symlink to it): `new-tierlist`, `edit-tierlist`, `open-tierlist`.
