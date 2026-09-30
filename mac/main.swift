// Tier List ZC.app, built into <repo>/build/: the tier list UI (public/index.html, served from the repo over tierlist://)
// on the left and a real browser pane on the right for card links.
import Cocoa
import WebKit

let imageTypes = ["jpg": "image/jpeg", "png": "image/png", "webp": "image/webp", "gif": "image/gif", "svg": "image/svg+xml", "avif": "image/avif"]

func fail(_ message: String) -> Never {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Tier List ZC can't start"
    alert.informativeText = message
    alert.runModal()
    exit(1)
}

func showError(_ message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Tier List ZC error"
    alert.informativeText = message
    alert.runModal()
}

// Repo files: lists/<slug>/tierlist.json, lists/<slug>/images/, current, public/index.html.
struct Repo {
    let root: URL
    var lists: URL { root.appendingPathComponent("lists") }
    var current: URL { root.appendingPathComponent("current") }
    var indexHTML: URL { root.appendingPathComponent("public/index.html") }

    func dataFile(_ slug: String) -> URL { lists.appendingPathComponent(slug).appendingPathComponent("tierlist.json") }

    func validSlug(_ slug: String) -> Bool {
        slug.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil && FileManager.default.fileExists(atPath: dataFile(slug).path)
    }
}

struct NotFound: Error {}

