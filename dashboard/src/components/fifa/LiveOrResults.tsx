import { useQuery } from "@tanstack/react-query";
import { loadUpcomingLive } from "@/lib/fifa/data";
import { LiveUpcomingMatches } from "./LiveUpcomingMatches";
import { TournamentResults } from "./TournamentResults";

export function LiveOrResults() {
  const { data, isLoading } = useQuery({ queryKey: ["fifa", "live"], queryFn: loadUpcomingLive });

  if (isLoading) {
    return <div className="text-sm text-muted-foreground">Loading…</div>;
  }

  const hasLiveOrUpcoming = (data ?? []).length > 0;
  const title = hasLiveOrUpcoming ? "Live & Upcoming" : "Tournament Result";

  return (
    <section className="space-y-3 rounded-3xl border border-border bg-card p-4 shadow-sm">
      <h2 className="text-lg font-semibold tracking-tight">{title}</h2>
      {hasLiveOrUpcoming ? <LiveUpcomingMatches /> : <TournamentResults />}
    </section>
  );
}
