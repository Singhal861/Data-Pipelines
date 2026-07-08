# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# DBTITLE 1,FIFA World Cup 2026 - Knockout Bracket Analysis
# MAGIC %md
# MAGIC ## 🏆 FIFA World Cup 2026 - Knockout Tournament Bracket
# MAGIC
# MAGIC This notebook creates and analyzes the **knockout stage bracket** structure for dashboard visualization.
# MAGIC
# MAGIC **Purpose:**
# MAGIC * Track tournament progression from Round of 16 → Final
# MAGIC * Show match relationships (which matches feed into which)
# MAGIC * Identify winners and track bracket paths
# MAGIC * Enable bracket visualization on dashboards
# MAGIC
# MAGIC **Knockout Structure:**
# MAGIC * **Round of 16 (R16):** 8 matches → 8 winners advance
# MAGIC * **Quarter-finals (QF):** 4 matches → 4 winners advance
# MAGIC * **Semi-finals (SF):** 2 matches → 2 winners to Final, 2 losers to 3rd place
# MAGIC * **Third Place:** 1 match
# MAGIC * **Final:** 1 match → Champion!
# MAGIC
# MAGIC **Source Data:** `singhal.fifa_worldcup_bronze.matches`
# MAGIC
# MAGIC **Output Table:** `singhal.fifa_worldcup_bronze.knockout_bracket`
# MAGIC
# MAGIC ---

# COMMAND ----------

# DBTITLE 1,⚙️ Imports and Configuration
from pyspark.sql import Row
from datetime import datetime, timezone

# Unity Catalog configuration
CATALOG = "singhal"
SCHEMA = "fifa_worldcup_bronze"

# Timestamp for ingestion
ingested_at = datetime.now(timezone.utc)

print(f"✅ Configuration loaded")
print(f"   Catalog: {CATALOG}")
print(f"   Schema: {SCHEMA}")
print(f"   Source: {CATALOG}.{SCHEMA}.matches")
print(f"   Target: {CATALOG}.{SCHEMA}.knockout_bracket")

# COMMAND ----------

# DBTITLE 1,1️⃣ Fetch Knockout Matches
# Fetch all knockout stage matches (R16, QF, SF, 3rd, Final)
print(f"\n🔍 Fetching knockout matches...")
print(f"="*80)

knockout_matches = spark.sql(f"""
    SELECT match_id, home_team_name, away_team_name, home_score, away_score,
           home_team_id, away_team_id, match_type, local_date, finished,
           stadium_id, home_scorers, away_scorers,
           home_penalty_score, away_penalty_score,
           home_penalty_scorers, away_penalty_scorers,
           home_penalty_misses, away_penalty_misses,
           home_team_label, away_team_label
    FROM {CATALOG}.{SCHEMA}.matches
    WHERE match_type IN ('r32', 'r16', 'qf', 'sf', 'third', 'final')
    ORDER BY 
        CASE match_type
            WHEN 'r16' THEN 1
            WHEN 'qf' THEN 2
            WHEN 'sf' THEN 3
            WHEN 'third' THEN 4
            WHEN 'final' THEN 5
        END,
        match_id
""").collect()

print(f"✅ Found {len(knockout_matches)} knockout matches")
print(f"\n📊 Breakdown by round:")
for match_type in ['r32', 'r16', 'qf', 'sf', 'third', 'final']:
    count = len([m for m in knockout_matches if m.match_type == match_type])
    type_label = {'r32': 'Round of 32','r16': 'Round of 16', 'qf': 'Quarter-finals', 'sf': 'Semi-finals', 'third': 'Third Place', 'final': 'Final'}[match_type]
    print(f"   {type_label}: {count} matches")

# COMMAND ----------

# DBTITLE 1,1.5️⃣ Map Stadium Timezones
# Map stadium locations to timezones
print(f"\n🌍 Mapping stadium timezones...")
print(f"="*80)

