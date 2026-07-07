import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Radar,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  ResponsiveContainer,
  Tooltip,
} from "recharts";
import { loadTopScorers } from "@/lib/fifa/data";
import type { TopScorer } from "@/lib/fifa/types";

export function TopScorers() {
  const { data } = useQuery({ queryKey: ["fifa", "scorers"], queryFn: loadTopScorers });
  const [selected, setSelected] = useState<TopScorer | null>(null);
  const top10 = (data ?? []).slice(0, 10);

  return (
    <div>
      <div className="overflow-x-auto rounded-lg border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-muted/40 text-left text-xs uppercase tracking-wide text-muted-foreground">
            <tr>
              <th className="px-3 py-2">#</th>
              <th className="px-3 py-2">Player</th>
              <th className="px-3 py-2">Team</th>
              <th className="px-3 py-2 text-right">Goals</th>
              <th className="px-3 py-2 text-right">Assists</th>
              <th className="px-3 py-2 text-right">Mins</th>
              <th className="px-3 py-2 text-right">Rating</th>
            </tr>
          </thead>
          <tbody>
            {top10.map((p) => (
              <tr
                key={p.player_id}
                className="cursor-pointer border-t hover:bg-accent/40"
                onClick={() => setSelected(p)}
              >
                <td className="px-3 py-2 tabular-nums">{p.rank}</td>
                <td className="px-3 py-2">
                  <div className="flex items-center gap-2">
                    <img src={p.player_logo} alt="" className="h-7 w-7 rounded-full object-cover" />
                    <span>{p.player_name}</span>
                  </div>
                </td>
                <td className="px-3 py-2">
                  <div className="flex items-center gap-2">
                    <img src={p.team_logo} alt="" className="h-5 w-5 object-contain" />
                    {p.team_name}
                  </div>
                </td>
                <td className="px-3 py-2 text-right tabular-nums font-semibold">{p.goals_scored}</td>
                <td className="px-3 py-2 text-right tabular-nums">{p.assists}</td>
                <td className="px-3 py-2 text-right tabular-nums">{p.minutes_played}</td>
                <td className="px-3 py-2 text-right tabular-nums">{p.rating_0_to_10.toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {selected && <PlayerModal player={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}

function PlayerModal({ player, onClose }: { player: TopScorer; onClose: () => void }) {
  const chartData = [
    { metric: "Goals", value: player.goals_percentile },
    { metric: "Assists", value: player.assists_percentile },
    { metric: "Minutes", value: player.minutes_percentile },
    { metric: "Matches", value: player.matches_percentile },
  ];
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-xl rounded-lg bg-card p-5 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img src={player.player_logo} className="h-10 w-10 rounded-full object-cover" alt="" />
            <div>
              <div className="font-semibold">{player.player_name}</div>
              <div className="text-xs text-muted-foreground">{player.team_name}</div>
            </div>
          </div>
          <button onClick={onClose} className="text-sm text-muted-foreground hover:text-foreground">✕</button>
        </div>
        <div className="mt-4 h-72 w-full">
          <ResponsiveContainer>
            <RadarChart data={chartData} outerRadius="75%">
              <PolarGrid />
              <PolarAngleAxis dataKey="metric" />
              <PolarRadiusAxis angle={30} domain={[0, 100]} />
              <Radar dataKey="value" stroke="hsl(var(--primary))" fill="var(--spider-fill)" fillOpacity={1} />
              <Tooltip />
            </RadarChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-2 grid grid-cols-2 gap-2 text-sm">
          <div>Golden Boot Rank: <b>{player.golden_boot_rank}</b></div>
          <div>Goals Behind Leader: <b>{player.goals_behind_leader}</b></div>
          <div>Most goals vs: <b>{player.most_goals_against_team_name}</b> ({player.most_goals_against_team_count})</div>
          <div>Rating: <b>{player.rating_0_to_10.toFixed(2)}</b></div>
        </div>
      </div>
    </div>
  );
}
