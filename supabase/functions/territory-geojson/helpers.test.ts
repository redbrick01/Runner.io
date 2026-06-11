import { buildFriendScopeUserIds } from "./helpers.ts";

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
  }
}

Deno.test("buildFriendScopeUserIds includes current user before friends", () => {
  assertEquals(buildFriendScopeUserIds("self", ["friend-a", "friend-b"]), [
    "self",
    "friend-a",
    "friend-b",
  ]);
});

Deno.test("buildFriendScopeUserIds removes duplicate current user entries", () => {
  assertEquals(buildFriendScopeUserIds("self", ["friend-a", "self"]), [
    "self",
    "friend-a",
  ]);
});
