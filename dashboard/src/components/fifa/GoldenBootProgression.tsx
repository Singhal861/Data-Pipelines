import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  Legend,
  CartesianGrid,
  type TooltipProps,
} from "recharts";
import { loadGoldenBoot } from "@/lib/fifa/data";

const LINE_COLORS = ["#eab308", "#38bdf8", "#34d399", "#fbbf24", "#a78bfa", "#22d3ee", "#f472b6", "#60a5fa"];
const GRID_STROKE = "rgba(148, 163, 184, 0.22)";

function GoldenBootTooltip({ active, payload, label }: TooltipProps<number, string>) {
  if (!active || !payload?.length) {
    return null;
  }

  return (
    <div className="rounded-2xl border border-white/10 bg-slate-950/95 px-3 py-2 text-xs text-slate-100 shadow-2xl shadow-black/20 backdrop-blur-sm">
      <div className="mb-2 text-[11px] uppercase tracking-[0.18em] text-slate-400">{label}</div>
      {payload.map((entry) => (
        <div key={entry.dataKey} className="flex items-center justify-between gap-3 py-1">
          <div className="flex items-center gap-2">
            <span
              className="h-2.5 w-2.5 rounded-full"
              style={{ backgroundColor: entry.color }}
            />
            <span className="truncate text-[11px] text-slate-100">{entry.name}</span>
          </div>
          <span className="font-semibold text-slate-100">{entry.value}</span>
        </div>
      ))}
    </div>
  );
}