# Define stadium to timezone mapping (based on actual knockout match venues)
# Stadium IDs from the stadiums table
stadium_timezones = {
    # Mexico
    '1': 'America/Mexico_City',   # Mexico City Stadium (Mexico City)
    '2': 'America/Mexico_City',   # Estadio Guadalajara (Guadalajara)
    '3': 'America/Monterrey',     # Estadio Monterrey (Monterrey)
    
    # USA - Central Time (CST/CDT)
    '4': 'America/Chicago',       # Dallas Stadium (Dallas, Texas)
    '5': 'America/Chicago',       # Houston Stadium (Houston, Texas)
    '6': 'America/Chicago',       # Kansas City Stadium (Kansas City, Missouri)
    
    # USA - Eastern Time (EST/EDT)
    '7': 'America/New_York',      # Atlanta Stadium (Atlanta, Georgia)
    '8': 'America/New_York',      # Miami Stadium (Miami Gardens, Florida)
    '9': 'America/New_York',      # Boston Stadium (Foxborough, Massachusetts)
    '10': 'America/New_York',     # Philadelphia Stadium (Philadelphia, Pennsylvania)
    '11': 'America/New_York',     # New York/New Jersey Stadium (East Rutherford, NJ)
    
    # Canada - Eastern Time
    '12': 'America/Toronto',      # Toronto Stadium (Toronto)
    
    # Canada/USA - Pacific Time (PST/PDT)
    '13': 'America/Vancouver',    # BC Place Vancouver (Vancouver, BC)
    '14': 'America/Los_Angeles',  # Seattle Stadium (Seattle, Washington)
    '15': 'America/Los_Angeles',  # San Francisco Bay Area Stadium (Santa Clara, California)
    '16': 'America/Los_Angeles',  # Los Angeles Stadium (Inglewood, California)
}

# Timezone abbreviations for July 2026 (all in daylight saving time)
timezone_abbrev = {
    'America/New_York': 'EDT',
    'America/Chicago': 'CDT',
    'America/Los_Angeles': 'PDT',
    'America/Mexico_City': 'CDT',
    'America/Monterrey': 'CDT',
    'America/Toronto': 'EDT',
    'America/Vancouver': 'PDT',
}

print(f"✅ Mapped {len(stadium_timezones)} stadium timezones")
print(f"\n📊 Timezone distribution:")
print(f"   America/New_York (EDT): 5 stadiums")
print(f"   America/Chicago (CDT): 3 stadiums")
print(f"   America/Los_Angeles (PDT): 3 stadiums")
print(f"   America/Mexico_City (CDT): 2 stadiums")
print(f"   America/Toronto (EDT): 1 stadium")
print(f"   America/Vancouver (PDT): 1 stadium")

# COMMAND ----------

# DBTITLE 1,2️⃣ Build Knockout Bracket Structure
# Build knockout bracket structure with match progression tree
print(f"\n🏗️ Building bracket structure...")
print(f"="*80)

bracket_rows = []

# BUILD BRACKET STRUCTURE (OFFICIAL FIFA BRACKET)
# - R32 positions: Hardcoded official bracket order
# - R32 → R16: Hardcoded official bracket progression
# - R16 positions: Derived from API feeder labels (to handle actual match results)
# - QF → SF → Final: From API

# 🔧 STEP 1: HARDCODED R32→R16 OFFICIAL BRACKET PROGRESSION
print(f"\n📊 Building R32→R16 mapping (official bracket structure)...")

