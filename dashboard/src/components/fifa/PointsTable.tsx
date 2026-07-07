import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { loadPoints, loadTeamHistory, formatUtc } from "@/lib/fifa/data";

export function PointsTable() {
  const { data: points } = useQuery({ queryKey: ["fifa", "points"], queryFn: loadPoints });
  const { data: history } = useQuery({ queryKey: ["fifa", "history"], queryFn: loadTeamHistory });
  const [team, setTeam] = useState<string | null>(null);

  const rows = useMemo(
    () =>
      (points ?? [])
        .slice()
        .sort(
          (a, b) =>
            b.total_points - a.total_points ||
            b.goal_difference - a.goal_difference ||
            b.goals_for - a.goals_for,
        ),
    [points],
  );

  const teamHistory = useMemo(
    () =>
      (history ?? [])
        .filter((m) => m.home_team_name === team || m.away_team_name === team)
        .sort((a, b) => a.match_datetime_utc.localeCompare(b.match_datetime_utc)),
    [history, team],
  );

  return (
    <div>
      <div className="overflow-x-auto rounded-lg border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-muted/40 text-left text-xs uppercase tracking-wide text-muted-foreground">
            <tr>
              <th className="px-3 py-2">#</th>
              <th className="px-3 py-2">Team</th>
              <th className="px-3 py-2">Group</th>
              <th className="px-3 py-2 text-right">P</th>
              <th className="px-3 py-2 text-right">W</th>
              <th className="px-3 py-2 text-right">D</th>
              <th className="px-3 py-2 text-right">L</th>
              <th className="px-3 py-2 text-right">GF</th>
              <th className="px-3 py-2 text-right">GA</th>
              <th className="px-3 py-2 text-right">GD</th>
              <th className="px-3 py-2 text-right">Pts</th>
              <th className="px-3 py-2">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr
                key={r.team_name}
                className="cursor-pointer border-t hover:bg-accent/40"
                onClick={() => setTeam(r.team_name)}
              >
                <td className="px-3 py-2 tabular-nums">{i + 1}</td>
                <td className="px-3 py-2">
                  <div className="flex items-center gap-2">
                    <img src={r.team_logo} alt="" className="h-5 w-5 object-contain" />
                    {r.team_name}
                  </div>
                </td>
                <td className="px-3 py-2">{r.group_name}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.total_wins + r.total_draws + r.total_losses}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.total_wins}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.total_draws}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.total_losses}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.goals_for}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.goals_against}</td>
                <td className="px-3 py-2 text-right tabular-nums">{r.goal_difference}</td>
                <td className="px-3 py-2 text-right font-semibold tabular-nums">{r.total_points}</td>
                <td className="px-3 py-2 text-xs">{r.qualification_status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {team && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setTeam(null)}>
          <div className="w-full max-w-2xl rounded-lg bg-card p-5 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold">{team} — Match History</h3>
              <button onClick={() => setTeam(null)} className="text-sm text-muted-foreground hover:text-foreground">✕</button>
            </div>
            <div className="mt-3 max-h-[60vh] overflow-y-auto">
              <table className="w-full text-sm">
                <tbody>
                  {teamHistory.map((m) => (
                    <tr key={m.match_id} className="border-t">
                      <td className="px-2 py-2 text-xs text-muted-foreground">{formatUtc(m.match_datetime_utc)}</td>
                      <td className="px-2 py-2">{m.stage}</td>
                      <td className="px-2 py-2">
                        {m.home_team_name} {m.home_score}-{m.away_score} {m.away_team_name}
                        {m.is_penalty_shootout && <span className="ml-1 text-xs text-orange-500">(PEN)</span>}
                      </td>
                      <td className="px-2 py-2 text-xs">
                        {m.winner_team_name === team ? "W" : m.winner_team_name ? "L" : "D"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
