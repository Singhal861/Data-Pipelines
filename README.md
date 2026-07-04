# FIFA World Cup 2026 Dashboard - dbt Data Pipeline

## 📊 Project Overview

Complete dbt pipeline for FIFA World Cup 2026 dashboard, implementing Bronze → Silver → Gold medallion architecture. Supports 6 core dashboard requirements with live updates, match tracking, player statistics, and tournament visualization.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BRONZE LAYER                              │
│              (Raw Data - No Transformations)                 │
├─────────────────────────────────────────────────────────────┤
│  📋 players              (78 from SportScore API)           │
│  📋 teams                (48 teams)                          │
│  📋 matches              (104 matches)                       │
│  📋 group_standings      (60 group entries)                  │
│  📋 stadiums             (16 venues)                         │
│  📋 goal_events          (300+ match-level goals)            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    SILVER LAYER                              │
│            (Cleaned, Joined, Type-2 SCD)                     │
├─────────────────────────────────────────────────────────────┤
│  🥈 silver_teams                                             │
│  🥈 silver_players                                           │
│  🥈 silver_matches          (Group + Knockout unified)       │
│  🥈 silver_goal_events      (Normalized goal timeline)       │
│  🥈 silver_group_standings                                   │
│  🥈 silver_knockout_bracket (Tournament tree structure)      │
│  🥈 silver_stadiums                                          │
│  🥈 silver_player_stats_history (SCD Type 2 snapshots)       │
│  🥈 silver_group_standings_history (SCD Type 2)              │
│  🥈 ref_stadium_enriched    (Manual: timezone mapping)       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                     GOLD LAYER                               │
│               (Dashboard-Ready Models)                       │
├─────────────────────────────────────────────────────────────┤
│  🏆 gold_tournament_bracket   (Req #1: Bracket viz)         │
│  🏆 gold_player_leaderboard   (Req #2: Top 10 scorers)      │
│  🏆 gold_match_schedule       (Req #3,#4: Live/upcoming)    │
│  🏆 gold_points_table         (Req #5: Group standings)     │
│  🏆 gold_golden_boot_race     (Req #6: Top 3 timeline)      │
│  🏆 gold_team_summary         (Team aggregates)             │
│  🏆 gold_team_goals           (Match-level goal details)    │
│  🏆 gold_tournament_summary   (Tournament totals)           │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Dashboard Requirements

### **Requirement #1: Tournament Bracket Visualization**
**Display:** A vs B → Winner C, team flags, stage progression  
**On Click:** Total wins, losses, top 2 scorers, points  
**Gold Model:** `gold_tournament_bracket`

**Columns:**
- `match_id`, `round` (R32, R16, QF, SF, Final, 3rd)
- `home_team_name`, `away_team_name`, `winner_name`
- `home_team_logo`, `away_team_logo`
- `match_datetime_utc`, `stadium_name`, `stadium_city`
- `display_order` (for bracket tree rendering)

---

### **Requirement #2: Top 10 Scorers Leaderboard**
**Display:** Top 10 players with goals, assists, rating, minutes, matches  
**On Click:** Spider chart (5 metrics) + highest goals vs team  
**Gold Model:** `gold_player_leaderboard`

**Columns:**
- `player_name`, `team_name`, `team_logo`
- `goals_scored`, `assists`, `rating` (out of 10)
- `matches_played`, `minutes_played`
- `highest_goals_vs_team` (e.g., "Brazil (3 goals)")

**Tiebreaker Rules (FIFA Golden Boot):**
1. Most goals
2. Most assists
3. Fewest minutes played

---

### **Requirement #3: Live & Upcoming Knockout Matches**
**Display:** Team A vs B (live/upcoming), team logos, top scorer per team, UTC time, stadium & city  
**Gold Model:** `gold_match_schedule` (filter: `is_knockout = TRUE`)

**Columns:**
- `match_status` (Live/Upcoming/Finished)
- `home_team_logo`, `away_team_logo`
- `home_top_scorer_name`, `away_top_scorer_name` (match-level)
- `match_datetime_utc`, `match_date_local`
- `stadium_name`, `stadium_city`
- `minutes_elapsed`, `hours_until_kickoff`

---

### **Requirement #4: Upcoming Group Stage Matches**
**Display:** Team A vs B, team logos, UTC time, stadium & city  
**Gold Model:** `gold_match_schedule` (filter: `is_knockout = FALSE`)

**Columns:** Same as Req #3, filtered to group stage only

---

### **Requirement #5: Points Table (Group Standings)**
**Display:** Team logo, points, wins, losses, qualification status  
**Order By:** Points DESC, Goal Difference DESC, Goals For DESC  
**Gold Model:** `gold_points_table`

**Columns:**
- `rank_overall`, `rank_in_group`
- `team_name`, `team_logo`
- `points`, `wins`, `draws`, `losses`
- `goals_for`, `goals_against`, `goal_difference`
- `qualification_status` (Qualified/Disqualified/In Progress)

**Qualification Rules:**
- Top 2 teams per group qualify for knockout stage
- Points: Win = 3, Draw = 1, Loss = 0

---

### **Requirement #6: Golden Boot Race (Line Graph)**
**Display:** Top 3 scorers progression match-by-match  
**Handles Ties:** 1,1,2 or 1,2,2 or 1,2,3,3 (DENSE_RANK)  
**Gold Model:** `gold_golden_boot_race`

**Columns:**
- `player_name`, `team_name`
- `match_sequence` (chronological match number)
- `goals_cumulative` (total goals up to this match)
- `assists_cumulative`
- `rank_at_match` (1-3, with ties)

**Data Grain:** ONE ROW PER PLAYER PER MATCH

---

## 🗂️ Key Data Models

### **Silver Layer**

#### **silver_matches**
Unified match table (group + knockout).
```sql
-- Columns:
match_id, stage, home_team_name, away_team_name,
home_score, away_score, winner_team_id,
match_date_local, stadium_id, is_finished
```

#### **silver_goal_events**
Normalized goal timeline (one row per goal).
```sql
-- Columns:
goal_event_id, match_id, team_id, scorer_name,
minute, minute_base, injury_time_minutes,
is_penalty, is_home_goal
```

#### **silver_player_stats_history (SCD Type 2)**
Player statistics snapshots over time.
```sql
-- Columns:
player_id, goals_scored, assists, rating,
matches_played, minutes_played,
valid_from, valid_to, is_current
```

#### **ref_stadium_enriched (Manual Table)**
Static reference for timezone conversion.
```sql
-- Columns:
stadium_id, city, actual_country,
utc_offset_hours, timezone_name
```
**Created once via notebook, not managed by dbt.**

---

### **Gold Layer**

#### **gold_match_schedule**
Serves BOTH Req #3 (knockout) and Req #4 (group stage).
```sql
-- Filter for Req #3:
WHERE is_knockout = TRUE AND match_status IN ('Live', 'Upcoming')

-- Filter for Req #4:
WHERE is_knockout = FALSE AND match_status = 'Upcoming'
```

#### **gold_player_leaderboard**
Top 10 scorers with complete stats.
```sql
-- Uses:
- player_stats_history (current snapshot)
- goal_events (highest goals vs team)

-- Tiebreaker:
ORDER BY goals DESC, assists DESC, minutes_played ASC
LIMIT 10
```

#### **gold_golden_boot_race**
Match-by-match timeline for top 3 scorers.
```sql
-- Uses SCD Type 2 snapshots
-- Maps valid_from → match_sequence
-- Calculates cumulative goals per match
-- DENSE_RANK handles ties (1,1,2 or 1,2,3,3)
```

---

## 🧪 Data Quality Tests

### **Silver Layer Tests** (models/silver/silver_matches.yml)

**silver_matches:**
- `match_id`: unique, not_null
- `stage`: accepted_values (Group Stage, R32, R16, QF, SF, Final, 3rd)
- `is_finished`: not_null

**silver_goal_events:**
- `goal_event_id`: unique, not_null
- `match_id`: relationships to silver_matches
- `team_id`, `scorer_name`, `minute`: not_null
- `is_penalty`, `is_home_goal`: accepted_values (true/false)

**silver_knockout_bracket:**
- `match_id`: unique, not_null
- `round`: accepted_values (R32, R16, QF, SF, Final, 3rd)

---

### **Pre-Gold Tests** (tests/pre_gold/)

**assert_scorer_name_completeness.sql**
- Fails if any finished match has goals with NULL/blank scorer_name
- Critical for: gold_match_schedule, gold_team_summary

**assert_all_matches_have_timezone_mapping.sql**
- Fails if any match stadium is missing in ref_stadium_enriched
- Critical for: UTC conversion in gold_match_schedule

**assert_top_scorers_have_complete_stats.sql**
- Fails if top scorers (goals > 0) have NULL assists/minutes/matches
- Critical for: gold_player_leaderboard

**assert_match_datetime_parseable.sql**
- Fails if match_date_local has invalid format for UTC conversion

**assert_all_players_have_valid_teams.sql**
- Fails if goal events reference non-existent teams

**assert_no_orphaned_goal_events.sql**
- Fails if goal events reference non-existent matches

---

## 🚀 Running the Pipeline

### **1. Prerequisites**
```bash
# Install dbt
pip install dbt-databricks

# Install dbt packages (dbt_utils, dbt_expectations)
dbt deps
```

### **2. Create ref_stadium_enriched (One-Time)**
Run notebook: Create the static timezone mapping table in `singhal.fifa_worldcup_silver.ref_stadium_enriched`.

### **3. Run Silver Layer**
```bash
dbt run --select silver_*
```

### **4. Run Pre-Gold Tests**
```bash
dbt test --select test_type:generic,silver_*
dbt test --select pre_gold
```

### **5. Run Gold Layer**
```bash
dbt run --select gold_*
```

### **6. Full Pipeline**
```bash
dbt build  # Run + Test in dependency order
```

---

## 📁 Project Structure

```
Data-Pipelines/
├── dbt_project.yml          # dbt config
├── profiles.yml             # Databricks connection
├── packages.yml             # dbt_utils, dbt_expectations
│
├── models/
│   ├── sources.yml          # Bronze + Silver sources
│   │
│   ├── silver/
│   │   ├── silver_matches.yml        # Silver tests
│   │   ├── silver_teams.sql
│   │   ├── silver_players.sql
│   │   ├── silver_matches.sql        # Group + Knockout union
│   │   ├── silver_goal_events.sql    # Normalized goals
│   │   ├── silver_group_standings.sql
│   │   ├── silver_knockout_bracket.sql
│   │   ├── silver_stadiums.sql
│   │   ├── silver_player_stats_history.sql  # SCD Type 2
│   │   └── silver_group_standings_history.sql
│   │
│   └── gold/
│       ├── schema.yml                # Gold model docs
│       ├── gold_tournament_bracket.sql
│       ├── gold_player_leaderboard.sql
│       ├── gold_match_schedule.sql   # Req #3 & #4
│       ├── gold_points_table.sql
│       ├── gold_golden_boot_race.sql
│       ├── gold_team_summary.sql
│       ├── gold_team_goals.sql
│       └── gold_tournament_summary.sql
│
├── tests/
│   ├── pre_gold/
│   │   ├── assert_scorer_name_completeness.sql
│   │   ├── assert_all_matches_have_timezone_mapping.sql
│   │   ├── assert_top_scorers_have_complete_stats.sql
│   │   ├── assert_match_datetime_parseable.sql
│   │   ├── assert_all_players_have_valid_teams.sql
│   │   └── assert_no_orphaned_goal_events.sql
│   │
│   └── (generic silver tests in models/silver/silver_matches.yml)
│
└── macros/
    └── generate_schema_name.sql  # Custom schema naming
```

---

## 🔑 Key Design Decisions

### **1. SCD Type 2 for Player Stats**
Player statistics evolve match-by-match. `silver_player_stats_history` tracks every snapshot with `valid_from`/`valid_to` timestamps, enabling the Golden Boot Race timeline.

### **2. Match-Level Top Scorers (Not Tournament-Level)**
Requirement #3 needs "top scorer of each team IN THIS MATCH", not overall tournament top scorer. Uses `goal_events` grouped by `match_id + team_id`, not `player_stats`.

### **3. Unified Matches Table**
`silver_matches` unions group stage and knockout matches into one table. Single source of truth for all 104 matches.

### **4. Static ref_stadium_enriched**
Timezone mapping is manually created once via notebook. Not managed by dbt to avoid accidental overwrites. Referenced via `source('silver', 'ref_stadium_enriched')`.

### **5. DENSE_RANK for Ties**
Golden Boot Race handles ties naturally: if 2 players share rank 1, the next is rank 2 (not rank 3). Allows visualizing 1,1,2 or 1,2,3,3 scenarios.

### **6. scorer_name as TEXT (No Fuzzy Join)**
Goal events use `scorer_name` (TEXT) parsed from API strings. No player_id available. Acceptable for match-level attribution; use `player_stats` for accurate tournament leaderboards.

---

## ⚠️ Known Limitations

1. **scorer_name Inconsistency:** Goal events may have spelling variations ("Messi" vs "L. Messi"). Match-level display only; use `player_stats` for accurate totals.

2. **Manual ref_stadium_enriched:** Must be created once via notebook before running gold models.

3. **Live Match Status:** Assumes matches are "live" if started within last 3 hours and `is_finished = FALSE`. Actual live status depends on upstream API updates.

4. **Timezone Accuracy:** UTC conversion assumes ref_stadium_enriched is correct. Verify manually for DST edge cases.

---

## 📊 Data Refresh Schedule

**Recommended:**
- **Bronze ingestion:** Every 15 minutes during matches, hourly otherwise
- **Silver + Gold dbt:** Every 30 minutes during tournament, hourly otherwise
- **Dashboard refresh:** Real-time query against gold tables

---

## 🐛 Troubleshooting

### **Test Failure: assert_all_matches_have_timezone_mapping**
**Cause:** Missing stadiums in ref_stadium_enriched  
**Fix:** Run notebook to create/update ref_stadium_enriched with all 16 stadiums

### **Test Failure: assert_scorer_name_completeness**
**Cause:** Goal events have NULL scorer_name  
**Fix:** Check bronze.goal_events parsing logic; ensure home_scorers/away_scorers arrays are valid

### **Empty gold_golden_boot_race**
**Cause:** No SCD snapshots in silver_player_stats_history  
**Fix:** Ensure player stats are ingested multiple times with different valid_from timestamps

### **UTC Time Incorrect**
**Cause:** Wrong utc_offset_hours in ref_stadium_enriched  
**Fix:** Verify timezone offsets (e.g., EDT = -4, PDT = -7, CST = -6)

---

## 🎯 Success Criteria

✅ All 6 dashboard requirements supported  
✅ All dbt tests passing (generic + pre-gold)  
✅ Gold models refresh in < 5 minutes  
✅ Accurate UTC conversion for all matches  
✅ Golden Boot Race handles ties correctly  
✅ Match-level top scorers display correctly  

---

## 📚 Additional Resources

* **Bronze Ingestion Notebook:** `/Users/abhisheksinghal861@gmail.com/fifa 2026 Static Raw data fetch`
* **Architecture Notebook:** `/Users/abhisheksinghal861@gmail.com/FIFA 2026 Dashboard - Data Architecture`
* **Unity Catalog:** `singhal.fifa_worldcup_bronze`, `singhal.fifa_worldcup_silver`, `singhal.fifa_worldcup_gold`

---

## 👤 Contact

Maintainer: Abhishek Singhal  
Email: abhisheksinghal861@gmail.com  
Workspace: Databricks (AWS)

---

**Last Updated:** July 4, 2026  
**dbt Version:** 1.5+  
**Databricks Runtime:** 13.3 LTS or higher