# Official bracket progression (based on FIFA tournament rules)
r32_feeds_into_override = {
    '73': 'R16-1',   # R32-1: South Africa vs Canada
    '75': 'R16-1',   # R32-2: Netherlands vs Morocco
    '74': 'R16-2',   # R32-3: Germany vs Paraguay
    '77': 'R16-2',   # R32-4: France vs Sweden
    '82': 'R16-3',   # R32-5: Belgium vs Senegal
    '81': 'R16-3',   # R32-6: USA vs Bosnia
    '84': 'R16-4',   # R32-7: Spain vs Austria
    '83': 'R16-4',   # R32-8: Portugal vs Croatia
    '76': 'R16-5',   # R32-9: Brazil vs Japan
    '78': 'R16-5',   # R32-10: Côte d'Ivoire vs Norway
    '79': 'R16-6',   # R32-11: Mexico vs Ecuador
    '80': 'R16-6',   # R32-12: England vs DR Congo
    '85': 'R16-7',   # R32-13: Switzerland vs Algeria
    '87': 'R16-7',   # R32-14: Colombia vs Ghana
    '88': 'R16-8',   # R32-15: Australia vs Egypt
    '86': 'R16-8',   # R32-16: Argentina vs Cabo Verde
}

print(f"✅ Official R32→R16 bracket progression:")
for r16_pos in ['R16-1', 'R16-2', 'R16-3', 'R16-4', 'R16-5', 'R16-6', 'R16-7', 'R16-8']:
    r32_list = [k for k, v in r32_feeds_into_override.items() if v == r16_pos]
    print(f"   {r16_pos}: R32 matches {sorted(r32_list)} feed into it")

# Build R16 match_id to position mapping (based on which R32 matches feed into them)
r16_matches = [m for m in knockout_matches if m.match_type == 'r16']
r16_match_to_position = {}  # Maps R16 match_id -> bracket position

for r16_match in r16_matches:
    # Extract which R32 matches feed into this R16 match from API labels
    home_label = getattr(r16_match, 'home_team_label', '')
    away_label = getattr(r16_match, 'away_team_label', '')
    
    feeder_ids = []
    if home_label and 'Winner Match' in home_label:
        feeder_ids.append(home_label.replace('Winner Match ', '').strip())
    if away_label and 'Winner Match' in away_label:
        feeder_ids.append(away_label.replace('Winner Match ', '').strip())
    
    # Find which R16 position these R32 feeders map to
    for r16_pos, r32_ids in [('R16-1', ['73', '75']), ('R16-2', ['74', '77']), 
                              ('R16-3', ['82', '81']), ('R16-4', ['84', '83']),
                              ('R16-5', ['76', '78']), ('R16-6', ['79', '80']),
                              ('R16-7', ['85', '87']), ('R16-8', ['88', '86'])]:
        if set(feeder_ids) == set(r32_ids):
            r16_match_to_position[r16_match.match_id] = r16_pos
            break

print(f"\n✅ R16 match_id to position mapping:")
for r16_id, r16_pos in sorted(r16_match_to_position.items(), key=lambda x: int(x[1].split('-')[1])):
    print(f"   Match {r16_id} → {r16_pos}")

# 🔧 STEP 2: HARDCODED R32 OFFICIAL BRACKET ORDER
# This is the official FIFA tournament bracket structure (not derived from API)
print(f"\n📊 Building R32 position mapping (official bracket order)...")

# Official R32 bracket order (match_id -> bracket_position)
r32_match_to_position = {
    '73': 'R32-1',   # South Africa vs Canada
    '75': 'R32-2',   # Netherlands vs Morocco
    '74': 'R32-3',   # Germany vs Paraguay
    '77': 'R32-4',   # France vs Sweden
    '82': 'R32-5',   # Belgium vs Senegal
    '81': 'R32-6',   # USA vs Bosnia
    '84': 'R32-7',   # Spain vs Austria
    '83': 'R32-8',   # Portugal vs Croatia
    '76': 'R32-9',   # Brazil vs Japan
    '78': 'R32-10',  # Côte d'Ivoire vs Norway
    '79': 'R32-11',  # Mexico vs Ecuador
    '80': 'R32-12',  # England vs DR Congo
    '85': 'R32-13',  # Switzerland vs Algeria
    '87': 'R32-14',  # Colombia vs Ghana
    '88': 'R32-15',  # Australia vs Egypt
    '86': 'R32-16',  # Argentina vs Cabo Verde
}

