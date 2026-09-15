#!/usr/bin/env bash
# ============================================================
# git-secret-audit.sh — Auditoría de secretos en un repo git:
#   [1] archivos sensibles en tracking   [2] .gitignore
#   [3] gitleaks (working tree)          [4] historial de commits
#   [5] archivos sensibles borrados      [6] frontend (keys embebidas)
# Ejecutar DENTRO del repositorio a auditar.
# Salida: security/evidence/
# ============================================================
set -u

OUT="security/evidence"
mkdir -p "$OUT"

echo "=== [1/6] Archivos sensibles en tracking (git ls-files) ==="
git ls-files | grep -iE "\.env|secret|credential|\.pem|\.p12|\.pfx|\.key$" || echo "  (ninguno)"

echo "=== [2/6] .gitignore — entradas de secretos ==="
grep -inE "env|secret|\.key" .gitignore 2>/dev/null || echo "  WARN: .gitignore sin entradas de secretos o inexistente"

echo "=== [3/6] gitleaks — working tree ==="
if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --source . --report-path "$OUT/gitleaks.json" --report-format json || true
    echo "  Reporte: $OUT/gitleaks.json"
else
    echo "  gitleaks NO instalado -> choco install gitleaks / brew install gitleaks"
    echo "  (o: npx gitleaks detect --source . --report-path $OUT/gitleaks.json)"
fi

echo "=== [4/6] Historial: commits con patrones de secretos (puede tardar) ==="
git log --all -p -G "api[_ -]?key|secret|password|token|BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE" 2>/dev/null \
    | grep -iE "^commit |api[_ -]?key|secret|password|token|BEGIN" \
    | head -80 > "$OUT/git-log-secrets.txt"
if [ -s "$OUT/git-log-secrets.txt" ]; then
    echo "  Posibles coincidencias -> $OUT/git-log-secrets.txt (primeras lineas:)"
    head -15 "$OUT/git-log-secrets.txt"
else
    echo "  (sin coincidencias)"
fi

echo "=== [5/6] Archivos sensibles BORRADOS del historial (aun en git) ==="
git log --all --diff-filter=D --name-only --pretty=format:"%h %s" -- "*.env*" "*secret*" "*credential*" 2>/dev/null \
    | head -40 > "$OUT/deleted-sensitive.txt"
if [ -s "$OUT/deleted-sensitive.txt" ]; then
    echo "  Revisar: $OUT/deleted-sensitive.txt"
    cat "$OUT/deleted-sensitive.txt"
else
    echo "  (nada)"
fi

echo "=== [6/6] Frontend: keys embebidas en codigo y bundles ==="
grep -rInE "AIza[0-9A-Za-z_-]{35}|sk_live_[0-9a-zA-Z]{24}|sk_test_[0-9a-zA-Z]{24}|AKIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|xox[baprs]-|-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE" \
    --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
    --include="*.vue" --include="*.html" --include="*.json" --include="*.env*" \
    . 2>/dev/null | grep -v "node_modules" | head -40 > "$OUT/frontend-secrets.txt"
if [ -s "$OUT/frontend-secrets.txt" ]; then
    echo "  Posibles keys -> $OUT/frontend-secrets.txt (triar falsos positivos)"
    cat "$OUT/frontend-secrets.txt"
else
    echo "  (ninguna encontrada)"
fi

echo
echo "=== COMPLETADO — Evidencia en $OUT/ ==="
echo "RECORDATORIO: secreto expuesto = comprometido -> ROTAR primero,"
echo "luego limpiar historial (git filter-repo --invert-paths --path <archivo> o BFG)."
