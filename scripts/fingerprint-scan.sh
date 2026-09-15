#!/bin/bash
# ============================================
# fingerprint-scan.sh — Detecta versiones de servidor/framework
# Uso: ./fingerprint-scan.sh <url>
# Ej:  ./fingerprint-scan.sh https://target.com
# ============================================
URL="${1:?Uso: $0 <url>}"

echo "== HEADERS DE VERSION =="
curl -sI -L --max-time 10 "$URL" | grep -iE '^(server|x-powered-by|x-aspnet|x-generator|via|x-runtime|x-pingback)'

echo ""
echo "== INDICADORES EN BODY =="
curl -sL --max-time 10 "$URL" | grep -ioE 'wp-content|generator[^>]*|joomla|drupal|laravel|django|flask|express|next|nuxt|react|vue|angular|asp\.net|spring|rails' | sort -u

echo ""
echo "== ENDPOINTS DE VERSION =="
for p in robots.txt CHANGELOG CHANGELOG.md README.md VERSION version.txt package.json composer.json wp-json administrator manager/html actuator swagger-ui.html openapi.json graphql info.php phpinfo.php; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL/$p")
    echo "  $code /$p"
done