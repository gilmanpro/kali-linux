#!/bin/bash
# ============================================
# rate-limit-test.sh — Verifica rate limit
# Uso: ./rate-limit-test.sh <url> [n_requests] [metodo] [data]
# Ej:  ./rate-limit-test.sh http://target.local/login 20 POST "user=admin&pass=wrong"
# Nota: ráfaga controlada; no uses valores altos de n.
# ============================================
URL="${1:?Uso: $0 <url> [n] [metodo] [data]}"
N="${2:-20}"
METHOD="${3:-GET}"
DATA="$4"

echo "== BASELINE =="
curl -s -o /dev/null -w "  %{http_code} en %{time_total}s\n" --max-time 10 "$URL"

echo ""
echo "== $N REQUESTS ($METHOD) =="
for i in $(seq 1 "$N"); do
    if [ -n "$DATA" ]; then
        curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -X "$METHOD" --data "$DATA" "$URL"
    else
        curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -X "$METHOD" "$URL"
    fi
done | sort | uniq -c

echo ""
echo "== HEADERS DE RATE LIMIT =="
curl -sI --max-time 10 "$URL" | grep -iE 'ratelimit|retry-after|429' || echo "  Sin headers de rate limit"