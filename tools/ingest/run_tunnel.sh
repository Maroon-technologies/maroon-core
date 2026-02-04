#!/usr/bin/env bash
set -euo pipefail

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not installed. Install it or use another tunnel." >&2
  exit 1
fi

cloudflared tunnel --url http://localhost:8000
