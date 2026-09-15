#!/bin/bash
# ============================================
# route-scan.sh — Verifica rutas sensibles
# Uso: ./route-scan.sh <url>
# Lista: scripts/paths/common-sensitive-paths.txt
# Imprime rutas con status != 404/403 y contenido > 0
# ============================================
URL="${1:?Uso: $0 <url>}"
LIST_DIR="$(cd "$(dirname "$0")" && pwd)/paths"
LIST="$LIST_DIR/common-sensitive-paths.txt"
mkdir -p security
OUT="security/route-scan-$(date +%Y%m%d-%H%M%S).txt"
BODY="$(mktemp)"

[ -f "$LIST" ] || { echo "No existe $LIST"; exit 1; }

echo "========================================"
echo " ROUTE SCAN — $URL"
echo "========================================"
echo "Filtrando: status != 404 y != 403 con contenido > 0 bytes"
echo ""

while IFS= read -r p; do
    [ -z "$p" ] && continue
    resp=$(curl -s -o "$BODY" -w "%{http_code}|%{size_download}|%{content_type}" --max-time 10 "$URL/$p")
    code="${resp%%|*}"
    rest="${resp#*|}"
    size="${rest%%|*}"
    ctype="${rest#*|}"
    if [ "$code" != "404" ] && [ "$code" != "403" ] && [ "${size:-0}" -gt 0 ] 2>/dev/null; then
        echo "  $code  ${size}B  /$p  [$ctype]"
        echo "$code  ${size}B  /$p  [$ctype]" >> "$OUT"
        case "$ctype" in
            *json*|*text*) cp "$BODY" "security/route-${p//\//_}.body" 2>/dev/null ;;
        esac
    fi
done < "$LIST"

echo ""
echo "Resultados guardados en: $OUT"
rm -f "$BODY"