# Runner.io Poster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-contained static presentation poster webpage for Runner.io.

**Architecture:** `docs/poster/index.html` contains the poster markup and inline CSS. `docs/poster/verify_poster.py` checks required content and layout markers so the static artifact remains presentation-ready.

**Tech Stack:** HTML, CSS, Python verification script.

---

### Task 1: Poster Verification

**Files:**
- Create: `docs/poster/verify_poster.py`

- [x] **Step 1: Write failing content/structure verification**

The script checks required phrases, semantic poster wrapper, architecture diagram, user flow, responsive CSS, and print support.

- [x] **Step 2: Run verification to confirm RED**

Run: `python3 docs/poster/verify_poster.py`

Expected: fails with `docs/poster/index.html missing`.

### Task 2: Static Poster Page

**Files:**
- Create: `docs/poster/index.html`

- [x] **Step 1: Create page**

Create a self-contained HTML file using the A+B design direction: map-first identity plus demo-day contrast.

- [x] **Step 2: Verify content**

Run: `python3 docs/poster/verify_poster.py`

Expected: `PASS: poster content and structure verified`.

- [x] **Step 3: Browser check**

Open `docs/poster/index.html` through the in-app browser or file URL and confirm that the first viewport clearly shows the project name, one-line description, and route/territory visual.