print(f"✅ Assigned R32 positions based on official bracket structure:")
for r32_id in ['73', '75', '74', '77', '82', '81', '84', '83', '76', '78', '79', '80', '85', '87', '88', '86']:
    print(f"   Match {r32_id} → {r32_match_to_position[r32_id]} (feeds into {r32_feeds_into_override.get(r32_id)})")

# Extract bracket progression from API labels (for R16 onwards)
knockout_structure = []
match_to_feeds_into = {}  # Maps match_id -> position it feeds into

# Round codes and position prefixes
round_info = {
    'r32': {'code': 'R32', 'bracket_side_threshold': 8},  # 1-8 Top, 9-16 Bottom
    'r16': {'code': 'R16', 'bracket_side_threshold': 4},  # 1-4 Top, 5-8 Bottom
    'qf': {'code': 'QF', 'bracket_side_threshold': 2},    # 1-2 Top, 3-4 Bottom
    'sf': {'code': 'SF', 'bracket_side_threshold': 1},    # 1 Top, 2 Bottom
    'third': {'code': '3rd', 'bracket_side_threshold': 0},
    'final': {'code': 'Final', 'bracket_side_threshold': 0},
}

# Parse each knockout match to understand bracket structure
for match in knockout_matches:
    match_id = match.match_id
    match_type = match.match_type
    
    if match_type not in round_info:
        continue
        
    round_code = round_info[match_type]['code']
    threshold = round_info[match_type]['bracket_side_threshold']
    
    # Determine position (e.g., R32-1, R16-3, QF-1)
    if match_type == 'r32':
        # 🔧 Use extracted R32 position from the mapping built above
        position = r32_match_to_position.get(match_id)
        if not position:
            # Fallback: if match not found in mapping, assign sequentially
            position_num = int(match_id) - 72
            position = f"{round_code}-{position_num}"
            print(f"   ⚠️ Warning: R32 match {match_id} not found in extracted mapping, using fallback {position}")
    elif match_type == 'r16':
        # 🔧 Use extracted R16 position from the mapping built above
        position = r16_match_to_position.get(match_id)
        if not position:
            # Fallback: if match not found in mapping, assign sequentially
            position_num = int(match_id) - 88
            position = f"{round_code}-{position_num}"
            print(f"   ⚠️ Warning: R16 match {match_id} not found in extracted mapping, using fallback {position}")
    elif match_type == 'qf':
        position_num = int(match_id) - 96  # Match 97 = QF-1
        position = f"{round_code}-{position_num}"
    elif match_type == 'sf':
        position_num = int(match_id) - 100  # Match 101 = SF-1
        position = f"{round_code}-{position_num}"
    elif match_type == 'third':
        position = '3rd-Place'
    else:  # final
        position = 'Final'
    
    # Determine bracket side
    if threshold == 0:  # Third place or Final
        bracket_side = 'Neutral'
    elif match_type in ['r32', 'r16', 'qf', 'sf']:
        position_num_val = int(position.split('-')[1]) if '-' in position else 1
        bracket_side = 'Top' if position_num_val <= threshold else 'Bottom'
    else:
        bracket_side = 'Neutral'
    
    # Extract feeds_into from API labels
    # Labels like "Winner Match 74" tell us this match feeds into the current match
    home_label = getattr(match, 'home_team_label', '')
    away_label = getattr(match, 'away_team_label', '')
    
    # Extract source match IDs from labels
    if home_label and 'Winner Match' in home_label:
        source_match_id = home_label.replace('Winner Match ', '').strip()
        if source_match_id not in match_to_feeds_into:
            match_to_feeds_into[source_match_id] = position
    
    if away_label and 'Winner Match' in away_label:
        source_match_id = away_label.replace('Winner Match ', '').strip()
        if source_match_id not in match_to_feeds_into:
            match_to_feeds_into[source_match_id] = position
    
    knockout_structure.append({
        'match_id': match_id,
        'round': round_code,
        'position': position,
        'feeds_into': None,  # Will be assigned in second pass
        'bracket_side': bracket_side,
    })

