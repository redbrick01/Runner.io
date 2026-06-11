import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const workspace = "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation";
const slidesDir = resolve(workspace, "slides-refresh");
const shots = JSON.parse(await readFile(resolve(workspace, "section-shots.json"), "utf8"));

await mkdir(slidesDir, { recursive: true });

for (let i = 0; i < shots.length; i += 1) {
  const shot = shots[i];
  const slideNo = String(i + 1).padStart(2, "0");
  const modulePath = resolve(slidesDir, `slide-${slideNo}.mjs`);
  const content = `export async function slide${slideNo}(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: ${JSON.stringify(shot.path)},
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: ${JSON.stringify(shot.title)},
    name: ${JSON.stringify(`web-section-${slideNo}`)}
  });
  return slide;
}
`;
  await writeFile(modulePath, content);
}
