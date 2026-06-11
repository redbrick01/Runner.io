export async function slide21(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-21-limits.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "contain",
    alt: "구현 결과와 향후 보완",
    name: "web-section-21"
  });
  return slide;
}
