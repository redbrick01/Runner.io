export async function slide26(presentation, ctx) {
  const slide = presentation.slides.add();
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-26-challenges.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "구현 중 처리한 주요 문제",
    name: "web-section-26"
  });
  return slide;
}
