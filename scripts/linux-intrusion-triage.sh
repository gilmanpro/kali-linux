#!/bin/bash
# ============================================
# linux-intrusion-triage.sh — Triaje rapido de posible intrusion
# Uso: sudo ./linux-intrusion-triage.sh
# SOLO LECTURA: no modifica nada del sistema.
# Genera salida en pantalla (12 pasos).
# ============================================
echo "========================================"
echo " TRIAGE DE INTRUSION — $(hostname) — $(date)"
echo "========================================"

echo; echo "== 1. SESIONES ACTIVAS =="
w

echo; echo "== 2. ULTIMOS LOGINS =="
last -25 2>/dev/null

echo; echo "== 3. USUARIOS CON UID 0 =="
awk -F: '$3==0 {print}' /etc/passwd

echo; echo "== 4. USUARIOS CON SHELL =="
awk -F: '$7 ~ /\/(bash|sh|zsh)$/ {print $1, $6}' /etc/passwd

echo; echo "== 5. PROCESOS SOSPECHOSOS (minado, shells inversos, descargas) =="
ps auxf 2>/dev/null | grep -iE '(nc |ncat|socat|tunnel|xmrig|minerd|kdevtmpfsi|kinsing|curl |wget |bash -i|python.*socket|/dev/tcp)' | grep -v grep || echo "  (ninguno obvio)"

echo; echo "== 6. CONEXIONES ACTIVAS =="
ss -tunp 2>/dev/null | grep ESTAB || netstat -tunp 2>/dev/null | grep ESTAB || echo "  sin conexiones establecidas"

echo; echo "== 7. BINARIOS SUID/SGID NUEVOS (modificados en 30 dias) =="
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -mtime -30 2>/dev/null || echo "  ninguno"

echo; echo "== 8. CRON Y TAREAS PROGRAMADAS =="
for d in /etc/cron* /var/spool/cron; do
  if [ -d "$d" ]; then echo "## $d"; find "$d" -type f -exec cat {} \; 2>/dev/null; fi
done
ls -la /var/spool/at/ 2>/dev/null

echo; echo "== 9. BASH HISTORY DE ROOT =="
tail -40 /root/.bash_history 2>/dev/null || echo "  sin acceso a /root/.bash_history"

echo; echo "== 10. ARCHIVOS DE /etc MODIFICADOS EN 48H =="
find /etc -type f -mtime -2 2>/dev/null | head -40

echo; echo "== 11. ROOTKIT CHECK =="
if command -v chkrootkit >/dev/null 2>&1; then
    chkrootkit 2>/dev/null | grep -v 'not infected' || echo "  chkrootkit sin hallazgos"
elif command -v rkhunter >/dev/null 2>&1; then
    rkhunter --check --skip-keypress 2>/dev/null | tail -20
else
    echo "  instala chkrootkit o rkhunter (apt install chkrootkit rkhunter)"
fi

echo; echo "== 12. LOGS DE AUTENTICACION (recientes) =="
for flog in /var/log/auth.log /var/log/secure; do
  if [ -f "$flog" ]; then
    grep -E 'Failed password|Invalid user|Accepted' "$flog" | tail -25
    break
  fi
done

echo; echo "========================================"
echo " Si hay indicios: preserva la evidencia (no apagues, no"
echo " edites nada, copia /var/log y .bash_history), aísla el"
echo " host y sigue el playbook de respuesta del módulo Linux."
echo "========================================"