export async function slide28(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-28-limits.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "구현 결과와 향후 보완",
    name: "web-section-28"
  });
  return slide;
}
