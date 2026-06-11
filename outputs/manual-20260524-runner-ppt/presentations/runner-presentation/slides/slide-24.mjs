export async function slide24(presentation, ctx) {
  const slide = presentation.slides.add();
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-24-timeline-continued.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "개발 일정",
    name: "web-section-24"
  });
  return slide;
}
