import os
import json

import boto3
import psycopg2
from flask import Flask, request, jsonify

app = Flask(__name__)


def get_db_credentials():
    """Read the DB username/password from AWS Secrets Manager."""
    secret_arn = os.environ["SECRET_ARN"]
    region = os.environ.get("AWS_REGION", "eu-central-1")
    client = boto3.client("secretsmanager", region_name=region)
    secret = client.get_secret_value(SecretId=secret_arn)
    return json.loads(secret["SecretString"])


def get_connection():
    creds = get_db_credentials()
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=creds["username"],
        password=creds["password"],
        connect_timeout=5,
    )


def init_db():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "CREATE TABLE IF NOT EXISTS items ("
        "id SERIAL PRIMARY KEY, name TEXT NOT NULL);"
    )
    conn.commit()
    cur.close()
    conn.close()


@app.route("/")
def home():
    return "Hello World from the ECS Fargate backend!"


@app.route("/health")
def health():
    # Kept DB-independent so the ALB health check stays green during DB blips.
    return "OK", 200


@app.route("/items", methods=["GET"])
def list_items():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name FROM items ORDER BY id;")
    rows = [{"id": r[0], "name": r[1]} for r in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/items", methods=["POST"])
def create_item():
    name = (request.get_json(force=True, silent=True) or {}).get("name")
    if not name:
        return jsonify({"error": "name is required"}), 400
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO items (name) VALUES (%s) RETURNING id;", (name,))
    item_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"id": item_id, "name": name}), 201


@app.route("/items/<int:item_id>", methods=["PUT"])
def update_item(item_id):
    name = (request.get_json(force=True, silent=True) or {}).get("name")
    if not name:
        return jsonify({"error": "name is required"}), 400
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("UPDATE items SET name = %s WHERE id = %s;", (name, item_id))
    updated = cur.rowcount
    conn.commit()
    cur.close()
    conn.close()
    if not updated:
        return jsonify({"error": "not found"}), 404
    return jsonify({"id": item_id, "name": name})


@app.route("/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM items WHERE id = %s;", (item_id,))
    deleted = cur.rowcount
    conn.commit()
    cur.close()
    conn.close()
    if not deleted:
        return jsonify({"error": "not found"}), 404
    return jsonify({"deleted": item_id})


if __name__ == "__main__":
    try:
        init_db()
    except Exception as exc:  # don't crash the container if the DB isn't ready yet
        print("DB init skipped:", exc)
    app.run(host="0.0.0.0", port=5000)
