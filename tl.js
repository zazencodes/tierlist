#!/usr/bin/env node
// Tier list CLI. All state lives in lists/<slug>/tierlist.json and the `current` file.
import fs from "node:fs";
import path from "node:path";

const ROOT = path.dirname(new URL(import.meta.url).pathname);
const LISTS = path.join(ROOT, "lists");
const CURRENT = path.join(ROOT, "current");
const DEFAULT_TIERS = [
  ["S", "#ff7f7f"], ["A", "#ffbf7f"], ["B", "#ffdf7f"],
  ["C", "#ffff7f"], ["D", "#bfff7f"], ["F", "#7fbfff"],
];

const die = (msg) => { console.error(`error: ${msg}`); process.exit(1); };
const slugify = (s) => s.toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const listDir = (slug) => path.join(LISTS, slug);
const dataFile = (slug) => path.join(listDir(slug), "tierlist.json");

export function currentSlug() {
  if (!fs.existsSync(CURRENT)) die("no current list; run `./tl.js use <slug>` or `./tl.js new`");
  const slug = fs.readFileSync(CURRENT, "utf8").trim();
  if (!fs.existsSync(dataFile(slug))) die(`current list "${slug}" does not exist`);
  return slug;
}
export const load = (slug) => JSON.parse(fs.readFileSync(dataFile(slug), "utf8"));
export const save = (slug, data) => fs.writeFileSync(dataFile(slug), JSON.stringify(data, null, 2) + "\n");

function findItem(data, ref) {
  const id = data.items[ref] ? ref : Object.keys(data.items).find((k) => data.items[k].name.toLowerCase() === ref.toLowerCase());
  if (!id) die(`no item "${ref}"`);
  return id;
}
function detach(data, id) {
  data.unranked = data.unranked.filter((x) => x !== id);
  for (const t of data.tiers) t.items = t.items.filter((x) => x !== id);
}

async function downloadImage(slug, id, url) {
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 tierlist" }, redirect: "follow" });
  if (!res.ok) die(`image download failed (${res.status}) for ${url}`);
  const type = res.headers.get("content-type") || "";
  if (!type.startsWith("image/")) die(`not an image (${type}) at ${url}`);
  const ext = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif", "image/svg+xml": "svg", "image/avif": "avif" }[type.split(";")[0]];
  if (!ext) die(`unsupported image type ${type} at ${url}`);
  const file = `${id}.${ext}`;
  fs.mkdirSync(path.join(listDir(slug), "images"), { recursive: true });
  fs.writeFileSync(path.join(listDir(slug), "images", file), Buffer.from(await res.arrayBuffer()));
  return `images/${file}`;
}

// Iconify icon ("set:name") saved as images/<id>.svg. Monochrome icons are tinted light for dark cards.
async function downloadIcon(slug, id, icon) {
  const m = /^([a-z0-9-]+):([a-z0-9-]+)$/.exec(icon ?? "");
  if (!m) die(`icon must look like "set:name", got "${icon}"`);
  const res = await fetch(`https://api.iconify.design/${m[1]}/${m[2]}.svg?color=%23eeeeee`);
  const svg = await res.text();
  if (!res.ok || !svg.startsWith("<svg")) die(`no Iconify icon "${icon}"`);
  fs.writeFileSync(path.join(listDir(slug), "images", `${id}.svg`), svg);
}

