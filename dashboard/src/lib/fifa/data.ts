// Central data service.
// Fetches live data from the /api/dashboard endpoint (backed by Databricks gold
// tables). This replaces the old approach of loading static JSON files from
// /public/data/req_*.json.
import type {
  BracketMatch,
  TopScorer,
  UpcomingLiveMatch,
  FinishedMatch,
  PointsRow,
  TeamMatchHistory,
  GoldenBootPoint,
  TournamentSummary,
} from "./types";

// Same-origin by default (works both on Vercel prod/preview deployments).
// Pass an alternate URL (e.g. a different environment) via setDataBase.
let BASE = "/api/dashboard";
export const setDataBase = (b: string) => {
  BASE = b;
};

type RawRow = Record<string, string | number | boolean | null>;

interface DashboardApiResponse {
  success: boolean;
  error?: string;
  tournament_summary: RawRow[];
  fixture: RawRow[];
  top_scorers: RawRow[];
  upcoming_matches: RawRow[];
  finished_matches: RawRow[];
  team_performance: RawRow[];
  team_matches_history: RawRow[];
  golden_boot_race: RawRow[];
}

// -------- Type coercion --------
// Databricks' SQL Statement Execution API returns every column value as a
// string (or null) inside data_array, including numbers and booleans. These
// field-name lists tell the normalizer which columns to convert back to real
// numbers/booleans so existing components (which do things like
// `a.total_points - b.total_points`, `rating.toFixed(2)`, or
// `{is_penalty_shootout && <Badge/>}`) keep working exactly as before.
const NUMBER_FIELDS = new Set([
  // tournament_summary
  "total_matches",
  "completed_matches",
  "remaining_matches",
  "total_goals",
  "avg_goals_per_match",
  "teams_remaining",
  "top_scorer_goals",
  // fixture / upcoming_matches / finished_matches / team_matches_history
  "home_score",
  "away_score",
  // top_scorers
  "rank",
  "goals_scored",
  "assists",
  "matches_played",
  "minutes_played",
  "rating_0_to_10",
  "goals_percentile",
  "assists_percentile",
  "minutes_percentile",
  "matches_percentile",
  "most_goals_against_team_count",
  "golden_boot_rank",
  "goals_behind_leader",
  // upcoming_matches
  "home_top_scorer_goals",
  "away_top_scorer_goals",
  "minutes_elapsed",
  "hours_until_kickoff",
  // team_performance
  "total_points",
  "total_wins",
  "total_losses",
  "total_draws",
  "goals_for",
  "goals_against",
  "goal_difference",
  "clean_sheets",
  "rank_overall",
  // golden_boot_race
  "match_sequence",
  "goals_cumulative",
  "assists_cumulative",
  "minutes_cumulative",
  "rank_at_match",
]);

const BOOLEAN_FIELDS = new Set([
  "is_finished",
  "is_live",
  "is_knockout",
  "is_penalty_shootout",
  "is_top_3",
  "is_current_top_3",
]);

function toBoolean(v: unknown): boolean {
  if (typeof v === "boolean") return v;
  if (v === null || v === undefined) return false;
  return String(v).trim().toLowerCase() === "true";
}

function toNumberOrNull(v: unknown): number | null {
  if (v === null || v === undefined || v === "") return null;
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function normalizeRow<T>(row: RawRow): T {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) {
    if (BOOLEAN_FIELDS.has(key)) {
      out[key] = toBoolean(value);
    } else if (NUMBER_FIELDS.has(key)) {
      out[key] = toNumberOrNull(value);
    } else {
      out[key] = value;
    }
  }
  return out as T;
}

function normalizeRows<T>(rows: RawRow[] | undefined | null): T[] {
  return (rows ?? []).map((r) => normalizeRow<T>(r));
}

// -------- Fetch + in-memory cache --------
// Every dataset comes from the same /api/dashboard endpoint, but each
// component reads its own slice through a separate react-query key
// (["fifa","bracket"], ["fifa","points"], etc). Without this memoization,
// mounting the dashboard would fire 8 concurrent requests to /api/dashboard
// for a single page load. This cache de-dupes those into one network call
// and briefly reuses the result for near-simultaneous calls.
let inflight: Promise<DashboardApiResponse> | null = null;
let cachedAt = 0;
const CACHE_TTL_MS = 60_000;

async function fetchDashboard(): Promise<DashboardApiResponse> {
  if (inflight && Date.now() - cachedAt < CACHE_TTL_MS) {
    return inflight;
  }

  cachedAt = Date.now();
  inflight = fetch(BASE)
    .then(async (res) => {
      if (!res.ok) {
        throw new Error(`Dashboard API request failed (${res.status})`);
      }
      const json = (await res.json()) as DashboardApiResponse;
      if (!json.success) {
        throw new Error(json.error ?? "Dashboard API returned success: false");
      }
      return json;
    })
    .catch((err) => {
      inflight = null; // don't cache a failed request — allow retry next call
      throw err;
    });

  return inflight;
}

