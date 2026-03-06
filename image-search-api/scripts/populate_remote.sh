#!/usr/bin/env bash
# populate_remote.sh — Push a local JSONL dump into Typesense on the remote EC2.
#
# What it does:
#   1. SCPs the JSONL file to the remote server's /tmp/
#   2. SSHes in, uses TYPESENSE_API_KEY from local .env
#   3. Creates the Typesense collection (idempotent) via the REST API
#   4. Imports the JSONL in chunks using the Typesense bulk-import endpoint
#
# Usage:
#   ./scripts/populate_remote.sh <remote_ip> [jsonl_file] [ssh_key]
#
# Examples:
#   ./scripts/populate_remote.sh 13.233.45.67
#   ./scripts/populate_remote.sh 13.233.45.67 unsplash_photos.jsonl ~/.ssh/id_rsa

set -euo pipefail

# Load local .env file
source .env

REMOTE_IP="${1:?Usage: $0 <remote_ip> [jsonl_file] [ssh_key]}"
JSONL_FILE="${2:-unsplash_photos.jsonl}"
SSH_KEY="${3:-$HOME/.ssh/id_rsa}"
REMOTE_USER="ubuntu"
REMOTE_DIR="/tmp"
TYPESENSE_PORT="8108"

SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10"

[[ -f "$JSONL_FILE" ]] || { echo "ERROR: JSONL file not found: $JSONL_FILE" >&2; exit 1; }

FILENAME=$(basename "$JSONL_FILE")
REMOTE_PATH="$REMOTE_DIR/$FILENAME"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Target  : $REMOTE_USER@$REMOTE_IP"
echo " JSONL   : $JSONL_FILE  ($(wc -l < "$JSONL_FILE" | xargs) documents)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Step 1: Upload JSONL ──────────────────────────────────────────────────────
echo ""
echo "[1/3] Uploading $FILENAME → $REMOTE_IP:$REMOTE_PATH …"
scp $SSH_OPTS "$JSONL_FILE" "$REMOTE_USER@$REMOTE_IP:$REMOTE_PATH"
echo "      Upload complete."

# ── Step 2 & 3: Create collection + import (runs entirely on the remote) ──────
echo ""
echo "[2/3] Creating Typesense collection (if not exists) …"
echo "[3/3] Importing documents …"

ssh $SSH_OPTS "$REMOTE_USER@$REMOTE_IP" bash << REMOTE_SCRIPT
set -euo pipefail

TSENSE_KEY="$TYPESENSE_API_KEY"
TSENSE_URL="http://localhost:$TYPESENSE_PORT"

if [[ -z "\$TSENSE_KEY" ]]; then
  echo "ERROR: TYPESENSE_API_KEY not found in local .env" >&2
  exit 1
fi

COLLECTION="unsplash_photos"

# Create collection — idempotent (409 = already exists, which is fine)
HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" -X POST "\$TSENSE_URL/collections" \\
  -H "X-TYPESENSE-API-KEY: \$TSENSE_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "name": "unsplash_photos",
    "fields": [
      {"name": "photo_id",             "type": "string"},
      {"name": "photo_description",    "type": "string",   "optional": true},
      {"name": "ai_description",       "type": "string",   "optional": true},
      {"name": "photographer_username","type": "string"},
      {"name": "photo_width",          "type": "int32"},
      {"name": "photo_height",         "type": "int32"},
      {"name": "photo_image_url",      "type": "string"},
      {"name": "photo_url",            "type": "string",   "optional": true},
      {"name": "stats_views",          "type": "int64",    "optional": true},
      {"name": "stats_downloads",      "type": "int64",    "optional": true},
      {"name": "keywords",             "type": "string[]", "optional": true},
      {"name": "colors",               "type": "string[]", "optional": true},
      {"name": "location_city",        "type": "string",   "optional": true},
      {"name": "location_country",     "type": "string",   "optional": true}
    ]
  }')

if [[ "\$HTTP_STATUS" == "201" ]]; then
  echo "      Collection created."
elif [[ "\$HTTP_STATUS" == "409" ]]; then
  echo "      Collection already exists — skipping creation."
else
  echo "ERROR: unexpected HTTP \$HTTP_STATUS when creating collection." >&2
  exit 1
fi

# Import JSONL — upsert so reruns are safe
echo "      Importing $REMOTE_PATH …"
RESULT=\$(curl -s -X POST "\$TSENSE_URL/collections/\$COLLECTION/documents/import?action=upsert" \\
  -H "X-TYPESENSE-API-KEY: \$TSENSE_KEY" \\
  -H "Content-Type: text/plain" \\
  --data-binary @"$REMOTE_PATH")

TOTAL=\$(echo "\$RESULT" | wc -l)
ERRORS=\$(echo "\$RESULT" | grep -c '"success":false' || true)
OK=\$(( TOTAL - ERRORS ))

echo "      Imported: \$OK / \$TOTAL  (errors: \$ERRORS)"
if [[ \$ERRORS -gt 0 ]]; then
  echo "      First error sample:"
  echo "\$RESULT" | grep '"success":false' | head -3
fi

# Clean up upload
rm -f "$REMOTE_PATH"
echo "      Done."
REMOTE_SCRIPT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Typesense population complete."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
