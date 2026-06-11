from pathlib import Path


ROOT = Path(__file__).resolve().parent
POSTER = ROOT / "index.html"


required_phrases = [
    "Runner.io",
    "러닝을 지도 위의 경로, 포인트, 랭킹, 영토 점령으로 연결",
    "영토 점령을 통한 포인트 경쟁",
    "AI 러닝 분석",
    "AI 리포트",
    "개발 목표",
    "구현 내용",
    "앱 구조",
    "개발 성과",
    "Google Maps",
    "Supabase",
    "PostgreSQL + PostGIS",
    "Flutter",
    "Android Foreground Service",
    "iOS Live Activity",
    "Run",
    "Claim",
    "Compete",
    "Grow",
]


def main() -> int:
    if not POSTER.exists():
        print("FAIL: docs/poster/index.html missing")
        return 1

    html = POSTER.read_text(encoding="utf-8")
    missing = [phrase for phrase in required_phrases if phrase not in html]
    if missing:
        print("FAIL: missing phrases: " + ", ".join(missing))
        return 1

    checks = {
        "semantic poster wrapper": '<main class="poster"' in html,
        "A-series poster ratio": "aspect-ratio: 1 / 1.414" in html,
        "project layout": 'class="project-grid"' in html,
        "responsive CSS": "@media" in html,
        "architecture diagram": 'class="architecture"' in html,
        "user flow": 'class="step"' in html,
        "print support": "@page" in html,
    }
    failed = [name for name, ok in checks.items() if not ok]
    if failed:
        print("FAIL: missing checks: " + ", ".join(failed))
        return 1

    print("PASS: poster content and structure verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
