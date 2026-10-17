#!/usr/bin/env bash
# Deploy the portfolio (public/) to the VPS. Works from Git Bash on Windows (no rsync needed).
#
#   bash deploy/without-coolify/deploy.sh              upload public/ as a new release and switch to it instantly
#   bash deploy/without-coolify/deploy.sh --rollback   switch back to the previous release
#   bash deploy/without-coolify/deploy.sh --list       show releases on the server
#
# Server layout:  /var/www/ahmad-zaven.io/releases/<timestamp>/
#                 /var/www/ahmad-zaven.io/current -> releases/<timestamp>   (what nginx serves)
# SSH_HOST is the alias from ~/.ssh/config (see deploy/SETUP.md). Override: SSH_HOST=myvps bash deploy/without-coolify/deploy.sh
set -euo pipefail

HOST=${SSH_HOST:-vps}
DOMAIN=ahmad-zaven.io
BASE=/var/www/$DOMAIN
KEEP=5
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC=$ROOT/public

case "${1:-}" in
  --list)
    ssh "$HOST" "ls -1t '$BASE/releases' | head -20; echo; echo -n 'current -> '; readlink '$BASE/current'"
    exit 0 ;;
  --rollback)
    ssh "$HOST" "bash -s -- '$BASE'" <<'REMOTE'
set -euo pipefail
BASE=$1
cur=$(basename "$(readlink "$BASE/current")")
prev=$(ls -1 "$BASE/releases" | sort | awk -v c="$cur" '$0 < c' | tail -1)
[ -n "$prev" ] || { echo "No earlier release to roll back to."; exit 1; }
ln -sfn "$BASE/releases/$prev" "$BASE/current.tmp" && mv -Tf "$BASE/current.tmp" "$BASE/current"
echo "Rolled back: $cur -> $prev"
REMOTE
    exit 0 ;;
  "") ;;
  *) sed -n '2,11p' "$0"; exit 1 ;;
esac

[ -f "$SRC/index.html" ] || { echo "public/index.html not found"; exit 1; }

# Warn about contact buttons that are still empty (they stay hidden on the site)
missing=$(grep -oE 'const CONTACT = \{[^}]*\}' "$SRC/index.html" | grep -oE '[a-z]+:""' | cut -d: -f1 | tr '\n' ' ' || true)
if [ -n "$missing" ]; then
  echo "⚠ Contact details still empty in public/index.html: $missing"
  echo "  Those buttons will be hidden on the live site."
  read -r -p "  Deploy anyway? [y/N] " ok; [ "$ok" = y ] || [ "$ok" = Y ] || exit 1
fi

TS=$(date +%Y%m%d-%H%M%S)
REL=$BASE/releases/$TS
echo "→ Uploading public/ to $HOST:$REL"
tar -C "$SRC" -czf - --exclude='./.*' . | ssh "$HOST" "mkdir -p '$REL' && tar -xzf - -C '$REL' && find '$REL' -type d -exec chmod 755 {} + && find '$REL' -type f -exec chmod 644 {} +"

ssh "$HOST" "bash -s -- '$BASE' '$REL' '$KEEP'" <<'REMOTE'
set -euo pipefail
BASE=$1; REL=$2; KEEP=$3
ln -sfn "$REL" "$BASE/current.tmp" && mv -Tf "$BASE/current.tmp" "$BASE/current"
cd "$BASE/releases"
cur=$(basename "$REL")
ls -1t | { grep -vx "$cur" || true; } | tail -n +"$KEEP" | while read -r old; do rm -rf -- "${BASE:?}/releases/${old:?}"; done
echo "✓ Live: $(readlink "$BASE/current")  ($(ls -1 | wc -l) releases kept)"
REMOTE

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$DOMAIN/" || true)
[ "$code" = "000" ] && code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "http://$DOMAIN/" || true)
echo "→ $DOMAIN answered HTTP $code"
case "$code" in 2*|3*) ;; *) echo "⚠ Site check failed. Roll back with: bash deploy/without-coolify/deploy.sh --rollback" ;; esac
echo "Rollback: bash deploy/without-coolify/deploy.sh --rollback"
