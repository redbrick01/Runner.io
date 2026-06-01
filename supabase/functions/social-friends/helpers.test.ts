import {
  aggregateHistoryScores,
  buildRejectedReopenPatch,
  getRangeBounds,
  isUniqueViolation,
  nextDateKey,
  parseAnchorDate,
  parseRangeType,
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

Deno.test("parseRangeType defaults to week and rejects unsupported ranges", () => {
  assertEquals(parseRangeType(null), "week");
  assertEquals(parseRangeType(""), "week");
  assertEquals(parseRangeType("month"), "month");
  assertEquals(parseRangeType("year"), "invalid");
});

Deno.test("parseAnchorDate accepts only empty or YYYY-MM-DD dates", () => {
  const fallback = new Date(2026, 5, 1, 12, 0, 0, 0);

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

Deno.test("parseAnchorDate defaults to the current KST day", () => {
  const anchor = parseAnchorDate(null, () => new Date("2026-05-31T16:30:00Z"));
  assert(anchor.ok);
  assertEquals(anchor.submitted, "2026-06-01");
  assertEquals(anchor.date.getFullYear(), 2026);
  assertEquals(anchor.date.getMonth(), 5);
  assertEquals(anchor.date.getDate(), 1);
});

Deno.test("getRangeBounds returns KST week and month windows", () => {
  const anchor = parseAnchorDate("2026-06-03");
  assert(anchor.ok);

  assertEquals(getRangeBounds("week", anchor.date), {
    from: "2026-06-01",
    to: "2026-06-07",
  });
  assertEquals(getRangeBounds("month", anchor.date), {
    from: "2026-06-01",
    to: "2026-06-30",
  });
});

Deno.test("nextDateKey returns the following calendar date", () => {
  assertEquals(nextDateKey("2026-06-07"), "2026-06-08");
  assertEquals(nextDateKey("2026-06-30"), "2026-07-01");
  assertEquals(nextDateKey("2026-12-31"), "2027-01-01");
});

Deno.test("aggregateHistoryScores totals point history per user", () => {
  const history = aggregateHistoryScores([
    { user_id: "self", points_delta: 10 },
    { user_id: "self", points_delta: 2 },
    { user_id: "friend-b", points_delta: 7 },
  ]);

  assertEquals(history.get("self"), 12);
  assertEquals(history.get("friend-b"), 7);
});

Deno.test("isUniqueViolation recognizes friendship unique pair conflicts", () => {
  assert(isUniqueViolation({ code: "23505" }));
  assert(
    isUniqueViolation({ details: "Key violates friendships_pair_unique" }),
  );
  assertEquals(isUniqueViolation({ code: "PGRST116" }), false);
});

Deno.test("buildRejectedReopenPatch prepares same-row pending request payload", () => {
  assertEquals(
    buildRejectedReopenPatch(
      "requester-id",
      "addressee-id",
      () => new Date("2026-06-01T01:02:03.000Z"),
    ),
    {
      requester_id: "requester-id",
      addressee_id: "addressee-id",
      status: "pending",
      created_at: "2026-06-01T01:02:03.000Z",
      responded_at: null,
    },
  );
});
