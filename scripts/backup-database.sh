#!/usr/bin/env bash
# Take a point-in-time MongoDB backup before a deploy that may change data.
# Requires mongodump on PATH (or MONGODB_BACKUP_COMMAND to override).
set -euo pipefail

: "${MONGODB_URI:?MONGODB_URI must be set}"
OUTPUT_DIR="${1:-./backups/$(date -u +%Y%m%dT%H%M%SZ)}"

if ! command -v mongodump >/dev/null 2>&1; then
  echo "backup: mongodump not found. If MongoDB Atlas is used, take a"
  echo "        provider snapshot instead and record its id in the release evidence."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
mongodump --uri="$MONGODB_URI" --out="$OUTPUT_DIR"
echo "backup: wrote $OUTPUT_DIR - verify it can be restored before proceeding."
