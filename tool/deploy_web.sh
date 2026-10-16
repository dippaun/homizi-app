#!/usr/bin/env bash
# Builds the staging web app and publishes build/web to Netlify.
# Requires NETLIFY_AUTH_TOKEN and NETLIFY_SITE_ID in the environment.
# The Netlify CLI reads those variables. They are not printed.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${NETLIFY_AUTH_TOKEN:-}" ]]; then
  echo "NETLIFY_AUTH_TOKEN is required." >&2
  exit 1
fi

if [[ -z "${NETLIFY_SITE_ID:-}" ]]; then
  echo "NETLIFY_SITE_ID is required." >&2
  exit 1
fi

flutter build web --release --dart-define-from-file=config/staging.json
npx netlify-cli deploy --prod --dir=build/web