# Second pass: assign feeds_into values
# - For R32: use hardcoded override (API labels are wrong)
# - For R16+: use API-extracted mapping (correct)
for structure in knockout_structure:
    if structure['match_id'] in r32_feeds_into_override:
        # R32 matches: use hardcoded mapping
        structure['feeds_into'] = r32_feeds_into_override[structure['match_id']]
    else:
        # R16, QF, SF, Final: use API labels (correct)
        structure['feeds_into'] = match_to_feeds_into.get(structure['match_id'])

print(f"✅ Built bracket structure (hybrid approach)")
print(f"   R32 → R16: {len(r32_feeds_into_override)} hardcoded mappings (API labels incorrect)")
print(f"   R16+: {len(match_to_feeds_into)} mappings from API (correct)")
print(f"   Total: {len(knockout_structure)} bracket entries")

# OLD HARDCODED VERSION (removed):
#knockout_structure = [
    # {'match_id': '73', 'round': 'R32', 'position': 'R32-1', 'feeds_into': 'R16-1', 'bracket_side': 'Top'},


# Match the structure with actual match data and determine winners
for structure in knockout_structure:
    # Find matching actual match
    actual_match = None
    for match in knockout_matches:
        if match.match_id == structure['match_id']:
            actual_match = match
            break
    
    if actual_match:
        # Determine winner (if match is finished)
        winner_team = None
        winner_team_id = None
        loser_team = None
        loser_team_id = None
        match_status = 'Not Started'
        
        if actual_match.home_team_name and actual_match.away_team_name:
            if actual_match.finished == 'TRUE':
                match_status = 'Finished'
                # Check regular time winner first
                if actual_match.home_score > actual_match.away_score:
                    winner_team = actual_match.home_team_name
                    winner_team_id = actual_match.home_team_id
                    loser_team = actual_match.away_team_name
                    loser_team_id = actual_match.away_team_id
                elif actual_match.away_score > actual_match.home_score:
                    winner_team = actual_match.away_team_name
                    winner_team_id = actual_match.away_team_id
                    loser_team = actual_match.home_team_name
                    loser_team_id = actual_match.home_team_id
                else:
                    # Scores are tied - check penalty shootout
                    home_pen = getattr(actual_match, 'home_penalty_score', None)
                    away_pen = getattr(actual_match, 'away_penalty_score', None)
                    
                    if home_pen is not None and away_pen is not None:
                        # Penalty shootout occurred
                        if home_pen > away_pen:
                            winner_team = actual_match.home_team_name
                            winner_team_id = actual_match.home_team_id
                            loser_team = actual_match.away_team_name
                            loser_team_id = actual_match.away_team_id
                            match_status = 'Finished (Penalties)'
                        elif away_pen > home_pen:
                            winner_team = actual_match.away_team_name
                            winner_team_id = actual_match.away_team_id
                            loser_team = actual_match.home_team_name
                            loser_team_id = actual_match.home_team_id
                            match_status = 'Finished (Penalties)'
                        else:
                            match_status = 'Draw (Tied Penalties)'
                    else:
                        match_status = 'Draw (Pending Penalties)'
            else:
                match_status = 'Scheduled'
        
        # Get timezone for this stadium
        stadium_tz = stadium_timezones.get(actual_match.stadium_id, 'America/New_York')  # Default to ET
        tz_abbrev = timezone_abbrev.get(stadium_tz, 'EDT')
        
        # Add timezone abbreviation to match date
        match_date_with_tz = f"{actual_match.local_date} {tz_abbrev}"
        
        bracket_rows.append(Row(
            match_id=actual_match.match_id,
            round=structure['round'],
            bracket_position=structure['position'],
            feeds_into_position=structure['feeds_into'],
            bracket_side=structure['bracket_side'],
            home_team=actual_match.home_team_name,
            away_team=actual_match.away_team_name,
            home_team_id=actual_match.home_team_id,
            away_team_id=actual_match.away_team_id,
            home_score=actual_match.home_score,
            away_score=actual_match.away_score,
            home_scorers=actual_match.home_scorers,
            away_scorers=actual_match.away_scorers,
            home_penalty_score=actual_match.home_penalty_score if hasattr(actual_match, 'home_penalty_score') else None,
            away_penalty_score=actual_match.away_penalty_score if hasattr(actual_match, 'away_penalty_score') else None,
            home_penalty_scorers=actual_match.home_penalty_scorers if hasattr(actual_match, 'home_penalty_scorers') else None,
            away_penalty_scorers=actual_match.away_penalty_scorers if hasattr(actual_match, 'away_penalty_scorers') else None,
            home_penalty_misses=actual_match.home_penalty_misses if hasattr(actual_match, 'home_penalty_misses') else None,
            away_penalty_misses=actual_match.away_penalty_misses if hasattr(actual_match, 'away_penalty_misses') else None,
            winner_team=winner_team,
            winner_team_id=winner_team_id,
            loser_team=loser_team,
            loser_team_id=loser_team_id,
            match_status=match_status,
            match_date_local=match_date_with_tz,
            timezone=stadium_tz,
            stadium_id=actual_match.stadium_id,
            is_finished=actual_match.finished == 'TRUE',
            ingested_at=ingested_at,
        ))

