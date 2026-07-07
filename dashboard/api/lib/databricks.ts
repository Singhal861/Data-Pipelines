const HOST = process.env.DATABRICKS_HOST!;
const TOKEN = process.env.DATABRICKS_TOKEN!;
const WAREHOUSE_ID = process.env.DATABRICKS_WAREHOUSE_ID!;

export async function executeSQL(statement: string) {
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

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Databricks API Error: ${error}`);
  }

  const result = await response.json();

  return result;
}