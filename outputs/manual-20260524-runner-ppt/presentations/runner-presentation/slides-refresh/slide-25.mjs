export async function slide25(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-25-workflow.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "개발 진행 방식",
    name: "web-section-25"
  });
  return slide;
}