print(f"✅ Built bracket structure with {len(bracket_rows)} matches")
print(f"\n📊 Bracket Tree:")
print(f"   R16 (8) → QF (4) → SF (2) → Final (1)")
print(f"                          └→ 3rd Place (1)")

# COMMAND ----------

# DBTITLE 1,3️⃣ Save Knockout Bracket Table
# Save the knockout bracket table to Unity Catalog
print(f"\n💾 Saving knockout bracket table...")
print(f"="*80)

# 🛡️ SAFETY CHECK: Validate data quality before overwriting
MIN_KNOCKOUT_MATCHES = 25  # Expect at least 25 knockout matches (32 total: 16 R32 + 8 R16 + 4 QF + 2 SF + 1 Third + 1 Final)

if len(bracket_rows) < MIN_KNOCKOUT_MATCHES:
    print(f"\n🚨 DATA QUALITY CHECK FAILED!")
    print(f"="*80)
    print(f"   ⚠️ Knockout matches: {len(bracket_rows)} < {MIN_KNOCKOUT_MATCHES} minimum")
    print(f"\n❌ SKIPPING TABLE SAVE to prevent data loss!")
    print(f"   Existing knockout_bracket table preserved.")
    print(f"   Check that bronze.matches has complete knockout stage data.")
    print(f"="*80)
    raise Exception("Data quality check failed - insufficient knockout matches")

print(f"✅ Data quality check passed: {len(bracket_rows)} matches (min: {MIN_KNOCKOUT_MATCHES})")
print(f"\n💾 Proceeding with table save...\n")

