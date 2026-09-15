#!/bin/bash
# ============================================
# cors-test.sh — Prueba configuracion CORS
# Uso: ./cors-test.sh <url>
# Ej:  ./cors-test.sh https://api.target.com/data
# ============================================
URL="${1:-http://localhost:3000/api/data}"

echo "========================================"
echo " CORS TEST — $URL"
echo "========================================"

test_origin() {
    local ORIGIN="$1"
    local LABEL="$2"
    local RESPONSE=$(curl -s -I -H "Origin: $ORIGIN" "$URL")
    local ACAO=$(echo "$RESPONSE" | grep -i "Access-Control-Allow-Origin" | tr -d '\r')
    local ACAC=$(echo "$RESPONSE" | grep -i "Access-Control-Allow-Credentials" | tr -d '\r')
    local HTTP_CODE=$(echo "$RESPONSE" | head -1 | awk '{print $2}')
    
    echo "  Origin: $ORIGIN"
    echo "    HTTP: $HTTP_CODE"
    echo "    $ACAO"
    echo "    $ACAC"
    
    if echo "$ACAO" | grep -qi "$ORIGIN"; then
        echo "    ⚠ VULNERABLE: Origin reflejado"
    elif echo "$ACAO" | grep -qi "*"; then
        echo "    ⚠ VULNERABLE: Wildcard permitido"
    fi
    echo ""
}

echo ""
echo "[1] Origin legitimo (same-origin)"
test_origin "https://trusted-site.com" "Legitimo"

echo "[2] Origin malicioso"
test_origin "https://evil.com" "Malicioso"

echo "[3] Null origin"
test_origin "null" "Null"

echo "[4] Subdomain attack"
test_origin "https://trusted-site.com.evil.com" "Subdomain"

echo "[5] Origin con @"
test_origin "https://trusted-site.com@evil.com" "AT bypass"

echo "[6] Origin vacio"  
test_origin "" "Vacio"

echo "[7] Metodo OPTIONS (preflight)"
curl -s -X OPTIONS -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -I "$URL" 2>/dev/null | grep -i "access-control" | sed 's/^/  /'

echo ""
echo "========================================"
echo " VEREDICTO:"
echo " Si algun origin no autorizado aparece en"
echo " Access-Control-Allow-Origin -> VULNERABLE"
echo "========================================"
