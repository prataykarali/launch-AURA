#!/usr/bin/env bash
set -euo pipefail

# Deletes AURA's local memory database and durable notebook mirrors.
# The app recreates clean files on the next auraInit().

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${HOME:-/home/pratay-karali}"
XDG_ROOT="${XDG_DATA_HOME:-$HOME_DIR/.local/share}"

DB_PATHS=(
  "$XDG_ROOT/aura_notebook/aura_memory.db"
  "$ROOT_DIR/aura_notebook/aura_memory.db"
  "$ROOT_DIR/aura_memory.db"
)

JSONL_PATHS=(
  "$XDG_ROOT/AURA/notebook.jsonl"
  "$XDG_ROOT/aura_notebook/notebook.jsonl"
  "$ROOT_DIR/aura_notebook/notebook.jsonl"
  "$ROOT_DIR/notebook.jsonl"
)

echo "Starting AURA memory purge..."

for db in "${DB_PATHS[@]}"; do
  rm -f "$db" "$db-wal" "$db-shm"
  echo "Removed DB path: $db"
done

for jsonl in "${JSONL_PATHS[@]}"; do
  rm -f "$jsonl"
  echo "Removed mirror path: $jsonl"
done

find "$XDG_ROOT/aura_notebook" "$ROOT_DIR" \
  -name 'aura_memory.db.bak*' -o \
  -name 'temp_test_memory_*.db' -o \
  -name 'temp_test_memory_*.db-wal' -o \
  -name 'temp_test_memory_*.db-shm' 2>/dev/null | while read -r path; do
  rm -f "$path"
  echo "Removed extra memory file: $path"
done

echo "AURA memory purge complete. Clean DB and mirror files will be recreated on next launch."
