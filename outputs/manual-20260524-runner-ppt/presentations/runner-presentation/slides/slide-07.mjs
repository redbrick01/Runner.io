export async function slide07(presentation, ctx) {
  const slide = presentation.slides.add();
  slide.background.fill = "#f7fafc";
  await ctx.addImage(slide, {
    path: "/Users/yw0410/Desktop/Project/runner_flutter/outputs/manual-20260524-runner-ppt/presentations/runner-presentation/assets/slide-07-architecture.png",
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    fit: "contain",
    alt: "Flutter 앱, Edge Function, PostGIS가 역할을 나누는 구조",
    name: "web-section-07"
  });
  return slide;
}
