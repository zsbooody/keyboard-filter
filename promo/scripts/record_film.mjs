import { chromium } from "playwright";
import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(__dirname, "../media/raw");
fs.mkdirSync(outDir, { recursive: true });
for (const f of fs.readdirSync(outDir)) fs.unlinkSync(path.join(outDir, f));

const url = process.env.FILM_URL || "http://127.0.0.1:8765/film.html";
const browser = await chromium.launch({
  channel: "chrome",
  headless: true,
  args: ["--autoplay-policy=no-user-gesture-required", "--disable-gpu-sandbox"]
});
const context = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
  recordVideo: { dir: outDir, size: { width: 1920, height: 1080 } }
});
const page = await context.newPage();
await page.goto(url, { waitUntil: "load", timeout: 30000 });
await page.waitForTimeout(34200);
await context.close();
await browser.close();
const files = fs.readdirSync(outDir).filter((n) => n.endsWith(".webm"));
console.log("recorded", files.map((n) => path.join(outDir, n)).join("\n"));
