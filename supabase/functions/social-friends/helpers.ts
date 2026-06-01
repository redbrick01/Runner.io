export type RangeType = "week" | "month";

export type ParsedAnchorDate =
  | { ok: true; date: Date; submitted: string }
  | { ok: false };

export function parseRangeType(value: string | null): RangeType | "invalid" {
  if (value === null || value.trim() === "") return "week";
  const raw = value.toLowerCase();
  if (raw === "week" || raw === "month") return raw;
  return "invalid";
}

export function parseAnchorDate(
  value: string | null,
  now: () => Date = () => new Date(),
): ParsedAnchorDate {
  if (value === null || value.trim() === "") {
    const submitted = kstDateString(now());
    return parseAnchorDate(submitted, now);
  }

  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return { ok: false };

  const year = Number(m[1]);
  const month = Number(m[2]);
  const day = Number(m[3]);
  const parsed = new Date(year, month - 1, day, 12, 0, 0, 0);
  if (
    parsed.getFullYear() !== year ||
    parsed.getMonth() !== month - 1 ||
    parsed.getDate() !== day
  ) {
    return { ok: false };
  }

  return { ok: true, date: parsed, submitted: value };
}

export function kstDateString(date: Date): string {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kst.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

export function startOfWeekMonday(date: Date): Date {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = d.getDay() === 0 ? 7 : d.getDay();
  return addDays(d, -(weekday - 1));
}

export function getRangeBounds(rangeType: RangeType, anchor: Date): {
  from: string;
  to: string;
} {
  const day = new Date(
    anchor.getFullYear(),
    anchor.getMonth(),
    anchor.getDate(),
  );
  if (rangeType === "week") {
    const from = startOfWeekMonday(day);
    const to = addDays(from, 6);
    return { from: kstDateString(from), to: kstDateString(to) };
  }

  const from = new Date(day.getFullYear(), day.getMonth(), 1);
  const to = new Date(day.getFullYear(), day.getMonth() + 1, 0);
  return { from: kstDateString(from), to: kstDateString(to) };
}

export function nextDateKey(dateKey: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateKey);
  if (!m) return dateKey;

  const year = Number(m[1]);
  const month = Number(m[2]);
  const day = Number(m[3]);
  const date = new Date(year, month - 1, day, 12, 0, 0, 0);
  date.setDate(date.getDate() + 1);
  return kstDateString(date);
}

export function aggregateHistoryScores(
  rows: Array<{ user_id: string; points_delta: number | null }>,
): Map<string, number> {
  const map = new Map<string, number>();
  for (const row of rows) {
    const score = Number(row.points_delta ?? 0);
    if (!Number.isFinite(score)) continue;
    map.set(row.user_id, (map.get(row.user_id) ?? 0) + score);
  }
  return map;
}

export function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const record = error as Record<string, unknown>;
  return record.code === "23505" ||
    String(record.details ?? "").includes("friendships_pair_unique") ||
    String(record.message ?? "").includes("friendships_pair_unique");
}

export function buildRejectedReopenPatch(
  requesterId: string,
  addresseeId: string,
  now: () => Date = () => new Date(),
) {
  return {
    requester_id: requesterId,
    addressee_id: addresseeId,
    status: "pending",
    created_at: now().toISOString(),
    responded_at: null,
  };
}
