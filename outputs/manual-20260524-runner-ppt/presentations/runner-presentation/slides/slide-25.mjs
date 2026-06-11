export async function slide25(presentation, ctx) {
  const slide = presentation.slides.add();
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-25-testing.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "자동 테스트와 실제 기기 검증",
    name: "web-section-25"
  });
  return slide;
}
