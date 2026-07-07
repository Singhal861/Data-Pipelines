import type { VercelRequest, VercelResponse } from "@vercel/node";
import { executeSQL } from "./lib/databricks";

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  try {
    const summary = await executeSQL(`
      SELECT *
      FROM singhal.fifa_worldcup_gold.gold_tournament_summary
    `);

    res.setHeader(
      "Cache-Control",
      "s-maxage=900, stale-while-revalidate=300"
    );

    res.status(200).json(summary);
  } catch (err: any) {
    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
}