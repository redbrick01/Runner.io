export async function slide05(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-05-user-guide-01.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "cover",
    alt: "화면별 기능과 데이터 흐름 / Feature 01",
    name: "web-section-05"
  });
  return slide;
}
