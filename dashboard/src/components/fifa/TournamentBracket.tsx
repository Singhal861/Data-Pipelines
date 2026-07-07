import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { loadBracket, parseGoalsDetail, formatUtc} from "@/lib/fifa/data";
import type { BracketMatch } from "@/lib/fifa/types";

const STAGES = ["Round of 32", "Round of 16", "Quarter Final", "Semi Final", "Final"] as const;
const STAGE_LABEL: Record<string, string> = {
  "Round of 32": "ROUND OF 32",
  "Round of 16": "ROUND OF 16",
  "Quarter Final": "QUARTER FINALS",
  "Semi Final": "SEMI FINALS",
  "Final": "FINAL",
};

const CARD_H = 72;
const BASE_GAP = 8;

type Side = "home" | "away";

function posNum(p: string): number {
  const m = p.match(/-(\d+)/);
  return m ? parseInt(m[1], 10) : 0;
}

// Sort feeders so Top precedes Bottom; falls back to bracket_position number.
function sortFeeders(a: BracketMatch, b: BracketMatch): number {
  const ah = a.bracket_half ?? "";
  const bh = b.bracket_half ?? "";
  if (ah === "Top" && bh === "Bottom") return -1;
  if (ah === "Bottom" && bh === "Top") return 1;
  return posNum(a.bracket_position) - posNum(b.bracket_position);
}

function slotInfo(
  m: BracketMatch,
  side: Side,
  feedersByParent: Map<string, BracketMatch[]>,
): { name: string; logo: string | null; isPlaceholder: boolean } {
  const explicitName = side === "home" ? m.home_team_name ?? m.home_display_name : m.away_team_name ?? m.away_display_name;
  const explicitLogo = side === "home" ? m.home_team_logo : m.away_team_logo;
  const isPlaceholderName = typeof explicitName === "string" && explicitName.startsWith("Winner of");

  const feeders = feedersByParent.get(m.bracket_position) ?? [];
  if (feeders.length > 0) {
    const feeder = feeders[side === "home" ? 0 : 1];
    if (feeder) {
      if (feeder.match_status === "Finished" && feeder.winner_team_name) {
        return {
          name: feeder.winner_team_name,
          logo: feeder.winner_team_logo,
          isPlaceholder: false,
        };
      }

      const feedersReady = feeders.every((f) => f.match_status === "Finished" && !!f.winner_team_name);
      if (!feedersReady) {
        return {
          name: `Winner of ${feeder.bracket_position}`,
          logo: null,
          isPlaceholder: true,
        };
      }
    }
  }

  if (explicitName && explicitName !== "TBD") {
    return { name: explicitName, logo: explicitLogo, isPlaceholder: isPlaceholderName };
  }

  return { name: "TBD", logo: null, isPlaceholder: true };
}

function slotName(m: BracketMatch, side: Side, feedersByParent: Map<string, BracketMatch[]>): string {
  return slotInfo(m, side, feedersByParent).name;
}