if bracket_rows:
    # Define explicit schema to handle None values
    from pyspark.sql.types import StructType, StructField, StringType, IntegerType, BooleanType, TimestampType
    
    schema = StructType([
        StructField("match_id", StringType(), True),
        StructField("round", StringType(), True),
        StructField("bracket_position", StringType(), True),
        StructField("feeds_into_position", StringType(), True),
        StructField("bracket_side", StringType(), True),
        StructField("home_team", StringType(), True),
        StructField("away_team", StringType(), True),
        StructField("home_team_id", StringType(), True),
        StructField("away_team_id", StringType(), True),
        StructField("home_score", IntegerType(), True),
        StructField("away_score", IntegerType(), True),
        StructField("home_scorers", StringType(), True),
        StructField("away_scorers", StringType(), True),
        StructField("home_penalty_score", IntegerType(), True),
        StructField("away_penalty_score", IntegerType(), True),
        StructField("home_penalty_scorers", StringType(), True),
        StructField("away_penalty_scorers", StringType(), True),
        StructField("home_penalty_misses", StringType(), True),
        StructField("away_penalty_misses", StringType(), True),
        StructField("winner_team", StringType(), True),
        StructField("winner_team_id", StringType(), True),
        StructField("loser_team", StringType(), True),
        StructField("loser_team_id", StringType(), True),
        StructField("match_status", StringType(), True),
        StructField("match_date_local", StringType(), True),
        StructField("timezone", StringType(), True),
        StructField("stadium_id", StringType(), True),
        StructField("is_finished", BooleanType(), True),
        StructField("ingested_at", TimestampType(), True),
    ])
    
    spark.createDataFrame(bracket_rows, schema=schema).write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(f"{CATALOG}.{SCHEMA}.knockout_bracket")
    print(f"✅ Saved {len(bracket_rows)} matches to {CATALOG}.{SCHEMA}.knockout_bracket")
    
    # Count matches by status
    finished_count = len([r for r in bracket_rows if r.is_finished])
    scheduled_count = len([r for r in bracket_rows if not r.is_finished])
    
    print(f"\n📈 Match Status:")
    print(f"   ✅ Finished: {finished_count}")
    print(f"   📅 Scheduled/Not Started: {scheduled_count}")
    
    # Show winners by round (if any matches finished)
    if finished_count > 0:
        print(f"\n🏆 Winners by Round:")
        for round_name in ['R16', 'QF', 'SF', '3rd', 'Final']:
            round_winners = [r for r in bracket_rows if r.round == round_name and r.winner_team]
            if round_winners:
                print(f"   {round_name}: {len(round_winners)} winners")
                for winner_row in round_winners[:3]:  # Show first 3
                    print(f"      → {winner_row.winner_team}")
else:
    print(f"⚠️  No knockout matches to save")

print(f"\n{'='*80}")
print(f"✅ Knockout bracket table ready for dashboard visualization!")

# COMMAND ----------

# DBTITLE 1,🛡️ Data Safety Guardrails
# MAGIC %md
# MAGIC ## 🛡️ Data Safety Guardrails
# MAGIC
# MAGIC ### ⚠️ **Problem This Solves**
# MAGIC This notebook builds the knockout bracket from `bronze.matches`. If the matches table is incomplete or empty (e.g., after an API failure), this notebook would **overwrite the existing bracket with incomplete data** — breaking dashboard visualizations!
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### ✅ **Safety Check Implemented**
# MAGIC
# MAGIC ```python
# MAGIC MIN_KNOCKOUT_MATCHES = 25  # Expect at least 25 matches
# MAGIC ```
# MAGIC
# MAGIC **Expected Knockout Structure:**
# MAGIC * **Round of 32 (R32):** 16 matches
# MAGIC * **Round of 16 (R16):** 8 matches
# MAGIC * **Quarter-finals (QF):** 4 matches
# MAGIC * **Semi-finals (SF):** 2 matches
# MAGIC * **Third Place:** 1 match
# MAGIC * **Final:** 1 match
# MAGIC * **Total:** 32 matches
# MAGIC
# MAGIC **Behavior:**
# MAGIC * ✅ If bracket has 25+ matches → Proceed with overwrite
# MAGIC * ❌ If bracket has < 25 matches → **ABORT** and preserve existing table
# MAGIC * 🛡️ Prevents incomplete knockout data from breaking dashboards
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### 📋 **What Happens When Source Data is Bad?**
# MAGIC
# MAGIC **Before (Dangerous):**
# MAGIC ```
# MAGIC bronze.matches incomplete → Only 10 knockout matches found → Overwrites table → 💥 Dashboard breaks!
# MAGIC ```
# MAGIC
# MAGIC **After (Safe):**
# MAGIC ```
# MAGIC bronze.matches incomplete → Only 10 knockout matches found → Quality check fails → ❌ Aborts
# MAGIC                             ↓
# MAGIC                     Existing bracket preserved ✅
# MAGIC ```
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### 🔄 **Recovery Steps If Notebook Aborts**
# MAGIC
# MAGIC 1. **Check Source Table**
# MAGIC    ```sql
# MAGIC    SELECT COUNT(*), match_type
# MAGIC    FROM singhal.fifa_worldcup_bronze.matches
# MAGIC    WHERE match_type IN ('r32', 'r16', 'qf', 'sf', 'third', 'final')
# MAGIC    GROUP BY match_type;
# MAGIC    ```
# MAGIC    Should show:
# MAGIC    - r32: 16 matches
# MAGIC    - r16: 8 matches
# MAGIC    - qf: 4 matches
# MAGIC    - sf: 2 matches
# MAGIC    - third: 1 match
# MAGIC    - final: 1 match
# MAGIC
# MAGIC 2. **Fix Upstream Issues**
# MAGIC    - Re-run the main bronze layer notebook: [fifa 2026 Static Raw data fetch](#notebook-3791554669137702)
# MAGIC    - Ensure worldcup26.ir API is accessible
# MAGIC    - Verify matches table has complete knockout stage data
# MAGIC
# MAGIC 3. **Re-run After Fix**
# MAGIC    - Fix source data
# MAGIC    - Re-run this notebook
# MAGIC    - Bracket only overwrites if quality checks pass
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### 🔗 **Dependency Chain**
# MAGIC
# MAGIC ```
# MAGIC worldcup26.ir API
# MAGIC     ↓
# MAGIC bronze.matches (main bronze notebook)
# MAGIC     ↓
# MAGIC bronze.knockout_bracket (THIS notebook) 🛡️ Safety check here
# MAGIC     ↓
# MAGIC Dashboards & Visualizations
# MAGIC ```
# MAGIC
# MAGIC Both the source (bronze.matches) and this derived table (knockout_bracket) are now protected!

