#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Load env if present
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ ! -d .venv ]; then
  echo "Creating virtualenv..."
  python3 -m venv .venv
fi

source .venv/bin/activate
pip install -r requirements.txt >/dev/null

echo "Starting backend on http://0.0.0.0:8000 (user: ${BASIC_USER:-demo})"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

