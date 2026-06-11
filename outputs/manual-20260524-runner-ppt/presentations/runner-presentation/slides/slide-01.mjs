export async function slide01(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-01-section-1.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "contain",
    alt: "RUNNER.IO",
    name: "web-section-01"
  });
  return slide;
}
