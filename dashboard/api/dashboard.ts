import type { VercelRequest, VercelResponse } from "@vercel/node";
import { queries } from "./queries";

const HOST = process.env.DATABRICKS_HOST!;
const TOKEN = process.env.DATABRICKS_TOKEN!;
const WAREHOUSE_ID = process.env.DATABRICKS_WAREHOUSE_ID!;

async function executeSQL(statement: string) {
  const response = await fetch(
    `https://${HOST}/api/2.0/sql/statements`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        warehouse_id: WAREHOUSE_ID,
        statement,
        wait_timeout: "30s",
      }),
    }
  );

  const json = await response.json();

  if (!response.ok) {
    console.error("Databricks Error:", json);
    throw new Error(JSON.stringify(json, null, 2));
  }

  const columns = json.manifest.schema.columns.map((c: any) => c.name);

  return json.result.data_array.map((row: any[]) => {
    const obj: Record<string, any> = {};

    columns.forEach((col: string, index: number) => {
      obj[col] = row[index];
    });

    return obj;
  });
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  try {
    const [
      tournamentSummary,
      fixture,
      topScorers,
      upcomingMatches,
      finishedMatches,
      teamPerformance,
      teamMatchesHistory,
      goldenBootRace,
    ] = await Promise.all([
      executeSQL(queries.tournament_summary),
      executeSQL(queries.fixture),
      executeSQL(queries.top_scorers),
      executeSQL(queries.upcoming_matches),
      executeSQL(queries.finished_matches),
      executeSQL(queries.team_performance),
      executeSQL(queries.team_matches_history),
      executeSQL(queries.golden_boot_race),
    ]);

    res.setHeader(
      "Cache-Control",
      "s-maxage=900, stale-while-revalidate=300"
    );

    return res.status(200).json({
      success: true,

      tournament_summary: tournamentSummary,
      fixture: fixture,
      top_scorers: topScorers,
      upcoming_matches: upcomingMatches,
      finished_matches: finishedMatches,
      team_performance: teamPerformance,
      team_matches_history: teamMatchesHistory,
      golden_boot_race: goldenBootRace,
    });
  } catch (error: any) {
    console.error(error);

    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}