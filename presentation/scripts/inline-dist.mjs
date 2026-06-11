import { cp, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const distDir = resolve(rootDir, "dist");
const htmlPath = resolve(distDir, "index.html");

let html = await readFile(htmlPath, "utf8");

html = await replaceLinkedStyles(html);
html = await replaceModuleScripts(html);
html = moveInlineModuleScriptsToBodyEnd(html);

await writeFile(htmlPath, html);
await cp(resolve(rootDir, "img"), resolve(distDir, "img"), { recursive: true });

async function replaceLinkedStyles(source) {
  const linkPattern = /<link rel="stylesheet" crossorigin href="\.\/(assets\/[^"]+\.css)">/g;
  return replaceAsync(source, linkPattern, async (_match, href) => {
    const css = await readFile(resolve(distDir, href), "utf8");
    return `<style>\n${css}\n</style>`;
  });
}

async function replaceModuleScripts(source) {
  const scriptPattern = /<script type="module" crossorigin src="\.\/(assets\/[^"]+\.js)"><\/script>/g;
  return replaceAsync(source, scriptPattern, async (_match, src) => {
    const js = await readFile(resolve(distDir, src), "utf8");
    return `<script type="module">\n${js.replaceAll("</script>", "<\\/script>")}\n</script>`;
  });
}

async function replaceAsync(source, pattern, replacer) {
  const matches = [...source.matchAll(pattern)];
  let result = source;

  for (const match of matches.reverse()) {
    const replacement = await replacer(...match);
    result = `${result.slice(0, match.index)}${replacement}${result.slice(match.index + match[0].length)}`;
  }

  return result;
}

function moveInlineModuleScriptsToBodyEnd(source) {
  const scriptPattern = /\s*<script type="module">\n[\s\S]*?\n<\/script>/g;
  const scripts = source.match(scriptPattern);

  if (!scripts?.length) {
    return source;
  }

  const withoutScripts = source.replace(scriptPattern, "");
  return withoutScripts.replace("</body>", `${scripts.join("\n")}\n  </body>`);
}
