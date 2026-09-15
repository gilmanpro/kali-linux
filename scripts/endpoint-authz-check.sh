#!/usr/bin/env bash
# ============================================================
# endpoint-authz-check.sh — Verifica que los endpoints que
# DEBEN requerir autenticación la exijan de verdad (A01/BOLA).
# Uso:
#   endpoint-authz-check.sh <base_url> [token] < endpoints.txt
#   echo "GET /api/users" | endpoint-authz-check.sh https://target.com
# Formato de endpoints.txt: METODO /ruta  (una por línea, # = comentario)
#   GET /api/users
#   POST /api/orders
#   GET /api/admin/users
# Salida: security/evidence/endpoint-authz.csv + tabla en consola
# ============================================================
set -u

BASE="${1:?Uso: $0 <base_url> [token] < endpoints.txt | echo 'GET /api/users' | $0 https://target.com}"
TOKEN="${2:-}"
OUT="security/evidence/endpoint-authz.csv"
mkdir -p security/evidence

echo "METODO,RUTA,CODIGO_SIN_AUTH,REDIREC,RESULTADO,CODIGO_CON_TOKEN" > "$OUT"

check() {
    local method="$1" path="$2"
    local url="$BASE$path"
    local code redir code_tok res
    code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url")
    redir=$(curl -s -o /dev/null -w "%{redirect_url}" -X "$method" "$url")
    if [ "$code" = "401" ] || [ "$code" = "403" ]; then
        res="OK"
    else
        res="FALLO"
    fi
    code_tok=""
    if [ -n "$TOKEN" ]; then
        code_tok=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" \
            -H "Authorization: Bearer $TOKEN" "$url")
    fi
    printf "%s,%s,%s,%s,%s,%s\n" "$method" "$path" "$code" "$redir" "$res" "${code_tok:-}" >> "$OUT"
    printf "%-6s %-45s sin-auth: %s (%s)  con-token: %s\n" \
        "$method" "$path" "$code" "$res" "${code_tok:-n/a}"
}

process() {
    while read -r method path; do
        [ -z "$method" ] && continue
        case "$method" in \#*) continue ;; esac
        check "$method" "$path"
    done
}

if [ -t 0 ]; then
    # Sin entrada por stdin: usar archivo endpoints.txt si existe
    if [ -f endpoints.txt ]; then
        process < endpoints.txt
    else
        echo "Uso: $0 <base_url> [token] < endpoints.txt" >&2
        echo "  o:  echo 'GET /api/users' | $0 https://target.com" >&2
        exit 1
    fi
else
    process
fi

echo
echo "Resultados: $OUT  (FALLO = accesible sin auth → investigar)"
