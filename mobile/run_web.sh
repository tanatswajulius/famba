#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f .env.web ]; then
  set -a
  source .env.web
  set +a
else
  echo "No .env.web found, using defaults from env.web.example"
  export API_BASE=${API_BASE:-http://localhost:8000}
  export API_USER=${API_USER:-demo}
  export API_PASS=${API_PASS:-demo123}
fi

echo "Using API_BASE=$API_BASE"
flutter pub get >/dev/null
flutter run -d chrome \
  --dart-define API_BASE="$API_BASE" \
  --dart-define API_USER="$API_USER" \
  --dart-define API_PASS="$API_PASS"