export function TournamentBracket() {
  const { data } = useQuery({ queryKey: ["fifa", "bracket"], queryFn: loadBracket });
  const [selected, setSelected] = useState<BracketMatch | null>(null);
  const [hoveredTeam, setHoveredTeam] = useState<string | null>(null);

  const { columns, feedersByParent, thirdPlace } = useMemo(() => {
    const rows = data ?? [];
    const feedersByParent = new Map<string, BracketMatch[]>();
    rows.forEach((r) => {
      if (!r.feeds_into_position) return;
      const arr = feedersByParent.get(r.feeds_into_position) ?? [];
      arr.push(r);
      feedersByParent.set(r.feeds_into_position, arr);
    });
    feedersByParent.forEach((arr) => arr.sort(sortFeeders));

    const columns = STAGES.map((stage) => {
      const list = rows.filter((m) => m.stage === stage);
      list.sort((a, b) => {
        if (stage === "Round of 16") {
          return posNum(a.bracket_position) - posNum(b.bracket_position);
        }
        const pa = posNum(a.feeds_into_position ?? "");
        const pb = posNum(b.feeds_into_position ?? "");
        if (pa !== pb) return pa - pb;
        return sortFeeders(a, b);
      });
      return list;
    });

    const thirdPlace = rows.find((r) => r.stage === "Third Place") ?? null;
    return { columns, feedersByParent, thirdPlace };
  }, [data]);

  if (!data) return <div className="text-sm text-muted-foreground">Loading bracket…</div>;

  return (
    <div className="rounded-xl border border-border bg-gradient-to-br from-card via-card to-primary/5 p-4 text-foreground shadow-sm">
      <div className="overflow-x-auto">
        <div className="flex min-w-[1100px] gap-6">
          {columns.map((matches, colIdx) => {
            const slot = (CARD_H + BASE_GAP) * Math.pow(2, colIdx);
            const topOffset = (slot - CARD_H) / 2;
            return (
              <div key={STAGES[colIdx]} className="flex flex-1 flex-col">
                <div className="mb-3 flex justify-center">
                  <span className="inline-block rounded-full bg-gradient-to-r from-primary/80 via-primary to-primary/80 px-3 py-1 text-[11px] font-bold uppercase tracking-[0.15em] text-primary-foreground shadow-sm">
                    {STAGE_LABEL[STAGES[colIdx]]}
                  </span>
                </div>
                <div className="relative flex flex-col">
                  {matches.map((m, i) => {
                    const showConnector = colIdx < columns.length - 1;
                    const isTopOfPair = i % 2 === 0;
                    const revealDelay = `${colIdx * 80 + i * 40}ms`;
                    return (
                      <div
                        key={m.match_id}
                        style={{
                          height: slot,
                          paddingTop: topOffset,
                          paddingBottom: slot - CARD_H - topOffset,
                          animationDelay: revealDelay,
                          animationFillMode: "both",
                        }}
                        className="relative animate-fade-in"
                      >
                        <MatchCard
                          m={m}
                          feedersByParent={feedersByParent}
                          onOpen={() => setSelected(m)}
                          hoveredTeam={hoveredTeam}
                          onHoverTeam={setHoveredTeam}
                        />
                        {showConnector && (
                          <>
                            <span
                              className="absolute right-[-16px] h-px w-4 bg-gradient-to-r from-primary/60 to-primary"
                              style={{ top: topOffset + CARD_H / 2 }}
                            />
                            {isTopOfPair && (
                              <span
                                className="absolute right-[-16px] w-px bg-primary/60"
                                style={{ top: topOffset + CARD_H / 2, height: slot }}
                              />
                            )}
                            {isTopOfPair && (
                              <span
                                className="absolute right-[-32px] h-px w-4 bg-gradient-to-r from-primary to-primary/60"
                                style={{ top: topOffset + CARD_H / 2 + slot / 2 }}
                              />
                            )}
                          </>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {thirdPlace && (
        <div className="mt-6 flex justify-center">
          <div className="w-72">
            <div className="mb-2 flex justify-center">
              <span className="inline-block rounded-full bg-gradient-to-r from-amber-500/90 to-amber-300/90 px-3 py-1 text-[11px] font-bold uppercase tracking-[0.15em] text-amber-950 shadow-sm">
                Third Place Play-off
              </span>
            </div>
            <MatchCard
              m={thirdPlace}
              feedersByParent={feedersByParent}
              onOpen={() => setSelected(thirdPlace)}
              hoveredTeam={hoveredTeam}
              onHoverTeam={setHoveredTeam}
            />
          </div>
        </div>
      )}

      {selected && (
        <MatchDetail match={selected} feedersByParent={feedersByParent} onClose={() => setSelected(null)} />
      )}
    </div>
  );
}

function MatchCard({
  m,
  feedersByParent,
  onOpen,
  hoveredTeam,
  onHoverTeam,
}: {
  m: BracketMatch;
  feedersByParent: Map<string, BracketMatch[]>;
  onOpen: () => void;
  hoveredTeam: string | null;
  onHoverTeam: (name: string | null) => void;
}) {
  const home = slotInfo(m, "home", feedersByParent);
  const away = slotInfo(m, "away", feedersByParent);
  const finished = m.match_status === "Finished";
  const pen = m.is_penalty_shootout;
  const winner = m.winner_team_name;
  const isHovered =
    hoveredTeam !== null && (home.name === hoveredTeam || away.name === hoveredTeam);

  return (
    <div
      className={`group h-[72px] w-full overflow-hidden rounded-md border bg-card/90 text-xs shadow-sm ring-1 backdrop-blur transition-all duration-200 ${
        isHovered
          ? "border-primary ring-primary/70 shadow-[0_0_0_2px_hsl(var(--primary)/0.35)] scale-[1.02]"
          : "border-border ring-border/40 hover:border-primary/60"
      }`}
    >
      <TeamRow
        name={home.name}
        logo={home.logo}
        score={finished && !home.isPlaceholder ? m.home_score : null}
        isWinner={finished && winner === home.name}
        isHovered={hoveredTeam === home.name}
        onClick={onOpen}
        onHover={onHoverTeam}
      />
      <div className="h-px bg-primary/20" />
      <TeamRow
        name={away.name}
        logo={away.logo}
        score={finished && !away.isPlaceholder ? m.away_score : null}
        isWinner={finished && winner === away.name}
        isHovered={hoveredTeam === away.name}
        onClick={onOpen}
        onHover={onHoverTeam}
      />

      <div className="flex items-center justify-between border-t border-border bg-background/80 px-2 py-0.5 text-[9px] uppercase tracking-wider text-muted-foreground">
        <span>{m.bracket_position}</span>
        <span>
          {m.match_status === "Finished" ? (
            pen ? "PEN" : "FT"
          ) : m.match_status === "Live" ? (
            <span className="animate-pulse text-red-400">● LIVE</span>
          ) : (
            "Upcoming"
          )}
        </span>
      </div>
    </div>
  );
}

function TeamRow({
  name,
  logo,
  score,
  isWinner,
  isHovered,
  onClick,
  onHover,
}: {
  name: string;
  logo: string | null;
  score: number | null;
  isWinner: boolean;
  isHovered: boolean;
  onClick: () => void;
  onHover: (name: string | null) => void;
}) {
  const isTBD = name.startsWith("Winner of") || name === "TBD";
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => !isTBD && onHover(name)}
      onMouseLeave={() => onHover(null)}
      className={`flex h-[26px] w-full items-center gap-2 px-2 text-left transition-all duration-200 hover:bg-muted/10 ${
        isWinner
          ? "bg-gradient-to-r from-primary/25 via-primary/15 to-transparent font-semibold text-foreground"
          : "text-foreground"
      } ${isHovered ? "bg-primary/20" : ""}`}
    >
      {logo && !isTBD ? (
        <img
          src={logo}
          alt=""
          className={`h-5 w-5 rounded-sm object-contain transition-transform ${
            isWinner ? "drop-shadow-[0_0_4px_hsl(var(--primary)/0.6)]" : ""
          } ${isHovered ? "scale-110" : ""}`}
        />
      ) : (
        <div className="h-5 w-5 rounded-sm bg-muted" />
      )}
      <span className={`flex-1 truncate ${isTBD ? "italic text-muted-foreground" : ""}`}>{name}</span>
      <span className="tabular-nums text-muted-foreground">{score ?? "-"}</span>
    </button>
  );
}

function MatchDetail({
  match,
  feedersByParent,
  onClose,
}: {
  match: BracketMatch;
  feedersByParent: Map<string, BracketMatch[]>;
  onClose: () => void;
}) {
  const homeName = slotName(match, "home", feedersByParent);
  const awayName = slotName(match, "away", feedersByParent);
  const homeGoals = parseGoalsDetail(match.home_goals_detail);
  const awayGoals = parseGoalsDetail(match.away_goals_detail);
  const notFinished = match.match_status !== "Finished";
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-background/70 p-4" onClick={onClose}>
      <div
        className="w-full max-w-lg rounded-lg border border-border bg-card p-5 text-foreground shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold">
            {homeName} vs {awayName}
          </h3>
          <button onClick={onClose} className="text-sm text-muted-foreground hover:text-foreground">✕</button>
        </div>
        <div className="mt-1 text-xs text-muted-foreground">
          {match.stage} · {match.bracket_position}
          {match.stadium_name ? ` · ${match.stadium_name}, ${match.stadium_city}` : ""}
          {match.match_datetime_utc ? ` · ${formatUtc(match.match_datetime_utc)}` : ""}
        </div>
        <div className="mt-3 text-center text-2xl font-bold tabular-nums">
          {notFinished ? "vs" : `${match.home_score ?? 0} - ${match.away_score ?? 0}`}
          {match.is_penalty_shootout && <span className="ml-2 text-sm text-orange-400">(PEN)</span>}
        </div>
        <div className="mt-4 grid grid-cols-2 gap-4 text-sm">
          <GoalList title={homeName} goals={notFinished ? [] : homeGoals} />
          <GoalList title={awayName} goals={notFinished ? [] : awayGoals} />
        </div>
      </div>
    </div>
  );
}

function GoalList({ title, goals }: { title: string; goals: string[] }) {
  return (
    <div>
      <div className="mb-1 font-medium">{title}</div>
      {goals.length === 0 ? (
        <div className="text-muted-foreground">No goals</div>
      ) : (
        <ul className="space-y-1">
          {goals.map((g, i) => (
            <li key={i} className="tabular-nums text-foreground">{g}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
