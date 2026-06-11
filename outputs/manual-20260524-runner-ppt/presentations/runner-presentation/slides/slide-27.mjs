export async function slide27(presentation, ctx) {
  const slide = presentation.slides.add();
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-27-demo.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "시연 순서",
    name: "web-section-27"
  });
  return slide;
}
