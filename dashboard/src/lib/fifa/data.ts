// Central data service. Loads JSON from /data/ (public folder) by default.
// Pass an alternate base URL (e.g. Databricks published endpoint) via setDataBase.
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

let BASE = "data";
export const setDataBase = (b: string) => {
  BASE = b.replace(/\/$/, "");
};

// Some source files contain raw NaN tokens which are not valid JSON.
async function loadJson<T>(name: string): Promise<T> {
  const res = await fetch(`${BASE}/${name}`);
  const text = await res.text();
  const sanitized = text.replace(/\bNaN\b/g, "null").replace(/\bInfinity\b/g, "null");
  return JSON.parse(sanitized) as T;
}

export const loadBracket = () => loadJson<BracketMatch[]>("req_1.json");
export const loadTopScorers = () => loadJson<TopScorer[]>("req_2.json");
export const loadUpcomingLive = () => loadJson<UpcomingLiveMatch[]>("req_3.json");
export const loadFinished = () => loadJson<FinishedMatch[]>("req_4.json");
export const loadPoints = () => loadJson<PointsRow[]>("req_5a.json");
export const loadTeamHistory = () => loadJson<TeamMatchHistory[]>("req_5b.json");
export const loadGoldenBoot = () => loadJson<GoldenBootPoint[]>("req_6.json");
export const loadSummary = () => loadJson<TournamentSummary[]>("req_7.json");

// -------- Formatting helpers --------

// Goal detail is a python-style string list, e.g. "['Astfan Avstakviv (90+2)']"
// Returns list of "Player NN'" or "Player NN' (PEN)" strings.
export function parseGoalsDetail(raw: string | null | undefined): string[] {
  if (!raw) return [];
  const s = raw.trim();
  if (!s || s === "['NA']" || s === "[]") return [];
  // Extract quoted entries
  const items = [...s.matchAll(/'([^']*)'/g)].map((m) => m[1]);
  return items
    .filter((x) => x && x !== "NA")
    .map((entry) => {
      // "Player Name (23)" or "Player Name (90+2)" or "Player Name (108, PEN)"
      const m = entry.match(/^(.*)\s*\(([^)]+)\)\s*$/);
      if (!m) return entry;
      const name = m[1].trim();
      const rest = m[2].trim();
      const isPen = /pen/i.test(rest);
      const minute = rest.replace(/,?\s*pen\.?/i, "").trim();
      return `${name} ${minute}'${isPen ? " (PEN)" : ""}`;
    });
}

// UTC ISO-ish "2026-07-05 20:00:00" -> Date
export function utcToDate(utc: string): Date {
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

// Countdown / elapsed
export function timeDelta(utc: string, now: Date = new Date()): {
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
