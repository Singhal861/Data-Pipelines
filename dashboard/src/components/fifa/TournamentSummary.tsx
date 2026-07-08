import { useQuery } from "@tanstack/react-query";
import { loadSummary } from "@/lib/fifa/data";

export function TournamentSummary() {
  const { data } = useQuery({ queryKey: ["fifa", "summary"], queryFn: loadSummary });
  const s = data?.[0];
  if (!s) return <div className="text-sm text-muted-foreground">Loading summary…</div>;
  const cell = (label: string, value: string | number) => (
    <div className="min-w-0 rounded-lg border bg-card p-3">
      <div className="truncate text-[11px] uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className="mt-1 truncate text-xl font-semibold" title={String(value)}>{value}</div>
    </div>
  );
  return (
    <div
      className="grid gap-3"
      style={{ gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))" }}
    >
      {cell("Tournament", `FIFA WC 26`)}
      {cell("Matches", `${s.completed_matches}/${s.total_matches}`)}
      {cell("Remaining", s.remaining_matches)}
      {cell("Goals", s.total_goals)}
      {cell("Avg Goals", s.avg_goals_per_match.toFixed(2))}
      {cell("Round", s.current_round)}
      {cell("Teams Left", s.teams_remaining)}
      {cell("Top Scorer", `${s.top_scorer_name} (${s.top_scorer_goals})`)}
    </div>
  );
}
