#!/usr/bin/env bash
# Health check for every hosted client site (+ the server itself).
#
#   health_check.sh domain1.com domain2.com ...           check sites from your computer
#   health_check.sh -f domains.txt                         one domain (or full URL) per line
#   health_check.sh -f domains.txt --server myvps          also check disk, memory, PM2, services, backups
#
# Prints a table and exits non-zero if anything needs attention.
# Checks per site: HTTPS answers 2xx/3xx, HTTP redirects to HTTPS, response time,
# SSL certificate days left (warns under 21), certificate matches the domain.
set -uo pipefail
DOMAINS=(); SERVER=""
while [ $# -gt 0 ]; do
  case "$1" in
    -f) while read -r l; do l=${l%%#*}; l=$(echo "$l" | xargs); [ -n "$l" ] && DOMAINS+=("$l"); done < "$2"; shift 2 ;;
    --server) SERVER=$2; shift 2 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) DOMAINS+=("$1"); shift ;;
  esac
done
[ ${#DOMAINS[@]} -gt 0 ] || [ -n "$SERVER" ] || { sed -n '2,11p' "$0"; exit 1; }

problems=0
warn() { problems=$((problems + 1)); }
if [ ${#DOMAINS[@]} -gt 0 ]; then
  printf '%-34s %-6s %-8s %-9s %-10s %s\n' "SITE" "HTTPS" "TIME" "SSL DAYS" "HTTP→HTTPS" "NOTE"
  for d in "${DOMAINS[@]}"; do
    url=$d; [[ "$url" =~ ^https?:// ]] || url="https://$d"
    host=$(echo "$url" | sed -E 's#^https?://([^/:]+).*#\1#')
    read -r code t < <(curl -s -o /dev/null -w '%{http_code} %{time_total}' --max-time 20 "$url" 2>/dev/null || echo "000 0")
    note=""
    case "$code" in 2*|3*) ;; 000) note="no answer"; warn ;; *) note="HTTP $code"; warn ;; esac
    end=$(echo | timeout 10 openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$end" ]; then
      days=$(( ( $(date -d "$end" +%s) - $(date +%s) ) / 86400 ))
      [ "$days" -lt 21 ] && { note="$note SSL expires soon"; warn; }
      if ! echo | timeout 10 openssl s_client -servername "$host" -connect "$host:443" -verify_hostname "$host" 2>/dev/null | grep -q 'Verify return code: 0'; then
        note="$note SSL invalid/mismatch"; warn
      fi
    else
      days="—"; [[ "$url" =~ ^https ]] && { note="$note no SSL"; warn; }
    fi
    redir=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 10 "http://$host/" 2>/dev/null)
    case "$redir" in 30[1278]\ https://*) r="yes" ;; *) r="NO"; [[ "$url" =~ ^https ]] && { note="$note no redirect"; warn; } ;; esac
    awk -v t="$t" 'BEGIN { exit !(t > 3) }' && note="$note slow"
    printf '%-34s %-6s %-8s %-9s %-10s %s\n' "$host" "$code" "${t:0:5}s" "$days" "$r" "${note# }"
  done
fi

if [ -n "$SERVER" ]; then
  echo
  echo "Server $SERVER:"
  if ! ssh "$SERVER" bash -s <<'REMOTE'
p=0
disk=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
echo "  disk /: ${disk}% used"; [ "$disk" -ge 85 ] && { echo "  ⚠ disk almost full"; p=1; }
mem=$(free | awk '/^Mem:/ {printf "%d", ($2-$7)*100/$2}')
echo "  memory: ${mem}% used"; [ "$mem" -ge 90 ] && { echo "  ⚠ memory almost full"; p=1; }
echo "  load: $(cut -d' ' -f1-3 /proc/loadavg) on $(nproc) cores"
if [ -d /run/systemd/system ]; then
  failed=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
  [ -n "$failed" ] && { echo "  ⚠ failed services: $failed"; p=1; }
  for s in nginx mysql mariadb postgresql php8.3-fpm php8.2-fpm php8.1-fpm docker; do
    if systemctl is-enabled "$s" >/dev/null 2>&1; then
      st=$(systemctl is-active "$s" 2>/dev/null); [ "$st" = active ] || { echo "  ⚠ $s is $st"; p=1; }
    fi
  done
else
  echo "  (no systemd — service checks skipped)"
fi
if command -v pm2 >/dev/null; then
  bad=$(pm2 jlist 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    d=[]
print(" ".join(f"{x[\"name\"]}({x[\"pm2_env\"][\"status\"]},{x[\"pm2_env\"].get(\"restart_time\",0)} restarts)" for x in d if x["pm2_env"]["status"]!="online" or x["pm2_env"].get("restart_time",0)>20))' 2>/dev/null)
  [ -n "$bad" ] && { echo "  ⚠ PM2: $bad"; p=1; } || echo "  PM2: all online"
fi
newest=$(find /var/backups/sites -mindepth 2 -maxdepth 2 -type d -name '20*' -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
if [ -n "$newest" ]; then
  age=$(( ( $(date +%s) - ${newest%.*} ) / 3600 ))
  echo "  newest backup: ${age}h ago"; [ "$age" -gt 30 ] && { echo "  ⚠ backups are not running"; p=1; }
else
  echo "  ⚠ no backups found in /var/backups/sites"; p=1
fi
[ -f /var/run/reboot-required ] && echo "  note: reboot required for updates"
exit $p
REMOTE
  then warn; fi
fi
echo
if [ $problems -eq 0 ]; then echo "All good."; else echo "$problems thing(s) need attention."; fi
[ $problems -eq 0 ]
