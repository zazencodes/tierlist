# Spec: native Mac app replaces the browser version

## Goal

Tier List becomes a native macOS app, `Tier List.app`, installed in `/Applications`. It has one window with the tier list on the left and a real embedded browser on the right. Clicking a card link loads the page in that browser pane with full JavaScript and saved logins. The localhost web server and the browser version are removed.

## Why

The current pane is an `<iframe>` fed by the `/proxy` route in `server.js`. Browsers stop one site from framing another (`X-Frame-Options`, CSP `frame-ancestors`). The proxy works around that by re-serving a stripped copy with scripts disabled, so JS-rendered sites (YouTube, X, parts of GitHub) come out broken, and logins never work. A native `WKWebView` is a top-level browser view and doesn't have these limits.

## Architecture

```
Tier List.app (Swift, AppKit + WebKit, one source file)
┌───────────────────────────── NSWindow ─────────────────────────────┐
│ NSSplitView                                                        │
│ ┌──────────── UI view (WKWebView) ───┐ ┌──── Pane (hidden) ──────┐ │
│ │ loads tierlist://app/              │ │ bar: url · ↗ · ×        │ │
│ │ = public/index.html                │ │ WKWebView (any https    │ │
│ │                                    │ │ site, persistent store) │ │
│ └────────────────────────────────────┘ └─────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
      │ GET  tierlist://app/...    → URL scheme handler reads repo files
      │ save / openLink messages   → script message handlers
      ▼
  <repo>/lists/<slug>/tierlist.json, images/, current   ← tl.js edits the same files
```

- **No Node at runtime.** The app reads and writes the repo files itself. `tl.js` stays in Node, and the skills keep editing the JSON as before.
  - This also removes a whole class of bug. The pane first broke because a server started before the `/proxy` code was added was still running. The app has no server that can go stale.
- **The UI stays HTML.** `public/index.html` is loaded from the repo at runtime, so a UI change needs only a reload (⌘R), not a rebuild. Only Swift changes need a rebuild.
- **The repo location is fixed at build time.** The build script writes the repo's absolute path into `Info.plist` under the key `TierListRoot`. If the key is missing or `<root>/current` doesn't exist at launch, the app shows an alert naming the path and quits. There is no fallback path.

## Files

| Path | Change |
|---|---|
| `mac/main.swift` | New. The whole app. |
| `mac/build.sh` | New. Compiles, bundles, signs and installs the app. |
| `public/index.html` | Remove the pane and the proxy code; switch saving and link opening to message handlers. |
| `server.js` | Delete. |
| `package.json` | Remove the `start` script. Keep `"type": "module"` for `tl.js`. |
| `.gitignore` | Add `build/`. |
| `AGENTS.md`, `.agents/skills/open-tierlist/SKILL.md`, `.agents/skills/edit-tierlist/SKILL.md` | Update the docs (see below). |

## `mac/main.swift`

This is a single file with no storyboard or Xcode project, targeting macOS 14 or later. It sets up `NSApplication` and an app delegate by hand.

### Window
- One `NSWindow`, 1400×900 by default, titled "Tier List", with `setFrameAutosaveName("TierListWindow")` so its size and position are remembered.
- The content is a vertical-divider `NSSplitView`. Set `autosaveName` on it so the divider position is remembered.
  - Left subview: the UI view.
  - Right subview: the pane, starting hidden.
  - Default split is 55/45.
- The app quits when its window closes (`applicationShouldTerminateAfterLastWindowClosed` returns `true`).

### Main menu (required: without it ⌘Q, ⌘C and ⌘V don't work)
- **App menu:** Quit (⌘Q).
- **Edit menu:** Undo, Redo, Cut, Copy, Paste, Select All, using the standard selectors. Paste is needed to sign in to sites in the pane.
- **View menu:**
  - Reload Tier List (⌘R) reloads the UI view.
  - Close Pane (⌘W) hides the pane when it is open. Nothing happens when it is closed; ⌘W must not close the window.

### UI view (left)
- A `WKWebView` whose configuration has:
  - `setURLSchemeHandler(handler, forURLScheme: "tierlist")`;
  - script message handlers `save` and `openLink`;
  - `isInspectable = true`, so Safari's Web Inspector can debug it.
- It loads `tierlist://app/`.
- **Scheme handler:** GET only. It serves the same paths `server.js` serves today, so `fetch` calls in `index.html` don't change:
  - `/` → `<root>/public/index.html` (`text/html`).
  - `/api/lists` → `{ current, lists: [{ slug, title }] }`.
    - `current` is `<root>/current`, trimmed.
    - The lists are the folders in `<root>/lists/` whose name matches `^[a-z0-9-]+$` and that contain a `tierlist.json`. `title` comes from that JSON.
  - `/api/list/<slug>` → the raw bytes of `tierlist.json` (`application/json`).
  - `/lists/<slug>/images/<file>` → the image file.
    - The MIME type comes from the extension, using the same table as `server.js`: jpg, png, webp, gif, svg, avif.
    - Use only the last path component of `<file>`, so a request can't reach outside the `images` folder.
  - Anything else, including an invalid slug, gets a 404 response.
  - Don't cache anything. The UI polls every 1.5 s to pick up edits from the CLI.