export const loadBracket = async () =>
  normalizeRows<BracketMatch>((await fetchDashboard()).fixture);

export const loadTopScorers = async () =>
  normalizeRows<TopScorer>((await fetchDashboard()).top_scorers);

export const loadUpcomingLive = async () =>
  normalizeRows<UpcomingLiveMatch>((await fetchDashboard()).upcoming_matches);

export const loadFinished = async () =>
  normalizeRows<FinishedMatch>((await fetchDashboard()).finished_matches);

export const loadPoints = async () =>
  normalizeRows<PointsRow>((await fetchDashboard()).team_performance);

export const loadTeamHistory = async () =>
  normalizeRows<TeamMatchHistory>((await fetchDashboard()).team_matches_history);

export const loadGoldenBoot = async () =>
  normalizeRows<GoldenBootPoint>((await fetchDashboard()).golden_boot_race);

export const loadSummary = async () =>
  normalizeRows<TournamentSummary>((await fetchDashboard()).tournament_summary);

// -------- Formatting helpers --------

// home_goals_detail / away_goals_detail are ARRAY<STRING> columns. Depending on
// the data source these can arrive as:
//   - Spark's default array-to-string form: "[NA]" or
//     "[Kylian Mbappe (23),Ousmane Dembele (77) (PEN)]"
//   - the legacy pandas/python repr form: "['NA']" or "['Player (23)']"
// This handles both.
export function parseGoalsDetail(raw: string | null | undefined): string[] {
  if (!raw) return [];
  const s = raw.trim();
  if (!s || s === "[]") return [];

  const inner = s.replace(/^\[/, "").replace(/\]$/, "").trim();
  if (!inner || inner === "NA" || inner === "'NA'") return [];

  // Legacy python-repr style: 'Player (23)', 'Player2 (45)'
  const quoted = [...inner.matchAll(/'([^']*)'/g)].map((m) => m[1]);
  // Otherwise split Spark's comma-joined entries, being careful not to split
  // inside a "(...)" group (e.g. the ", " in "(90+2, PEN)" if it ever occurs).
  const items = quoted.length > 0 ? quoted : inner.split(/,(?![^(]*\))/);

  return items
    .map((x) => x.trim())
    .filter((x) => x && x !== "NA")
    .map((entry) => {
      // "Player Name (23)" or "Player Name (90+2)" or "Player Name (108) (PEN)"
      const m = entry.match(/^(.*?)\s*\(([^)]+)\)\s*(\(pen\))?\s*$/i);
      if (!m) return entry;
      const name = m[1].trim();
      const rawRest = m[2].trim();
      const isPen = /pen/i.test(rawRest) || !!m[3];
      const minute = rawRest.replace(/,?\s*pen\.?/i, "").trim();
      return `${name} ${minute}'${isPen ? " (PEN)" : ""}`;
    });
}

// Accepts either:
//   - "YYYY-MM-DD HH:mm:ss" — assumed UTC, no offset (legacy JSON export format)
//   - a full ISO string with timezone info, e.g. "2026-07-07T00:00:00.000Z"
//     (Databricks Statement Execution API output)
export function utcToDate(utc: string): Date {
  if (!utc) return new Date(NaN);
  if (/[zZ]|[+-]\d{2}:\d{2}$/.test(utc)) {
    return new Date(utc);
  }
  return new Date(utc.replace(" ", "T") + "Z");
}

export function formatLocal(utc: string): string {
  const d = utcToDate(utc);
  return d.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

export function formatUtc(utc: string): string {
  const d = utcToDate(utc);
  return d.toUTCString().replace(":00 GMT", " UTC");
}

// e.g. "1 July 26 20:00 UTC"
export function formatUtcShort(utc: string): string {
  const d = utcToDate(utc);
  if (Number.isNaN(d.getTime())) return "";
  const day = d.getUTCDate();
  const month = d.toLocaleString("en-US", { month: "long", timeZone: "UTC" });
  const yy = String(d.getUTCFullYear()).slice(-2);
  const hh = String(d.getUTCHours()).padStart(2, "0");
  const mm = String(d.getUTCMinutes()).padStart(2, "0");
  return `${day} ${month} ${yy} ${hh}:${mm} UTC`;
}

// Countdown / elapsed
export function timeDelta(
  utc: string,
  now: Date = new Date(),
): {
  kind: "past" | "future";
  minutes: number;
  label: string;
} {
  const target = utcToDate(utc).getTime();
  const diffMs = target - now.getTime();
  const mins = Math.round(diffMs / 60000);
  const kind = mins >= 0 ? "future" : "past";
  const abs = Math.abs(mins);
  const d = Math.floor(abs / (60 * 24));
  const h = Math.floor((abs % (60 * 24)) / 60);
  const m = abs % 60;
  const parts = [d && `${d}d`, h && `${h}h`, `${m}m`].filter(Boolean).join(" ");
  return { kind, minutes: mins, label: kind === "future" ? `in ${parts}` : `${parts} ago` };
}