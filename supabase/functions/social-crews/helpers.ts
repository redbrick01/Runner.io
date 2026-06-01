export type SeasonType = "week" | "month";
export type CrewSort = "score" | "members" | "activity" | "new";

export type ParsedAnchorDate =
  | { ok: true; date: Date; submitted: string }
  | { ok: false };

export type CrewMetric = {
  rawScore: number;
  maintenancePenalty: number;
  finalScore: number;
  areaM2: number;
};

export type SortableCrew = {
  id: string;
  name: string;
  member_count: number;
  season_score: number;
  cumulative_area_m2: number;
  last_contributed_at: string | null;
  created_at: string;
};

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

export function candidateLimitForSearch(sort: CrewSort, limit: number): number {
  if (sort === "new") return limit;
  return Math.min(Math.max(limit * 2, 50), 100);
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

export function aggregateCrewMetrics(
  rows: Array<{
    crew_id: string;
    contribution_score: number | null;
    contribution_area_m2: number | null;
  }>,
): Map<string, CrewMetric> {
  const totals = new Map<string, { score: number; area: number }>();
  for (const row of rows) {
    const score = Number(row.contribution_score ?? 0);
    const area = Number(row.contribution_area_m2 ?? 0);
    const current = totals.get(row.crew_id) ?? { score: 0, area: 0 };
    totals.set(row.crew_id, {
      score: current.score + (Number.isFinite(score) ? score : 0),
      area: current.area + (Number.isFinite(area) ? area : 0),
    });
  }

  const metrics = new Map<string, CrewMetric>();
  for (const [crewId, total] of totals) {
    const maintenancePenalty = 0;
    metrics.set(crewId, {
      rawScore: total.score,
      maintenancePenalty,
      finalScore: round2(total.score - maintenancePenalty),
      areaM2: round2(total.area),
    });
  }
  return metrics;
}

export function sortCrewSummaries<T extends SortableCrew>(
  crews: T[],
  sort: CrewSort,
): T[] {
  return [...crews].sort((a, b) => {
    if (sort === "members" && b.member_count !== a.member_count) {
      return b.member_count - a.member_count;
    }
    if (sort === "activity") {
      const aTime = Date.parse(a.last_contributed_at ?? "");
      const bTime = Date.parse(b.last_contributed_at ?? "");
      const aValue = Number.isFinite(aTime) ? aTime : 0;
      const bValue = Number.isFinite(bTime) ? bTime : 0;
      if (bValue !== aValue) return bValue - aValue;
    }
    if (sort === "new") {
      const createdDiff = Date.parse(b.created_at) - Date.parse(a.created_at);
      if (createdDiff !== 0) return createdDiff;
    }
    if (b.season_score !== a.season_score) {
      return b.season_score - a.season_score;
    }
    if (b.cumulative_area_m2 !== a.cumulative_area_m2) {
      return b.cumulative_area_m2 - a.cumulative_area_m2;
    }
    return a.name.localeCompare(b.name) || a.id.localeCompare(b.id);
  });
}