- **`save` message:** the body is `{ slug, json }`, where `json` is the already-formatted string (`JSON.stringify(data, null, 2) + "\n"`). The handler validates the slug the same way as the scheme handler, then writes the string to `tierlist.json` byte for byte. Formatting stays in JS, so the files match what `tl.js` writes.
- **`openLink` message:** the body is an http(s) URL string. The handler shows the pane and loads the URL there.
- **Navigation:** any navigation in the UI view to a URL whose scheme isn't `tierlist:` is cancelled and opened in the default browser with `NSWorkspace.shared.open`. So is any new-window request (the ↗ links use `target="_blank"`), handled through `WKUIDelegate.createWebViewWith` returning `nil`.

### Pane (right)
- A vertical stack with a bar and a `WKWebView`.
- The pane's `WKWebView` uses `WKWebsiteDataStore.default()`. It persists per bundle ID, so logins survive relaunches. It is separate from Safari and Chrome.
  - Set `applicationNameForUserAgent = "Version/18.0 Safari/605.1.15"`, so sites treat the view as Safari and don't serve "unsupported browser" pages.
  - Set `allowsBackForwardNavigationGestures = true`, so a two-finger swipe goes back and forward.
- The bar, matching the current HTML pane bar:
  - A label with the current URL, kept in sync by observing `webView.url` with KVO. It truncates in the middle.
  - A **↗** button that opens the current URL in the default browser.
  - A **×** button that hides the pane.
- **Hiding the pane:** collapse the split subview and load `about:blank`, so audio and video stop.
- **Showing the pane:** un-collapse the split subview and load the URL.
- New-window requests inside the pane (`target="_blank"`, `window.open`) load in the pane itself instead of opening a new window.
- Downloads, tabs and an address bar are out of scope.

### Errors
- A failed file read or write in a handler throws or fails loudly. The scheme handler returns an error to the task, and the `save` handler shows an `NSAlert` with the path and the error.
- Nothing is swallowed.

## `mac/build.sh`

This is a bash script (`set -euo pipefail`) run from anywhere. The repo root is the script's parent directory.

1. Create `build/Tier List.app/Contents/MacOS/`.
2. Compile with `swiftc -O mac/main.swift -framework Cocoa -framework WebKit -o "build/Tier List.app/Contents/MacOS/TierList"`.
3. Write `Contents/Info.plist` with:
   - `CFBundleName` = "Tier List"
   - `CFBundleIdentifier` = `com.zazencodes.tierlist`
   - `CFBundleExecutable` = `TierList`
   - `CFBundlePackageType` = `APPL`
   - `LSMinimumSystemVersion` = `14.0`
   - `NSHighResolutionCapable` = `true`
   - `TierListRoot` = the absolute repo path
4. Sign ad hoc with `codesign --force --sign - "build/Tier List.app"`.
5. Replace `/Applications/Tier List.app` with the new build, removing the old one first.

The app uses the default app icon; no icon work is in scope.

## `public/index.html` changes

- Delete `#pane`, its CSS, `openPane`, `closePane`, and the `#pane` flex layout on `body`. `#app` fills the window.
- Detail dialog link buttons call `webkit.messageHandlers.openLink.postMessage(url)` and close the dialog.
- In `wireDrop`, replace the `fetch(..., { method: "PUT" })` with `webkit.messageHandlers.save.postMessage({ slug, json: raw })`. `raw` is already set to the formatted string on the line above.
- Keep the ↗ anchors (`target="_blank"`). The Swift side sends them to the default browser.
- The `?list=` picker navigation stays. It resolves to `tierlist://app/?list=<slug>`.

## Doc updates

- **`AGENTS.md`:**
  - Replace the `npm start` bullet with: build and install with `./mac/build.sh`, open with `open -a "Tier List"`, and ⌘R reloads the UI after editing `public/index.html`.
  - Rewrite the pane bullet: card links open in a native browser pane on the right with full JS and persistent logins; ↗ opens the default browser.
  - Change "Node 24, no dependencies" to say the CLI is Node 24 and the app is Swift built with the Command Line Tools.
  - Change "in an open browser" to "in the open app".
- **`open-tierlist` skill:**
  - Set the list with `./tl.js use <slug>` when one is named.
  - Then run `open -a "Tier List"`.
  - If `/Applications/Tier List.app` is missing, run `./mac/build.sh` first.
  - Note that an app that's already open keeps showing its current list. The user switches lists with the picker, or with ⌘R after `use`.
- **`edit-tierlist` skill, line 24:** change "An open browser picks up changes" to "The open app picks up changes".

## Done when

1. `./mac/build.sh` succeeds on a clean checkout, and `/Applications/Tier List.app` launches from Finder and from Spotlight.
2. The current list renders; drags save to `tierlist.json`, formatted the same way as `tl.js` output. `git diff` shows only the moved IDs.
3. `./tl.js add-cards ...` or `rename` while the app is open shows up within about 2 s.
4. On a text-list card:
   - Opening the GitHub, YouTube and x.com links renders each one fully in the pane, and YouTube video plays.
   - ↗ opens the default browser.
   - × stops playback and hides the pane.
5. Sign in to GitHub in the pane, quit, relaunch: you are still signed in. Pasting into the login form works.
6. ⌘Q quits, ⌘R reloads the UI, and ⌘W closes the pane, not the window.
7. The window size and the split position survive a relaunch.
8. Break it on purpose: temporarily rename `current`, then launch. The app shows an alert naming the path and quits.
9. `server.js` and every mention of `npm start`, `localhost:4747` and `/proxy` are gone from the repo (`grep -r`).
