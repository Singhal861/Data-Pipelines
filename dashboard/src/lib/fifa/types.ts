// Types mapped from /public/data/req_*.json

export interface BracketMatch {
  match_id: string;
  stage: string;
  bracket_position: string;
  feeds_into_position: string | null;
  bracket_half: string;
  home_team_name: string | null;
  home_display_name: string | null;
  home_team_logo: string | null;
  home_score: number | null;
  home_goals_detail: string;
  away_team_name: string | null;
  away_display_name: string | null;
  away_team_logo: string | null;
  away_score: number | null;
  away_goals_detail: string;
  winner_team_name: string | null;
  winner_team_logo: string | null;
  match_status: "Finished" | "Live" | "Upcoming" | string;
  match_datetime_utc: string;
  stadium_name?: string;
  stadium_city?: string;
  actual_country?: string;
  is_penalty_shootout?: boolean;
}

export interface TopScorer {
  rank: number;
  player_id: string;
  player_name: string;
  player_logo: string;
  team_id: string;
  team_name: string;
  team_logo: string;
  goals_scored: number;
  assists: number;
  matches_played: number;
  minutes_played: number;
  rating_0_to_10: number;
  goals_percentile: number;
  assists_percentile: number;
  minutes_percentile: number;
  matches_percentile: number;
  most_goals_against_team_name: string;
  most_goals_against_team_count: number;
  golden_boot_rank: number;
  is_top_3: boolean;
  goals_behind_leader: number;
}

export interface UpcomingLiveMatch {
  match_id: string;
  match_status: "Live" | "Upcoming" | string;
  match_datetime_utc: string;
  match_date_local: string;
  home_team_id: string;
  home_team_name: string;
  home_team_logo: string;
  home_top_scorer_name: string | null;
  home_top_scorer_goals: number | null;
  home_score: number;
  away_team_id: string;
  away_team_name: string;
  away_team_logo: string;
  away_top_scorer_name: string | null;
  away_top_scorer_goals: number | null;
  away_score: number;
  stage: string;
  group_name: string | null;
  is_knockout: boolean;
  stadium_name: string;
  stadium_city: string;
  actual_country?: string;
  live_minute?: number | null;
}

export interface FinishedMatch {
  match_id: string;
  team_a_name: string;
  team_a_logo: string;
  team_b_name: string;
  team_b_logo: string;
  home_score: number;
  away_score: number;
  winner_team_name: string | null;
  winner_team_logo: string | null;
  is_penalty_shootout: boolean;
  match_datetime_utc: string;
  match_date_local: string;
  stadium_city: string;
  stadium_name: string;
  actual_country: string;
  stage: string;
  group_name: string | null;
  is_knockout: boolean;
}

export interface PointsRow {
  team_name: string;
  team_logo: string;
  total_points: number;
  total_wins: number;
  total_losses: number;
  total_draws: number;
  goals_for: number;
  goals_against: number;
  goal_difference: number;
  clean_sheets: number;
  group_name: string;
  current_stage: string;
  qualification_status: string;
  rank_overall: number;
}

export interface TeamMatchHistory {
  match_id: string;
  match_datetime_utc: string;
  match_date_local: string;
  stage: string;
  home_team_name: string;
  home_team_logo: string;
  home_score: number;
  away_team_name: string;
  away_team_logo: string;
  away_score: number;
  winner_team_name: string | null;
  winner_team_logo: string | null;
  is_penalty_shootout: boolean;
  stadium_name: string;
  stadium_city: string;
}

export interface GoldenBootPoint {
  match_sequence: number;
  player_id: string;
  player_name: string;
  player_logo: string;
  team_id: string;
  team_name: string;
  team_logo: string;
  goals_cumulative: number;
  assists_cumulative: number;
  minutes_cumulative: number;
  rank_at_match: number;
  medal: string;
  is_current_top_3: boolean;
}

export interface TournamentSummary {
  tournament_name: string;
  total_matches: number;
  completed_matches: number;
  remaining_matches: number;
  total_goals: number;
  avg_goals_per_match: number;
  current_round: string;
  teams_remaining: number;
  top_scorer_name: string;
  top_scorer_goals: number;
}
