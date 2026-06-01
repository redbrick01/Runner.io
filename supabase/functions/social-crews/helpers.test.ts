import {
  aggregateCrewMetrics,
  getSeasonBounds,
  nextDateKey,
  parseAnchorDate,
  parseCrewSort,
  parseSeasonType,
  sortCrewSummaries,
} from "./helpers.ts";

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
  }
}

Deno.test("parseSeasonType defaults to week and rejects unsupported values", () => {
  assertEquals(parseSeasonType(null), "week");
  assertEquals(parseSeasonType(""), "week");
  assertEquals(parseSeasonType("month"), "month");
  assertEquals(parseSeasonType("year"), "invalid");
});

Deno.test("parseAnchorDate accepts only empty or YYYY-MM-DD dates", () => {
  const fallback = new Date("2026-05-31T16:30:00.000Z");

  const empty = parseAnchorDate(null, () => fallback);
  assert(empty.ok);
  assertEquals(empty.submitted, "2026-06-01");

  const valid = parseAnchorDate("2026-06-01");
  assert(valid.ok);
  assertEquals(valid.submitted, "2026-06-01");
  assertEquals(valid.date.getFullYear(), 2026);
  assertEquals(valid.date.getMonth(), 5);
  assertEquals(valid.date.getDate(), 1);

  assertEquals(parseAnchorDate("2026-06-01T00:00:00Z"), { ok: false });
  assertEquals(parseAnchorDate("2026-02-30"), { ok: false });
});

Deno.test("getSeasonBounds returns KST week and month windows", () => {
  const anchor = parseAnchorDate("2026-06-03");
  assert(anchor.ok);

  assertEquals(getSeasonBounds("week", anchor.date), {
    from: "2026-06-01",
    to: "2026-06-07",
  });
  assertEquals(getSeasonBounds("month", anchor.date), {
    from: "2026-06-01",
    to: "2026-06-30",
  });
});

Deno.test("nextDateKey returns the following calendar date", () => {
  assertEquals(nextDateKey("2026-06-07"), "2026-06-08");
  assertEquals(nextDateKey("2026-06-30"), "2026-07-01");
  assertEquals(nextDateKey("2026-12-31"), "2027-01-01");
});

Deno.test("aggregateCrewMetrics totals season score and area per crew", () => {
  const metrics = aggregateCrewMetrics([
    {
      crew_id: "crew-a",
      contribution_score: 12.345,
      contribution_area_m2: 40,
    },
    {
      crew_id: "crew-a",
      contribution_score: 2,
      contribution_area_m2: 3.5,
    },
    {
      crew_id: "crew-b",
      contribution_score: null,
      contribution_area_m2: 10,
    },
  ]);

  assertEquals(metrics.get("crew-a"), {
    rawScore: 14.345,
    maintenancePenalty: 0,
    finalScore: 14.35,
    areaM2: 43.5,
  });
  assertEquals(metrics.get("crew-b"), {
    rawScore: 0,
    maintenancePenalty: 0,
    finalScore: 0,
    areaM2: 10,
  });
});

Deno.test("sortCrewSummaries supports score, members, activity, and new modes", () => {
  const crews = [
    {
      id: "old-active",
      name: "Old Active",
      member_count: 8,
      season_score: 10,
      cumulative_area_m2: 100,
      last_contributed_at: "2026-06-03T00:00:00Z",
      created_at: "2026-05-01T00:00:00Z",
    },
    {
      id: "newer",
      name: "Newer",
      member_count: 2,
      season_score: 30,
      cumulative_area_m2: 10,
      last_contributed_at: null,
      created_at: "2026-06-02T00:00:00Z",
    },
    {
      id: "members",
      name: "Members",
      member_count: 20,
      season_score: 5,
      cumulative_area_m2: 200,
      last_contributed_at: "2026-06-01T00:00:00Z",
      created_at: "2026-05-20T00:00:00Z",
    },
  ];

  assertEquals(parseCrewSort("bad"), "score");
  assertEquals(sortCrewSummaries(crews, "score").map((crew) => crew.id), [
    "newer",
    "old-active",
    "members",
  ]);
  assertEquals(sortCrewSummaries(crews, "members").map((crew) => crew.id), [
    "members",
    "old-active",
    "newer",
  ]);
  assertEquals(sortCrewSummaries(crews, "activity").map((crew) => crew.id), [
    "old-active",
    "members",
    "newer",
  ]);
  assertEquals(sortCrewSummaries(crews, "new").map((crew) => crew.id), [
    "newer",
    "members",
    "old-active",
  ]);
});
