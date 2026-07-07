import type { VercelRequest, VercelResponse } from "@vercel/node";

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

  const result = await response.json();

  if (!response.ok) {
    console.error("Databricks Error:", result);
    throw new Error(JSON.stringify(result, null, 2));
  }

  return result;
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  try {
    // Test query first
    const result = await executeSQL(`
      SELECT 1 AS test
    `);

    res.setHeader(
      "Cache-Control",
      "s-maxage=900, stale-while-revalidate=300"
    );

    return res.status(200).json(result);
  } catch (error: any) {
    console.error(error);

    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}