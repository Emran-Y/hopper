#!/usr/bin/env bash
# Build the landing page (static export) and publish it + the app downloads to the VPS.
#   landing/deploy.sh            → https://hopperclip.xyz  (and the preview at https://mants.emranyonas.com/hopper/)
set -euo pipefail
cd "$(dirname "$0")"
# Server settings live in landing/.deploy.env (not in git):  VPS=user@host  DEST=/path/on/server
[ -f .deploy.env ] || { echo "landing/.deploy.env missing (VPS=user@host, DEST=/path)"; exit 1; }
set -a; . ./.deploy.env; set +a
DL=../hopper/dist/downloads

npm run build
mkdir -p out/downloads
[ -d "$DL" ] && cp "$DL"/* out/downloads/
rsync -az --delete --exclude downloads out/ "$VPS:$DEST/"
rsync -az out/downloads/ "$VPS:$DEST/downloads/"
ssh "$VPS" "cd /opt/apps/hopperclip && docker compose up -d 2>&1 | tail -1"
echo "✓ live: https://hopperclip.xyz  ·  preview: https://mants.emranyonas.com/hopper/"
