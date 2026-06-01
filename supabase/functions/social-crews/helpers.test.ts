import {
  getSeasonBounds,
  nextDateKey,
  parseAnchorDate,
  parseBearerToken,
  parseCrewSort,
  parseMemberLimit,
  parseSearchLimit,
  parseSeasonType,
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

Deno.test("parseBearerToken accepts case-insensitive bearer scheme only", () => {
  assertEquals(parseBearerToken("Bearer user-token", "anon-key"), "user-token");
  assertEquals(
    parseBearerToken("bearer   user-token", "anon-key"),
    "user-token",
  );
  assertEquals(parseBearerToken("BEARER user-token", "anon-key"), "user-token");
  assertEquals(parseBearerToken("  Bearer user-token", "anon-key"), null);
  assertEquals(parseBearerToken("Basic user-token", "anon-key"), null);
  assertEquals(parseBearerToken("Bearer anon-key", "anon-key"), null);
});

Deno.test("parseSearchLimit bounds crew search work", () => {
  assertEquals(parseSearchLimit(null), 20);
  assertEquals(parseSearchLimit("5"), 5);
  assertEquals(parseSearchLimit("500"), 50);
  assertEquals(parseSearchLimit("-1"), 20);
});

Deno.test("parseMemberLimit defaults to 50 and caps at 100", () => {
  assertEquals(parseMemberLimit(null), 50);
  assertEquals(parseMemberLimit("12"), 12);
  assertEquals(parseMemberLimit("500"), 100);
  assertEquals(parseMemberLimit("-1"), 50);
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

Deno.test("parseCrewSort defaults unsupported sort to score", () => {
  assertEquals(parseCrewSort("bad"), "score");
  assertEquals(parseCrewSort("members"), "members");
  assertEquals(parseCrewSort("activity"), "activity");
  assertEquals(parseCrewSort("new"), "new");
});
