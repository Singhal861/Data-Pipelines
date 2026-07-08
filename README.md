## ![](path)# FIFA World Cup 2026 Dashboard - Data Pipeline

## 📊 Project Overview

Complete data pipeline for FIFA World Cup 2026 dashboard implementing Bronze → Silver → Gold medallion architecture with dbt transformations. Supports **7 core dashboard representations** with live match tracking, player statistics, knockout brackets, and tournament visualization.

**Scheduled Job:** `fifa_WorldCup_2026`  
**Schedule:** Twice daily (due to Databricks free edition limitations)  
**Catalog:** `singhal` (Unity Catalog)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BRONZE LAYER                              │
│         (Raw Data from Dual API Sources)                     │
├─────────────────────────────────────────────────────────────┤
│  🔹 Notebook 1: fifa 2026 Static Raw data fetch             │
│     • Data Sources:                                          │
│       - SportScore API: players, teams, group_standings      │
│       - worldcup26.ir API: matches (104), stadiums (16)      │
│     • Quality checks: min thresholds before overwrites       │
│                                                               │
│  📋 Tables Created:                                          │
│     players              (78 from SportScore)               │
│     teams                (48 teams from SportScore)          │
│     matches              (104 from worldcup26.ir)            │
│     group_standings      (60 entries from SportScore)        │
│     stadiums             (16 venues from worldcup26.ir)      │
│                                                               │
│  🔹 Notebook 2: Knockout Bracket RAW Analysis                │
│     • Reads bronze.matches                                   │
│     • Builds tournament tree (R32→R16→QF→SF→Final)           │
│     • Maps stadium timezones                                 │
│     • Quality check: min 25 knockout matches                 │
│                                                               │
│  📋 Table Created:                                           │
│     knockout_bracket     (32 knockout matches)               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    SILVER LAYER (dbt)                        │
│            (Cleaned, Joined, Type-2 SCD)                     │
├─────────────────────────────────────────────────────────────┤
│  🥈 silver_teams          (from bronze.teams)                │
│  🥈 silver_players        (from bronze.players)              │
│  🥈 silver_matches        (Group + Knockout unified)         │
│     ⭐ Team name normalization logic lives here              │
│  🥈 silver_goal_events    (derived from matches.home_scorers │
│                            /away_scorers, NOT from bronze)   │
│  🥈 silver_group_standings                                   │
│  🥈 silver_knockout_bracket                                  │
│  🥈 silver_stadiums                                          │
│  🥈 silver_player_stats_history (SCD Type 2)                 │
│  🥈 silver_group_standings_history (SCD Type 2)              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                     GOLD LAYER (dbt)                         │
│               (Dashboard-Ready Models)                       │
├─────────────────────────────────────────────────────────────┤
│  🏆 gold_fact_match_schedule     (DR #1,#3,#4: All matches) │
│  🏆 gold_team_goals              (DR #1: Goal details)       │
│  🏆 gold_player_leaderboard      (DR #2: Top 10 scorers)    │
│  🏆 gold_fact_team_performance   (DR #5: Points table)      │
│  🏆 gold_golden_boot_race        (DR #6: Top 3 timeline)    │
│  🏆 gold_tournament_summary      (DR #7: Tournament KPIs)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Live Dashboard

View the interactive FIFA World Cup 2026 dashboard with all 7 visualizations:

**🔗 [FIFA 2026 Dashboard - Click Here](https://singhal-fifa-2026-dashboard.vercel.app/)**

**Dashboard Features:**
1. **Tournament Bracket** - Interactive knockout bracket with TBD logic and goal details (click on fixture block to respective match to see details)
2. **Top 10 Scorers** - Leaderboard with spider chart (click on player image)
3. **Live & Upcoming Matches** - Real-time match tracking with countdown timers
4. **Match History** - Complete record of all finished matches
5. **Points Table** - Tournament standings & match-by-match details(click on team name / logo)
6. **Golden Boot Race** - Goal progression timeline for top 3 scorers
7. **Tournament Summary** - High-level KPIs and statistics

---

## 🗂️ Key Data Models

### **Bronze Layer** (Notebooks)

#### **fifa 2026 Static Raw data fetch**
Fetches from dual API sources with quality checks.
```python
# SportScore API:
- players (top 50 scorers + assisters)
- teams (48 teams with logos)
- group_standings (60 entries)

# worldcup26.ir API:
- matches (104 matches with scores)
- stadiums (16 venues)

# Quality Checks:
MIN_PLAYERS = 50
MIN_TEAMS = 40
MIN_MATCHES = 90
MIN_STANDINGS = 50
```

#### **Knockout Bracket RAW Analysis**
Builds tournament tree structure.
```python
# Input: bronze.matches (knockout only)
# Output: bronze.knockout_bracket

# Features:
- Match progression tree (which matches feed into which)
- Stadium timezone mapping (16 venues across USA/Canada/Mexico)
- Winner tracking for bracket visualization

# Quality Check:
MIN_KNOCKOUT_MATCHES = 25  # Prevents incomplete data overwrites
```

---

### **Silver Layer** (dbt)

#### **silver_matches**
Unified match table (group + knockout) with team name normalization.
```sql
-- ALL team name normalization logic resides here
-- Consumed by all gold models
-- Columns:
match_id, stage, home_team_name, away_team_name,
home_score, away_score, winner_team_id,
match_date_local, stadium_id, is_finished
```

#### **silver_goal_events**
Derived from `bronze.matches` (home_scorers/away_scorers), NOT a bronze table.
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

**Critical for:** Golden Boot Race timeline (Dashboard #6), tracking goal progression

---

### **Gold Layer** (dbt)

#### **gold_fact_match_schedule**
Serves MULTIPLE dashboard representations:
- Dashboard #1: Tournament bracket (filter: `is_knockout = TRUE`)
- Dashboard #3: Live/upcoming matches (filter: `match_status IN ('Live', 'Upcoming')`)
- Dashboard #4: Finished matches (filter: `is_finished = TRUE`)
- Dashboard #5: Match history on click (filter by team)

**Key Features:**
- Unified fact table for all match data
- TBD opponent logic (`home_display_name`, `away_display_name`)
- Bracket structure (`bracket_position`, `feeds_into_position`)
- Match status tracking
- Top scorers per team

#### **gold_team_goals**
Goal-by-goal details for Dashboard #1 click interaction.
```sql
-- Columns:
match_id, team_name, scorer_name, minute,
is_penalty, goal_number_in_match

-- Used for showing goal timing: "Messi (23')", "Di Maria (67') (PEN)"
```

#### **gold_player_leaderboard**
Top 10 scorers for Dashboard #2.
```sql
-- Tiebreaker:
ORDER BY 
    goals_scored DESC,
    assists DESC,
    minutes_played ASC
LIMIT 10

-- Includes percentiles for spider chart
```

#### **gold_fact_team_performance**
Tournament points table for Dashboard #5.
```sql
-- Aggregate team statistics
-- Validation:
total_points = (total_wins × 3) + total_draws
goal_difference = goals_for - goals_against
```

#### **gold_golden_boot_race**
Match-by-match timeline for Dashboard #6.
```sql
-- Key Logic:
1. Identify current top 3 from latest player snapshot (valid_to IS NULL)
2. Filter matches: WHERE is_finished = TRUE (no future matches)
3. Use 24-hour buffer for stat updates after match finish
4. Flag latest records: is_current_top_3 = TRUE for current top 3

-- Key Features:
- 6-hour buffer for post-match stat updates
- Filters to exclude future matches (only finished matches shown)
- Current top 3 based on most recent player stats, not match datetime
```

#### **gold_tournament_summary**
Tournament-wide KPIs for Dashboard #7.
```sql
-- Top Scorer Selection:
ROW_NUMBER() OVER (
    ORDER BY 
        goals_scored DESC,
        assists DESC,           -- ✅ Tiebreaker
        minutes_played ASC
)

-- Key Features:
- FIFA tiebreaker logic (goals → assists → minutes)
- Correctly identifies top scorer with multi-criteria ranking
```

---

## 🧪 Data Quality Tests

### **Silver Layer Tests**

**silver_matches:**
- `match_id`: unique, not_null
- `stage`: accepted_values (Group Stage, R32, R16, QF, SF, Final, 3rd)
- `is_finished`: not_null

**silver_goal_events:**
- `goal_event_id`: unique, not_null
- `match_id`: relationships to silver_matches
- `team_id`, `scorer_name`, `minute`: not_null

---

### **Pre-Gold Tests** (tests/pre_gold/)

1. **assert_scorer_name_completeness.sql**
   - Fails if finished matches have NULL scorer_name

2. **assert_all_matches_have_timezone_mapping.sql**
   - Fails if stadiums missing timezone mappings

3. **assert_top_scorers_have_complete_stats.sql**
   - Fails if top scorers have NULL assists/minutes

4. **assert_match_datetime_parseable.sql**
   - Validates match_date_local format

5. **assert_all_players_have_valid_teams.sql**
   - Validates goal events reference existing teams

6. **assert_no_orphaned_goal_events.sql**
   - Validates goal events reference existing matches

---

### **Gold Layer Tests** (tests/gold/)

**Dashboard-aligned test files:**
1. `test_req1_tournament_bracket_completeness.sql` (Dashboard #1)
2. `test_req2_player_leaderboard_completeness.sql` (Dashboard #2)
3. `test_req3_match_schedule_completeness.sql` (Dashboard #3)
4. `test_req4_team_performance_completeness.sql` (Dashboard #5)
5. `test_req5_points_table_completeness.sql` (Dashboard #5)
6. `test_req6_golden_boot_race_completeness.sql` (Dashboard #6)

**Key Features:**
- Tests 1 & 3: Check both `home_team_name IS NOT NULL AND away_team_name IS NOT NULL` to skip partially-assigned future knockout matches

---

## 🚀 Pipeline Execution

### **Databricks Job: fifa_WorldCup_2026**

**Schedule:** Twice daily (due to Databricks free edition limitations)  
**Status:** Active

**Task Flow:**
```
1. refresh_bronze_layer_data (Notebook)
   ↓
2. knockout_calculation (Notebook)
   ↓
3. silver_layer_dbt_tranformation (dbt)
   • dbt clean
   • dbt deps
   • dbt run --select tag:silver
   • dbt test --select tag:silver
   • dbt test --select path:tests/pre_gold
   ↓
4. gold_layer_dbt_transformation (dbt)
   • dbt deps
   • dbt run --select tag:gold
   • dbt test --select tag:gold
```

---

## 📁 Project Structure

### **FIFA_WC_26/** (dbt Project)

```
FIFA_WC_26/
├── README.md
│
├── dbt_project.yml          # dbt config
├── profiles.yml             # Databricks connection
├── packages.yml             # dbt_utils, dbt_expectations
├── package-lock.yml
│
├── models/
│   ├── sources.yml          # Bronze + Silver sources
│   │
│   ├── silver/
│   │   ├── sources.yml               # Silver layer sources
│   │   ├── silver_matches.yml        # Silver tests
│   │   ├── silver_teams.sql
│   │   ├── silver_players.sql
│   │   ├── silver_matches.sql        # ⭐ Team normalization
│   │   ├── silver_goal_events.sql    # Derived from matches
│   │   ├── silver_group_standings.sql
│   │   ├── silver_knockout_bracket.sql
│   │   ├── silver_stadiums.sql
│   │   ├── silver_player_stats_history.sql  # SCD Type 2
│   │   └── silver_group_standings_history.sql
│   │
│   └── gold/
│       ├── schema.yml
│       ├── gold_fact_match_schedule.sql     # DR #1,#3,#4,#5
│       ├── gold_team_goals.sql              # DR #1 (click)
│       ├── gold_player_leaderboard.sql      # DR #2
│       ├── gold_fact_team_performance.sql   # DR #5
│       ├── gold_golden_boot_race.sql        # DR #6
│       └── gold_tournament_summary.sql      # DR #7
│
├── tests/
│   ├── assert_player_stats_*.sql       # 7 player stats tests
│   │
│   ├── pre_gold/                       # 6 pre-gold assertions
│   │   ├── assert_scorer_name_completeness.sql
│   │   ├── assert_all_matches_have_timezone_mapping.sql
│   │   ├── assert_top_scorers_have_complete_stats.sql
│   │   ├── assert_match_datetime_parseable.sql
│   │   ├── assert_all_players_have_valid_teams.sql
│   │   └── assert_no_orphaned_goal_events.sql
│   │
│   ├── gold/                           # 6 dashboard-aligned tests
│   │   ├── schema.yml
│   │   ├── README.md
│   │   ├── test_req1_tournament_bracket_completeness.sql
│   │   ├── test_req2_player_leaderboard_completeness.sql
│   │   ├── test_req3_match_schedule_completeness.sql
│   │   ├── test_req4_team_performance_completeness.sql
│   │   ├── test_req5_points_table_completeness.sql
│   │   └── test_req6_golden_boot_race_completeness.sql
│   │
│   └── silver/                         # Custom silver tests
│       └── test_team_logo_join.sql
│
├── macros/
│   └── generate_schema_name.sql
│
└── dashboard/                          # React + TypeScript (separate deployment)
```

---

### **Bronze Layer Notebooks** (Databricks Workspace)

Located in: `/Workspace/Users/abhisheksinghal861@gmail.com/Databricks_core_notebooks/Bronze_layer_data_fetch/`

* **fifa 2026 Static Raw data fetch** - Fetches players, teams, matches, stadiums, group standings from dual APIs
* **Knockout Bracket RAW Analysis** - Builds tournament tree structure with timezone mappings

---

### **Optimization Layer Notebook** (Databricks Workspace)

Located in: `/Workspace/Users/abhisheksinghal861@gmail.com/Databricks_core_notebooks/`

* **Performance Optimization** - Runs OPTIMIZE, Z-ORDER, and VACUUM commands on high-traffic gold tables

---

## 🔑 Key Design Decisions

### **1. Dual API Architecture**
- **SportScore API:** Player stats (avoids double-counting)
- **worldcup26.ir API:** Matches and stadiums (complete 104-match dataset)
- Prevents conflicting data sources

### **2. Quality Checks Before Overwrites**
Both notebooks validate data quality:
- Bronze notebook: min 50 players, 40 teams, 90 matches
- Knockout notebook: min 25 knockout matches
- **Prevents empty API responses from wiping good data**

### **3. goal_events in Silver, NOT Bronze**
Derived from `bronze.matches` (home_scorers/away_scorers) in silver layer, avoiding raw API parsing issues.

### **4. SCD Type 2 for Player Stats**
`silver_player_stats_history` tracks snapshots with `valid_from`/`valid_to`, enabling timeline analysis for Golden Boot Race.

### **5. Unified Match Table**
`silver_matches` unions group + knockout into single source of truth. **All team name normalization logic lives here.**

### **6. Smart Boundary Logic (Prevents Back-to-Back Overlap)**
Golden Boot Race uses **next-match-aware boundaries** instead of fixed time windows:
```sql
ps.valid_from <= COALESCE(
    next_match_datetime_utc,  -- Use next match if exists
    match_datetime_utc + INTERVAL 24 HOURS  -- Else 24h for last match
)
```

**Why this matters:**
* **Problem:** Fixed 24h windows overlap when matches are <24h apart (France: 6h, Norway: 3h gaps found)
* **Impact:** Same snapshot appears in multiple matches → duplicate goal counts
* **Solution:** Use next match start as boundary → each snapshot attributed to exactly one match
* **Fallback:** For the last match (no next match), use 24h buffer to catch delayed API updates

**Evolution:**
1. Originally 6 hours (insufficient for API delays)
2. Increased to 24 hours (fixed Match 95: 11.87h delay)
3. Smart boundary (prevents back-to-back overlap while keeping 24h safety net)

### **7. TBD Opponent Logic**
Dashboard #1 (Tournament Bracket) handles future knockout matches:
- `home_display_name`: Shows "Winner of QF1" or "TBD"
- `away_display_name`: Shows "Winner of QF3" or "TBD"
- Goals show "NA" for unfinished matches

### **8. Performance Optimization Pipeline**
Separate optimization pipeline implements Databricks best practices:
- **Z-Ordering:** Multi-dimensional clustering on frequently filtered columns (match_id, team_id, player_id)
- **OPTIMIZE Command:** Compacts small files into larger ones for improved scan efficiency
- **VACUUM Command:** Removes old data files no longer referenced by Delta tables, reclaiming storage space
- **Table Maintenance:** Runs post-gold layer to reduce query latency
- **Delta Lake Features:** Leverages Delta table optimization for faster dashboard queries

**Implementation:**
- Runs after gold layer transformations complete
- Targets high-traffic tables: `gold_fact_match_schedule`, `gold_player_leaderboard`, `gold_fact_team_performance`
- Z-Order columns aligned with dashboard filter patterns
- VACUUM retains 7-day retention period for time travel capabilities
- Scheduled independently to minimize impact on main pipeline runtime

---

## 🎯 Success Criteria

✅ All 7 dashboard representations supported  
✅ All dbt tests passing (silver + pre-gold + gold)  
✅ Quality checks prevent data loss  
✅ Golden Boot Race shows current top 3 with correct goal counts  
✅ Tournament summary uses FIFA tiebreaker (goals → assists → minutes)  
✅ TBD opponent logic working for future knockout matches  
✅ Pipeline runs twice daily on schedule without failures  

---

## 👤 Contact

Maintainer: Abhishek Singhal  
Email: abhisheksinghal861@gmail.com  
Workspace: Databricks (AWS)

---

## 📄 License & Copyright

**Copyright © 2026 Abhishek Singhal. All Rights Reserved.**

This project and its associated documentation, source code, data models, and dashboard implementations are the intellectual property of Abhishek Singhal.

### Terms of Use

* **No Reproduction:** No part of this project may be reproduced, distributed, or transmitted in any form or by any means without prior written permission from the copyright holder.
* **No Commercial Use:** This project is intended for educational and portfolio demonstration purposes only. Commercial use, redistribution, or derivative works are strictly prohibited without explicit authorization.
* **Attribution Required:** Any reference to this work must include proper attribution to the author.

For permissions, licensing inquiries, or collaboration opportunities, please contact: abhisheksinghal861@gmail.com

---

**Last Updated:** July 8, 2026  
**dbt Version:** 1.11+  
**Databricks Runtime:** Serverless (AWS)  
**Dashboard Representations:** 7 (Tournament Bracket, Top Scorers, Live Matches, Match History, Points Table, Golden Boot Race, Tournament Summary)
