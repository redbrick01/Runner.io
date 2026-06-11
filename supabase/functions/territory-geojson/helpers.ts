export function buildFriendScopeUserIds(
  currentUserId: string,
  friendUserIds: string[],
): string[] {
  return [...new Set([currentUserId, ...friendUserIds])];
}
