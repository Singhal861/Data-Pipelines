import os
import json
from dotenv import load_dotenv
from databricks import sql

load_dotenv()

HOST = os.getenv("DATABRICKS_HOST")
HTTP_PATH = os.getenv("DATABRICKS_HTTP_PATH")
TOKEN = os.getenv("DATABRICKS_TOKEN")


def execute_query(query: str):
    """
    Execute SQL query and return list of dictionaries.
    """

    with sql.connect(
        server_hostname=HOST,
        http_path=HTTP_PATH,
        access_token=TOKEN,
    ) as connection:

        with connection.cursor() as cursor:

            cursor.execute(query)

            columns = [col[0] for col in cursor.description]

            rows = cursor.fetchall()

            return [
                dict(zip(columns, row))
                for row in rows
            ]


def json_response(handler, data, status=200):
    """
    Send JSON response.
    """

    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.end_headers()

    handler.wfile.write(
        json.dumps(data, default=str).encode("utf-8")
    )