export function GoldenBootProgression() {
  const { data } = useQuery({ queryKey: ["fifa", "gb"], queryFn: loadGoldenBoot });

  const { goalsChart, players, playerMeta, leaders, strokePatterns } = useMemo(() => {
    const rows = data ?? [];
    if (rows.length === 0)
      return { goalsChart: [], players: [] as string[], playerMeta: {} as Record<string, { name: string; logo: string | null; team: string }>, leaders: [] };

    // Player metadata
    const meta: Record<string, { name: string; logo: string | null; team: string }> = {};
    rows.forEach((r) => {
      meta[r.player_id] = { name: r.player_name, logo: r.player_logo, team: r.team_name };
    });
    const playerIds = Array.from(new Set(rows.map((r) => r.player_id)));

    const seqs = Array.from(new Set(rows.map((r) => r.match_sequence))).sort((a, b) => a - b);

    // sequence -> playerId -> row
    const idx: Record<number, Record<string, (typeof rows)[number]>> = {};
    rows.forEach((r) => {
      (idx[r.match_sequence] ||= {})[r.player_id] = r;
    });

    // Forward-fill cumulative goals across the sequence timeline
    const lastGoals: Record<string, number> = {};
    playerIds.forEach((p) => (lastGoals[p] = 0));

    const goalsChart: Array<Record<string, number | string>> = [];
    // Baseline (0,0)
    const baseline: Record<string, number | string> = { match: "0" };
    playerIds.forEach((pid) => (baseline[meta[pid].name] = 0));
    goalsChart.push(baseline);

    seqs.forEach((s) => {
      const row: Record<string, number | string> = { match: `M${s}` };
      playerIds.forEach((pid) => {
        const cur = idx[s]?.[pid];
        if (cur) lastGoals[pid] = cur.goals_cumulative;
        row[meta[pid].name] = lastGoals[pid];
      });
      goalsChart.push(row);
    });

    // Current standings: prefer rows flagged is_current_top_3, else last seq
    const currentRows = rows.filter((r) => r.is_current_top_3);
    const leaderPool = currentRows.length
      ? currentRows
      : rows.filter((r) => r.match_sequence === seqs[seqs.length - 1]);
    const leaders = [...leaderPool].sort(
      (a, b) =>
        a.rank_at_match - b.rank_at_match ||
        b.goals_cumulative - a.goals_cumulative ||
        b.assists_cumulative - a.assists_cumulative ||
        a.minutes_cumulative - b.minutes_cumulative,
    );

    const patterns = ["", "6 4", "2 4 6 4", "1 4"];
    const duplicatePathGroups = new Map<string, string[]>();

    playerIds.map((id) => meta[id].name).forEach((name) => {
      const pathKey = goalsChart.map((row) => row[name]).join("|");
      const group = duplicatePathGroups.get(pathKey);
      if (group) {
        group.push(name);
      } else {
        duplicatePathGroups.set(pathKey, [name]);
      }
    });

    const strokePatterns: Record<string, string> = {};
    duplicatePathGroups.forEach((group) => {
      group.forEach((name, index) => {
        strokePatterns[name] = patterns[index % patterns.length];
      });
    });

    return {
      goalsChart,
      players: playerIds.map((id) => meta[id].name),
      playerMeta: meta,
      leaders,
      strokePatterns,
    };
  }, [data]);

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <div className="lg:col-span-2 rounded-lg border bg-card p-3">
        <div className="mb-2 flex items-baseline justify-between">
          <div className="text-sm font-medium">Golden Boot Race — cumulative goals</div>
          <div className="text-[11px] text-muted-foreground">X: match · Y: goals</div>
        </div>
        <div className="h-72">
          <ResponsiveContainer>
            <LineChart data={goalsChart} margin={{ top: 20, right: 16, left: 8, bottom: 16 }}>
              <defs>
                <linearGradient id="line-highlight" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#facc15" stopOpacity={0.24} />
                  <stop offset="100%" stopColor="#facc15" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid stroke={GRID_STROKE} strokeDasharray="4 4" vertical={false} />
              <XAxis
                dataKey="match"
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                angle={-25}
                textAnchor="end"
                height={28}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                allowDecimals={false}
                domain={[0, (max: number) => Math.max(3, Math.ceil(max + 1))]}
                tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
              />
              <Tooltip content={<GoldenBootTooltip />} cursor={{ stroke: "rgba(148, 163, 184, 0.28)", strokeDasharray: "3 3" }} />
              <Legend
                align="center"
                verticalAlign="bottom"
                iconType="circle"
                iconSize={8}
                wrapperStyle={{ fontSize: 11, paddingTop: 8, color: "var(--muted-foreground)" }}
              />
              {players.map((p, i) => (
                <Line
                  key={p}
                  type="monotone"
                  dataKey={p}
                  stroke={LINE_COLORS[i % LINE_COLORS.length]}
                  strokeWidth={3}
                  dot={false}
                  activeDot={{ r: 5, strokeWidth: 2, fill: "#fff" }}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeDasharray={strokePatterns?.[p]}
                  opacity={0.95}
                  isAnimationActive={false}
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-2 text-[11px] text-muted-foreground">
          Baseline starts at 0 goals before the first recorded match. Lines forward-fill on matches where
          a player didn't appear in the top-3 snapshot.
        </div>
      </div>

      <div className="rounded-lg border bg-card p-3">
        <div className="mb-2 text-sm font-medium">Current Standings</div>
        <ul className="space-y-2 text-sm">
          {leaders.map((p) => (
            <li key={p.player_id} className="flex items-center gap-2">
              <span className="w-6 text-lg">{p.medal || `#${p.rank_at_match}`}</span>
              {p.player_logo ? (
                <img src={p.player_logo} alt="" className="h-8 w-8 rounded-full object-cover border" />
              ) : (
                <div className="h-8 w-8 rounded-full bg-muted" />
              )}
              <div className="flex-1 min-w-0">
                <div className="truncate">{p.player_name}</div>
                <div className="flex items-center gap-1 text-xs text-muted-foreground">
                  {p.team_logo && <img src={p.team_logo} alt="" className="h-3 w-3" />}
                  <span className="truncate">{p.team_name}</span>
                </div>
              </div>
              <div className="text-right tabular-nums">
                <div className="font-semibold">{p.goals_cumulative}g</div>
                <div className="text-[10px] text-muted-foreground">
                  {p.assists_cumulative}a · {p.minutes_cumulative}′
                </div>
              </div>
            </li>
          ))}
        </ul>
        <div className="mt-3 border-t pt-2 text-[11px] text-muted-foreground">
          FIFA tiebreakers: goals → assists → fewer minutes.
        </div>
      </div>
    </div>
  );
}