const commands = {
  // new "<title>" [--style image|text] [--tiers "S,A,B"]
  new(title, ...rest) {
    if (!title) die("usage: new <title> [--style image|text] [--tiers S,A,B,...]");
    const slug = slugify(title);
    if (fs.existsSync(listDir(slug))) die(`list "${slug}" already exists`);
    const ti = rest.indexOf("--tiers");
    const tiers = ti >= 0
      ? rest[ti + 1].split(",").map((n, i) => ({ name: n.trim(), color: DEFAULT_TIERS[i % DEFAULT_TIERS.length][1], items: [] }))
      : DEFAULT_TIERS.map(([name, color]) => ({ name, color, items: [] }));
    const si = rest.indexOf("--style");
    const style = si >= 0 ? rest[si + 1] : "image";
    if (!["image", "text"].includes(style)) die(`style must be image or text, got "${style}"`);
    fs.mkdirSync(path.join(listDir(slug), "images"), { recursive: true });
    save(slug, { title, style, tiers, unranked: [], items: {} });
    fs.writeFileSync(CURRENT, slug + "\n");
    console.log(`created and switched to ${slug}`);
  },
  use(slug) {
    if (!slug || !fs.existsSync(dataFile(slug))) die(`no list "${slug}"`);
    fs.writeFileSync(CURRENT, slug + "\n");
    console.log(`current: ${slug}`);
  },
  current() { console.log(currentSlug()); },
  lists() {
    const cur = fs.existsSync(CURRENT) ? fs.readFileSync(CURRENT, "utf8").trim() : null;
    for (const s of fs.readdirSync(LISTS).filter((s) => fs.existsSync(dataFile(s))))
      console.log(`${s === cur ? "*" : " "} ${s}  (${load(s).title})`);
  },
  show() { console.log(JSON.stringify(load(currentSlug()), null, 2)); },
  // add "<name>" <imageUrl> [tier]
  async add(name, url, tier) {
    if (!name || !url) die("usage: add <name> <imageUrl> [tier]");
    const slug = currentSlug(), data = load(slug);
    if (data.style !== "image") die("add is for image lists; use add-cards");
    let id = slugify(name);
    if (data.items[id]) die(`item "${id}" already exists`);
    const target = tier ? data.tiers.find((t) => t.name === tier) ?? die(`no tier "${tier}"`) : null;
    data.items[id] = { name, image: await downloadImage(slug, id, url) };
    (target ? target.items : data.unranked).push(id);
    save(slug, data);
    console.log(`added ${id}`);
  },
  // add-cards < items.json — JSON array of {name, icon?, tag?, summary?, links?: [{label, url}], tier?}
  async "add-cards"() {
    const slug = currentSlug(), data = load(slug);
    if (data.style !== "text") die("add-cards is for text lists; use add");
    const cards = JSON.parse(fs.readFileSync(0, "utf8"));
    if (!Array.isArray(cards)) die("expected a JSON array on stdin");
    for (const { name, icon, tag, summary, links, tier, ...extra } of cards) {
      if (!name) die("every card needs a name");
      if (Object.keys(extra).length) die(`unknown fields on "${name}": ${Object.keys(extra).join(", ")}`);
      const id = slugify(name);
      if (data.items[id]) die(`item "${id}" already exists`);
      for (const l of links ?? []) if (!l.label || !l.url) die(`link on "${name}" needs label and url`);
      const target = tier ? (data.tiers.find((t) => t.name === tier) ?? die(`no tier "${tier}"`)).items : data.unranked;
      if (icon !== undefined) await downloadIcon(slug, id, icon);
      data.items[id] = Object.fromEntries(Object.entries({ name, icon, tag, summary, links }).filter(([, v]) => v !== undefined));
      target.push(id);
    }
    save(slug, data);
    console.log(`added ${cards.length} cards`);
  },
  async image(ref, url) {
    const slug = currentSlug(), data = load(slug), id = findItem(data, ref);
    if (data.style !== "image") die("image is for image lists");
    const old = data.items[id].image;
    data.items[id].image = await downloadImage(slug, id, url);
    if (old !== data.items[id].image) fs.rmSync(path.join(listDir(slug), old), { force: true });
    save(slug, data);
    console.log(`updated image for ${id}`);
  },
  // icon "<item>" set:name — find names with `icons <query>`
  async icon(ref, icon) {
    const slug = currentSlug(), data = load(slug), id = findItem(data, ref);
    if (data.style !== "text") die("icon is for text lists");
    await downloadIcon(slug, id, icon);
    data.items[id].icon = icon;
    save(slug, data);
    console.log(`${id} icon -> ${icon}`);
  },
  // icons <query> [set] — search Iconify
  async icons(query, set) {
    if (!query) die("usage: icons <query> [set]");
    const url = `https://api.iconify.design/search?limit=64&query=${encodeURIComponent(query)}${set ? `&prefix=${set}` : ""}`;
    const res = await fetch(url);
    if (!res.ok) die(`Iconify search failed (${res.status})`);
    const { icons } = await res.json();
    console.log(icons.length ? icons.join("\n") : "no results");
  },
  remove(ref) {
    const slug = currentSlug(), data = load(slug), id = findItem(data, ref);
    if (data.items[id].image) fs.rmSync(path.join(listDir(slug), data.items[id].image), { force: true });
    if (data.items[id].icon) fs.rmSync(path.join(listDir(slug), "images", `${id}.svg`), { force: true });
    detach(data, id);
    delete data.items[id];
    save(slug, data);
    console.log(`removed ${id}`);
  },
  rename(ref, name) {
    const slug = currentSlug(), data = load(slug), id = findItem(data, ref);
    data.items[id].name = name;
    save(slug, data);
    console.log(`renamed ${id} -> ${name}`);
  },
  // place "<item>" <tier|unranked>
  place(ref, tier) {
    const slug = currentSlug(), data = load(slug), id = findItem(data, ref);
    const target = tier === "unranked" ? data.unranked : (data.tiers.find((t) => t.name === tier) ?? die(`no tier "${tier}"`)).items;
    detach(data, id);
    target.push(id);
    save(slug, data);
    console.log(`${id} -> ${tier}`);
  },
  // tiers "S,A,B,C" — items in removed tiers go back to unranked
  tiers(spec) {
    if (!spec) die("usage: tiers S,A,B,...");
    const slug = currentSlug(), data = load(slug);
    const names = spec.split(",").map((s) => s.trim());
    for (const t of data.tiers) if (!names.includes(t.name)) data.unranked.push(...t.items);
    data.tiers = names.map((n, i) => data.tiers.find((t) => t.name === n) ?? { name: n, color: DEFAULT_TIERS[i % DEFAULT_TIERS.length][1], items: [] });
    save(slug, data);
    console.log(`tiers: ${names.join(", ")}`);
  },
  color(tier, color) {
    const slug = currentSlug(), data = load(slug);
    (data.tiers.find((t) => t.name === tier) ?? die(`no tier "${tier}"`)).color = color;
    save(slug, data);
  },
  title(title) {
    const slug = currentSlug(), data = load(slug);
    data.title = title;
    save(slug, data);
  },
};

if (process.argv[1] === new URL(import.meta.url).pathname) {
  const [cmd, ...args] = process.argv.slice(2);
  if (!commands[cmd]) die(`commands: ${Object.keys(commands).join(", ")}`);
  await commands[cmd](...args);
}
