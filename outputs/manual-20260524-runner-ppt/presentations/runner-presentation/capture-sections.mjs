import { mkdir, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require("/Users/yw0410/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright");

const workspace = "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation";
const pageUrl = "http://127.0.0.1:5173/";
const assetDir = resolve(workspace, "assets");
const manifestPath = resolve(workspace, "section-shots.json");

await mkdir(assetDir, { recursive: true });

const browser = await chromium.launch({
  headless: true,
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
await page.goto(pageUrl, { waitUntil: "load" });
await page.waitForTimeout(1000);

const sections = await page.locator("section").evaluateAll((nodes) =>
  nodes.map((node, index) => {
    const eyebrow = node.querySelector("p")?.textContent?.trim() ?? "";
    const title = node.querySelector("h1,h2")?.textContent?.replace(/\s+/g, " ").trim() ?? `Slide ${index + 1}`;
    const rect = node.getBoundingClientRect();
    return {
      index,
      id: node.id || `section-${index + 1}`,
      eyebrow,
      title,
      top: Math.round(rect.top + window.scrollY),
      height: Math.round(rect.height),
    };
  }),
);

const shots = [];

for (let i = 0; i < sections.length; i += 1) {
  const section = sections[i];

  if (section.id === "user-guide") {
    const guideButtons = page.locator("#user-guide button[aria-label$='보기']");
    const guideCount = await guideButtons.count();

    for (let guideIndex = 0; guideIndex < guideCount; guideIndex += 1) {
      await captureSection(i, {
        fileSuffix: `user-guide-${String(guideIndex + 1).padStart(2, "0")}`,
        titleSuffix: ` / Feature ${String(guideIndex + 1).padStart(2, "0")}`,
        beforeCapture: async () => {
          await guideButtons.nth(guideIndex).click();
          await page.waitForTimeout(650);
        },
      });
    }

    continue;
  }

  await captureSection(i);
}

await browser.close();
await writeFile(manifestPath, JSON.stringify(shots, null, 2));

function slug(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9가-힣]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

async function captureSection(sectionIndex, options = {}) {
  const section = await page.locator("section").nth(sectionIndex).evaluate((node, index) => {
    const eyebrow = node.querySelector("p")?.textContent?.trim() ?? "";
    const title = node.querySelector("h1,h2")?.textContent?.replace(/\s+/g, " ").trim() ?? `Slide ${index + 1}`;
    const rect = node.getBoundingClientRect();
    return {
      index,
      id: node.id || `section-${index + 1}`,
      eyebrow,
      title,
      top: Math.round(rect.top + window.scrollY),
      height: Math.round(rect.height),
    };
  }, sectionIndex);

  const frameHeight = Math.max(720, section.height);
  const frameWidth = Math.round(frameHeight * (16 / 9));

  await page.setViewportSize({ width: frameWidth, height: frameHeight });
  await page.waitForTimeout(250);

  if (options.beforeCapture) {
    await options.beforeCapture();
  }

  const top = await page
    .locator("section")
    .nth(sectionIndex)
    .evaluate((node) => Math.round(node.getBoundingClientRect().top + window.scrollY));

  await page.evaluate((scrollTop) => window.scrollTo({ top: scrollTop, behavior: "instant" }), top);
  await page.waitForTimeout(550);

  const shotIndex = shots.length + 1;
  const suffix = options.fileSuffix || slug(section.id);
  const fileName = `slide-${String(shotIndex).padStart(2, "0")}-${suffix}.png`;
  const path = resolve(assetDir, fileName);
  await page.screenshot({ path, fullPage: false });
  shots.push({
    ...section,
    shotIndex,
    title: `${section.title}${options.titleSuffix || ""}`,
    frameWidth,
    frameHeight,
    path,
  });
}
