import { useQuery } from "@tanstack/react-query";
import { loadSummary } from "@/lib/fifa/data";

export function TournamentSummary() {
  const { data } = useQuery({ queryKey: ["fifa", "summary"], queryFn: loadSummary });
  const s = data?.[0];
  if (!s) return <div className="text-sm text-muted-foreground">Loading summary…</div>;
  const cell = (label: string, value: string | number) => (
    <div className="rounded-lg border bg-card p-3">
      <div className="text-[11px] uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-8">
      {cell("Tournament", s.tournament_name)}
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
