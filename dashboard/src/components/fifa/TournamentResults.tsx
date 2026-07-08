import { useQuery } from "@tanstack/react-query";
import { loadBracket } from "@/lib/fifa/data";
import type { BracketMatch } from "@/lib/fifa/types";

type Podium = {
  place: 1 | 2 | 3;
  label: string;
  team_name: string;
  team_logo: string | null;
};

function pickPodium(bracket: BracketMatch[] | undefined): Podium[] {
  if (!bracket) return [];
  const final = bracket.find((m) => m.stage === "Final" && m.match_status === "Finished");
  const third = bracket.find((m) => m.stage === "Third Place" && m.match_status === "Finished");
  const out: Podium[] = [];
  if (final && final.winner_team_name) {
    const winner = final.winner_team_name;
    const runnerName =
      winner === final.home_team_name ? final.away_team_name : final.home_team_name;
    const runnerLogo =
      winner === final.home_team_name ? final.away_team_logo : final.home_team_logo;
    out.push({ place: 1, label: "Winner", team_name: winner, team_logo: final.winner_team_logo });
    if (runnerName) {
      out.push({ place: 2, label: "Runner-up", team_name: runnerName, team_logo: runnerLogo });
    }
  }
  if (third && third.winner_team_name) {
    out.push({
      place: 3,
      label: "Third Place",
      team_name: third.winner_team_name,
      team_logo: third.winner_team_logo,
    });
  }
  return out;
}

const STYLES: Record<
  1 | 2 | 3,
  { ring: string; glow: string; badge: string; text: string; bg: string }
> = {
  1: {
    ring: "ring-amber-300/60",
    glow: "shadow-[0_0_45px_rgba(251,191,36,0.55)]",
    badge: "from-amber-400 to-yellow-500 text-amber-950",
    text: "text-amber-500",
    bg: "from-amber-400/15 via-amber-300/5 to-transparent",
  },
  2: {
    ring: "ring-slate-300/50",
    glow: "shadow-[0_0_35px_rgba(203,213,225,0.45)]",
    badge: "from-slate-300 to-slate-500 text-slate-900",
    text: "text-slate-400",
    bg: "from-slate-300/15 via-slate-300/5 to-transparent",
  },
  3: {
    ring: "ring-orange-400/50",
    glow: "shadow-[0_0_35px_rgba(251,146,60,0.45)]",
    badge: "from-orange-400 to-amber-600 text-orange-950",
    text: "text-orange-500",
    bg: "from-orange-400/15 via-orange-300/5 to-transparent",
  },
};

export function TournamentResults() {
  const { data } = useQuery({ queryKey: ["fifa", "bracket"], queryFn: loadBracket });
  const podium = pickPodium(data);

  if (podium.length === 0) {
    return (
      <div className="text-sm text-muted-foreground">
        Final standings will appear here once the tournament concludes.
      </div>
    );
  }

  const ordered = [
    podium.find((p) => p.place === 2),
    podium.find((p) => p.place === 1),
    podium.find((p) => p.place === 3),
  ].filter(Boolean) as Podium[];

  return (
    <div className="grid gap-4 sm:grid-cols-3 items-end">
      {ordered.map((p) => {
        const s = STYLES[p.place];
        const isWinner = p.place === 1;
        return (
          <div
            key={p.place}
            className={`relative overflow-hidden rounded-2xl border border-border bg-gradient-to-b ${s.bg} p-5 text-center ring-2 ${s.ring} ${s.glow} animate-fade-in ${
              isWinner ? "sm:-translate-y-2" : ""
            }`}
            style={{ animation: `pulse-glow 2.6s ease-in-out infinite` }}
          >
            <div
              className={`inline-block rounded-full bg-gradient-to-r ${s.badge} px-3 py-0.5 text-[10px] font-bold uppercase tracking-[0.18em]`}
            >
              {p.label}
            </div>
            <div className={`mt-2 text-4xl font-black ${s.text}`}>
              {p.place === 1 ? "🏆" : p.place === 2 ? "🥈" : "🥉"}
            </div>
            <div className="mt-3 flex flex-col items-center gap-2">
              {p.team_logo && (
                <img
                  src={p.team_logo}
                  alt=""
                  className={`h-16 w-16 object-contain ${isWinner ? "drop-shadow-[0_0_12px_rgba(251,191,36,0.7)]" : ""}`}
                />
              )}
              <div className="text-base font-bold text-foreground">{p.team_name}</div>
            </div>
          </div>
        );
      })}
      <style>{`
        @keyframes pulse-glow {
          0%, 100% { filter: brightness(1); }
          50% { filter: brightness(1.15); }
        }
      `}</style>
    </div>
  );
}