# COMMAND ----------

# DBTITLE 1,📊 Verify Bracket Table
# Query and display the knockout bracket table
print(f"\n📊 KNOCKOUT BRACKET TABLE VERIFICATION")
print(f"="*80)

# Show bracket structure with venue information
bracket_df = spark.sql(f"""
    SELECT kb.round, kb.bracket_position, kb.home_team, kb.away_team, 
           kb.home_score, kb.away_score, kb.match_date_local, kb.timezone,
           s.fifa_name as venue, s.city_en as city,
           kb.winner_team, kb.match_status, kb.feeds_into_position
    FROM {CATALOG}.{SCHEMA}.knockout_bracket kb
    LEFT JOIN {CATALOG}.{SCHEMA}.stadiums s ON kb.stadium_id = s.stadium_id
    ORDER BY 
        CASE round
            WHEN 'R16' THEN 1
            WHEN 'QF' THEN 2
            WHEN 'SF' THEN 3
            WHEN '3rd' THEN 4
            WHEN 'Final' THEN 5
        END,
        bracket_position
""")

print(f"\n🏆 Complete Knockout Bracket:")
bracket_df.show(100, truncate=False)

# Show progression tree
print(f"\n🌳 Tournament Progression Tree:")
print(f"-"*80)

progression_df = spark.sql(f"""
    SELECT round, bracket_position, winner_team, feeds_into_position
    FROM {CATALOG}.{SCHEMA}.knockout_bracket
    WHERE winner_team IS NOT NULL
    ORDER BY 
        CASE round
            WHEN 'R16' THEN 1
            WHEN 'QF' THEN 2
            WHEN 'SF' THEN 3
            WHEN '3rd' THEN 4
            WHEN 'Final' THEN 5
        END
""")

if progression_df.count() > 0:
    progression_df.show(100, truncate=False)
else:
    print("   No matches finished yet - tournament hasn't started!")

print(f"\n{'='*80}")
print(f"✅ Bracket table is ready for dashboard visualization!")
print(f"\n💡 Use this table to:")
print(f"   • Visualize tournament bracket on dashboards")
print(f"   • Track match progression (feeds_into_position)")
print(f"   • Show live winners as matches complete")
print(f"   • Build interactive bracket widgets")
