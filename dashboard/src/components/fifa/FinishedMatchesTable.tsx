import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { loadFinished, formatUtc } from "@/lib/fifa/data";

export function FinishedMatchesTable() {
  const { data } = useQuery({ queryKey: ["fifa", "finished"], queryFn: loadFinished });
  const [q, setQ] = useState("");
  const rows = useMemo(() => {
    const list = (data ?? []).slice().sort(
      (a, b) => b.match_datetime_utc.localeCompare(a.match_datetime_utc),
    );
    if (!q) return list;
    const s = q.toLowerCase();
    return list.filter(
      (m) =>
        m.team_a_name.toLowerCase().includes(s) ||
        m.team_b_name.toLowerCase().includes(s) ||
        (m.stage ?? "").toLowerCase().includes(s),
    );
  }, [data, q]);

  return (
    <div className="space-y-2">
      <div className="flex flex-col gap-3">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search team or stage…"
          className="w-full max-w-xs rounded-md border bg-background px-3 py-1.5 text-sm"
        />
        <div className="overflow-auto rounded-lg border bg-card" style={{ maxHeight: 440 }}>
          <table className="w-full text-sm">
            <thead className="sticky top-0 z-10 bg-muted/80 text-left text-xs uppercase tracking-wide text-muted-foreground backdrop-blur">
              <tr>
                <th className="px-3 py-2">Date (UTC)</th>
                <th className="px-3 py-2">Stage</th>
                <th className="px-3 py-2">Match</th>
                <th className="px-3 py-2 text-right">Score</th>
                <th className="px-3 py-2">Winner</th>
                <th className="px-3 py-2">Venue</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((m) => (
                <tr key={m.match_id} className="border-t border-border hover:bg-muted/10">
                  <td className="px-3 py-2 whitespace-nowrap">{formatUtc(m.match_datetime_utc)}</td>
                  <td className="px-3 py-2">{m.stage}</td>
                  <td className="px-3 py-2">
                    <div className="flex items-center gap-2">
                      <img src={m.team_a_logo} alt="" className="h-5 w-5 object-contain" />
                      {m.team_a_name}
                      <span className="text-muted-foreground">vs</span>
                      <img src={m.team_b_logo} alt="" className="h-5 w-5 object-contain" />
                      {m.team_b_name}
                    </div>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums font-semibold">
                    {m.home_score}-{m.away_score}
                    {m.is_penalty_shootout && <span className="ml-1 text-xs text-orange-500">(PEN)</span>}
                  </td>
                  <td className="px-3 py-2">{m.winner_team_name ?? "Draw"}</td>
                  <td className="px-3 py-2 text-xs text-muted-foreground">
                    {m.stadium_name}, {m.stadium_city}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
