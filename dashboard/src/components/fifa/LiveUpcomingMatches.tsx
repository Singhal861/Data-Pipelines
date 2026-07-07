import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { loadUpcomingLive, formatUtc, formatLocal, timeDelta } from "@/lib/fifa/data";

export function LiveUpcomingMatches() {
  const { data } = useQuery({ queryKey: ["fifa", "live"], queryFn: loadUpcomingLive });
  const [, force] = useState(0);
  useEffect(() => {
    const id = setInterval(() => force((n) => n + 1), 30_000);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {(data ?? []).map((m) => {
        const isLive = m.match_status === "Live";
        const delta = timeDelta(m.match_datetime_utc);
        return (
          <div key={m.match_id} className="rounded-lg border bg-card p-3 text-sm">
            <div className="flex items-center justify-between text-[11px] uppercase tracking-wide text-muted-foreground">
              <span>{m.stage}</span>
              {isLive ? (
                <span className="flex items-center gap-1 font-semibold text-red-500">
                  <span className="h-2 w-2 animate-pulse rounded-full bg-red-500" />
                  LIVE {m.live_minute ? `${m.live_minute}'` : ""}
                </span>
              ) : (
                <span>{delta.label}</span>
              )}
            </div>
            <div className="mt-2 space-y-1">
              <TeamLine name={m.home_team_name} logo={m.home_team_logo} score={m.home_score} showScore={isLive} />
              <TeamLine name={m.away_team_name} logo={m.away_team_logo} score={m.away_score} showScore={isLive} />
            </div>
            <div className="mt-2 border-t pt-2 text-[11px] text-muted-foreground">
              <div>UTC: {formatUtc(m.match_datetime_utc)}</div>
              <div>Local: {formatLocal(m.match_datetime_utc)}</div>
              <div>{m.stadium_name}, {m.stadium_city}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function TeamLine({ name, logo, score, showScore }: { name: string; logo: string; score: number; showScore: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <img src={logo} alt="" className="h-5 w-5 object-contain" />
      <span className="flex-1 truncate">{name}</span>
      {showScore && <span className="font-semibold tabular-nums">{score}</span>}
    </div>
  );
}
