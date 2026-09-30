// Local web UI. Serves the current list (or ?list=<slug>) and saves drags back to its JSON.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const ROOT = path.dirname(new URL(import.meta.url).pathname);
const LISTS = path.join(ROOT, "lists");
const PORT = Number(process.env.PORT ?? 4747);
const TYPES = { ".html": "text/html", ".jpg": "image/jpeg", ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif", ".svg": "image/svg+xml", ".avif": "image/avif" };

const dataFile = (slug) => path.join(LISTS, slug, "tierlist.json");
const validSlug = (s) => /^[a-z0-9-]+$/.test(s) && fs.existsSync(dataFile(s));

function send(res, code, body, type = "application/json") {
  res.writeHead(code, { "Content-Type": type });
  res.end(typeof body === "string" || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}

http.createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  const parts = url.pathname.split("/").filter(Boolean);

  if (url.pathname === "/") return send(res, 200, fs.readFileSync(path.join(ROOT, "public/index.html")), "text/html");

  if (url.pathname === "/api/lists") {
    const current = fs.readFileSync(path.join(ROOT, "current"), "utf8").trim();
    const lists = fs.readdirSync(LISTS).filter(validSlug).map((slug) => ({ slug, title: JSON.parse(fs.readFileSync(dataFile(slug))).title }));
    return send(res, 200, { current, lists });
  }

  if (parts[0] === "api" && parts[1] === "list" && validSlug(parts[2])) {
    if (req.method === "GET") return send(res, 200, fs.readFileSync(dataFile(parts[2])));
    if (req.method === "PUT") {
      let body = "";
      req.on("data", (c) => (body += c));
      req.on("end", () => {
        fs.writeFileSync(dataFile(parts[2]), JSON.stringify(JSON.parse(body), null, 2) + "\n");
        send(res, 200, { ok: true });
      });
      return;
    }
  }

  if (parts[0] === "lists" && validSlug(parts[1]) && parts[2] === "images" && parts.length === 4) {
    const file = path.join(LISTS, parts[1], "images", path.basename(parts[3]));
    if (fs.existsSync(file)) return send(res, 200, fs.readFileSync(file), TYPES[path.extname(file)]);
  }

  send(res, 404, { error: "not found" });
}).listen(PORT, () => console.log(`tierlist on http://localhost:${PORT}`));
