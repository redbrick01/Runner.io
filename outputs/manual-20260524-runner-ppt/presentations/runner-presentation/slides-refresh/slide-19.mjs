export async function slide19(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-19-engine.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "GPS 샘플 기반 러닝 기록 변환",
    name: "web-section-19"
  });
  return slide;
}
