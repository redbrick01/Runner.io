export type SeasonType = "week" | "month";
export type CrewSort = "score" | "members" | "activity" | "new";

export type ParsedAnchorDate =
  | { ok: true; date: Date; submitted: string }
  | { ok: false };

export function parseSeasonType(value: string | null): SeasonType | "invalid" {
  if (value === null || value.trim() === "") return "week";
  const raw = value.toLowerCase();
  if (raw === "week" || raw === "month") return raw;
  return "invalid";
}

export function parseCrewSort(value: string | null): CrewSort {
  const raw = (value ?? "").toLowerCase();
  if (
    raw === "score" ||
    raw === "members" ||
    raw === "activity" ||
    raw === "new"
  ) {
    return raw;
  }
  return "score";
}

export function parseSearchLimit(value: string | null): number {
  const parsed = Number(value ?? "");
  if (!Number.isFinite(parsed) || parsed <= 0) return 20;
  return Math.min(Math.floor(parsed), 50);
}

export function parseMemberLimit(value: string | null): number {
  const parsed = Number(value ?? "");
  if (!Number.isFinite(parsed) || parsed <= 0) return 50;
  return Math.min(Math.floor(parsed), 100);
}

export function parseBearerToken(
  authHeader: string | null,
  anonKey: string | undefined,
): string | null {
  const raw = authHeader ?? "";
  const token = raw.replace(/^Bearer\s+/i, "").trim();
  if (!token || token === raw.trim() || token === anonKey) return null;
  return token;
}

export function parseAnchorDate(
  value: string | null,
  now: () => Date = () => new Date(),
): ParsedAnchorDate {
  if (value === null || value.trim() === "") {
    return parseAnchorDate(kstDateString(now()), now);
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

export function getSeasonBounds(seasonType: SeasonType, anchor: Date): {
  from: string;
  to: string;
} {
  const day = new Date(
    anchor.getFullYear(),
    anchor.getMonth(),
    anchor.getDate(),
  );
  if (seasonType === "week") {
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

export function startOfDayKst(dateKey: string): string {
  return `${dateKey}T00:00:00+09:00`;
}

export function round2(value: number): number {
  return Number(value.toFixed(2));
}