final class SchemeHandler: NSObject, WKURLSchemeHandler {
    let repo: Repo
    init(repo: Repo) { self.repo = repo }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let url = task.request.url!
        do {
            guard task.request.httpMethod == "GET" else { throw NotFound() }
            let (data, type) = try route(url.pathComponents.filter { $0 != "/" })
            respond(task, url: url, status: 200, type: type, data: data)
        } catch is NotFound {
            respond(task, url: url, status: 404, type: "application/json", data: Data(#"{"error":"not found"}"#.utf8))
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func route(_ parts: [String]) throws -> (Data, String) {
        if parts.isEmpty { return (try Data(contentsOf: repo.indexHTML), "text/html") }
        if parts == ["api", "lists"] {
            let current = try String(contentsOf: repo.current, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            let slugs = try FileManager.default.contentsOfDirectory(atPath: repo.lists.path).filter(repo.validSlug).sorted()
            let lists = try slugs.map { slug -> [String: Any] in
                let json = try JSONSerialization.jsonObject(with: Data(contentsOf: repo.dataFile(slug))) as! [String: Any]
                return ["slug": slug, "title": json["title"]!]
            }
            return (try JSONSerialization.data(withJSONObject: ["current": current, "lists": lists]), "application/json")
        }
        if parts.count == 3, parts[0] == "api", parts[1] == "list", repo.validSlug(parts[2]) {
            return (try Data(contentsOf: repo.dataFile(parts[2])), "application/json")
        }
        if parts.count == 4, parts[0] == "lists", repo.validSlug(parts[1]), parts[2] == "images" {
            let name = (parts[3] as NSString).lastPathComponent
            let file = repo.lists.appendingPathComponent(parts[1]).appendingPathComponent("images").appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard let type = imageTypes[file.pathExtension.lowercased()],
                  FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue else { throw NotFound() }
            return (try Data(contentsOf: file), type)
        }
        throw NotFound()
    }

    private func respond(_ task: WKURLSchemeTask, url: URL, status: Int, type: String, data: Data) {
        let headers = ["Content-Type": type, "Content-Length": String(data.count), "Cache-Control": "no-store"]
        task.didReceive(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!)
        task.didReceive(data)
        task.didFinish()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let repo: Repo
    var window: NSWindow!
    var ui: WKWebView!
    var browser: WKWebView!
    var observations: [NSKeyValueObservation] = []

    init(repo: Repo) { self.repo = repo }

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.mainMenu = makeMenu()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1400, height: 900))

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(SchemeHandler(repo: repo), forURLScheme: "tierlist")
        for name in ["save", "openLink", "paneRect"] { config.userContentController.add(self, name: name) }
        ui = WKWebView(frame: container.bounds, configuration: config)
        ui.autoresizingMask = [.width, .height]
        ui.isInspectable = true
        ui.navigationDelegate = self
        ui.uiDelegate = self

        // The browser floats over the UI view, in the slot index.html reserves for it (see paneRect).
        let paneConfig = WKWebViewConfiguration()
        paneConfig.websiteDataStore = .default()
        paneConfig.applicationNameForUserAgent = "Version/18.0 Safari/605.1.15"
        browser = WKWebView(frame: .zero, configuration: paneConfig)
        browser.allowsBackForwardNavigationGestures = true
        browser.uiDelegate = self
        browser.isHidden = true
        // The pane is right-aligned with a fixed width, so this tracks it during a live resize.
        browser.autoresizingMask = [.minXMargin, .height]
        observations = [
            browser.observe(\.url) { [weak self] _, _ in self?.sendPaneState() },
            browser.observe(\.isLoading) { [weak self] _, _ in self?.sendPaneState() },
            browser.observe(\.estimatedProgress) { [weak self] _, _ in self?.sendPaneState() },
        ]

        container.addSubview(ui)
        container.addSubview(browser)

        window = NSWindow(contentRect: container.frame,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Tier List ZC"
        window.contentView = container
        window.center()
        window.setFrameAutosaveName("TierListWindow")
        window.makeKeyAndOrderFront(nil)

        // Esc inside the browser would go to the web page; send it to index.html instead, like Esc in the UI view.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, event.window === self.window,
                  let focused = self.window.firstResponder as? NSView, focused.isDescendant(of: self.browser) else { return event }
            self.ui.evaluateJavaScript("onEscape()")
            return nil
        }
        NSApp.activate()

        ui.load(URLRequest(url: URL(string: "tierlist://app/")!))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    // MARK: pane

    // Tells index.html what the browser is showing, for its URL bar and progress line.
    func sendPaneState() {
        let state: [String: Any] = ["url": browser.url?.absoluteString ?? "", "loading": browser.isLoading, "progress": browser.estimatedProgress]
        let json = String(data: try! JSONSerialization.data(withJSONObject: state), encoding: .utf8)!
        ui.evaluateJavaScript("window.paneState?.(\(json))")
    }

    func hideBrowser() {
        guard !browser.isHidden else { return }
        browser.isHidden = true
        browser.load(URLRequest(url: URL(string: "about:blank")!))
    }

    @objc func closePane() { ui.evaluateJavaScript("closePane()") }

    @objc func reloadUI() { ui.reload() }

    // MARK: messages from index.html

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "save":
            guard let body = message.body as? [String: Any], let slug = body["slug"] as? String, let json = body["json"] as? String else {
                return showError("save: bad message body \(message.body)")
            }
            guard repo.validSlug(slug) else { return showError("save: invalid list slug \"\(slug)\"") }
            let file = repo.dataFile(slug)
            do { try Data(json.utf8).write(to: file) } catch { showError("Could not save \(file.path):\n\(error.localizedDescription)") }
        case "openLink":
            guard let s = message.body as? String, let url = URL(string: s), ["http", "https"].contains(url.scheme) else {
                return showError("openLink: not an http(s) URL: \(message.body)")
            }
            browser.load(URLRequest(url: url))
        case "paneRect":
            // null: no slot on screen. Otherwise the slot's CSS rect, which is in points, top-left origin.
            if message.body is NSNull { return hideBrowser() }
            guard let r = message.body as? [String: Double], let x = r["x"], let y = r["y"], let w = r["width"], let h = r["height"] else {
                return showError("paneRect: bad message body \(message.body)")
            }
            browser.frame = NSRect(x: x, y: ui.bounds.height - y - h, width: w, height: h)
            browser.isHidden = false
        default:
            fatalError("unknown message \(message.name)")
        }
    }

    // MARK: navigation

    // UI view: anything outside tierlist:// goes to the default browser.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, url.scheme != "tierlist" else { return decisionHandler(.allow) }
        decisionHandler(.cancel)
        NSWorkspace.shared.open(url)
    }

    // New-window requests: from the UI they go to the default browser, inside the pane they stay in the pane.
    func webView(_ webView: WKWebView, createWebViewWith config: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }
        if webView === browser { browser.load(action.request) } else { NSWorkspace.shared.open(url) }
        return nil
    }

    // MARK: menu

    func makeMenu() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        func item(_ title: String, _ action: Selector, _ key: String, _ mods: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
            it.keyEquivalentModifierMask = mods
            it.target = target
            return it
        }
        submenu("Tier List ZC", [item("Quit Tier List ZC", #selector(NSApplication.terminate(_:)), "q")])
        submenu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ])
        submenu("View", [
            item("Reload Tier List", #selector(reloadUI), "r", target: self),
            item("Close Pane", #selector(closePane), "w", target: self),
        ])
        return main
    }
}

// The app lives at <repo>/build/Tier List ZC.app.
let repo = Repo(root: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
let app = NSApplication.shared
app.setActivationPolicy(.regular)
guard FileManager.default.fileExists(atPath: repo.current.path) else {
    fail("\(repo.current.path) does not exist. The app must run from <repo>/build/, and this copy is at \(Bundle.main.bundlePath).")
}
let delegate = AppDelegate(repo: repo)
app.delegate = delegate
app.run()
