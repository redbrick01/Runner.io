# Runner.io Poster Design

## Goal

Build a static presentation poster webpage for Runner.io that helps a first-time viewer understand the project in about one minute.

## Selected Direction

Use an A+B blend from the visual companion:

- Map-first identity: GPS route, territory polygons, and running flow are visible immediately.
- Demo-day impact: strong hierarchy, high contrast accents, compact feature cards, and a clear system diagram.

## Content Selection Criteria

Content is selected from the current codebase and README by prioritizing:

- User-facing differentiators: running map, route recording, points, ranking, territory ownership, achievements, AI report, social flow.
- Technical differentiators: Flutter client, Google Maps/geolocation, Supabase Auth and Edge Functions, PostgreSQL/PostGIS, Android foreground service, iOS Live Activity.
- Presentation clarity: short phrases, visual flow, and architecture over long README-style prose.

## Page Scope

Create `docs/poster/index.html` as a self-contained static page with inline CSS. The page must work by opening the file directly in a browser.

Create `docs/poster/verify_poster.py` to verify required poster content and structural markers.

## Layout

The poster uses one large desktop-oriented canvas:

- Hero: project name, one-line value statement, and route/territory visual.
- Problem and solution: short blocks showing why the app exists and what it changes.
- Core loop: Run, Claim, Compete, Grow.
- Feature grid: map tracking, territory, ranking, history, achievements, coaching/reporting, profile/social.
- Architecture: Flutter, native background helpers, Supabase Edge Functions, PostgreSQL/PostGIS, Google Maps.
- User flow: login, run, save, reward, review.
- Tech stack and impact: compact badges and expected effects.

## Visual Tone

Follow the app color tokens:

- Primary blue: `#3A6DFF`
- Accent green: `#00D47E`
- Warning yellow: `#FFB800`
- Text: `#0A0B0D`
- Border: `#DEE1E6`

Use white and soft gray as the main surface, with dark navy bands only where contrast improves demo readability.
