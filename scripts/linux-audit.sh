#!/bin/bash
# ============================================
# linux-audit.sh — Auditoria de seguridad basica de Linux
# Uso: sudo ./linux-audit.sh [dir_salida]
# Recolecta: sistema, cuentas, permisos, software,
# red, servicios, logs, rootkits e integridad.
# Solo lectura salvo la creacion del directorio de salida.
# ============================================
OUTDIR="${1:-security/linux-audit-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTDIR"
SUMMARY="$OUTDIR/SUMMARY.txt"
: > "$SUMMARY"

echo "========================================"
echo " LINUX AUDIT — $(hostname) — $(date)"
echo " Salida: $OUTDIR"
echo "========================================"

log() { echo "[+] $*" | tee -a "$SUMMARY"; }

# 1. Sistema
log "Sistema"
{ uname -a; cat /etc/os-release; uptime; } > "$OUTDIR/01-system.txt" 2>&1

# 2. Cuentas
log "Cuentas con UID 0 y cuentas con shell"
awk -F: '$3==0 {print $1" (uid 0)"}' /etc/passwd > "$OUTDIR/02-uid0.txt"
grep -E '(/bin/bash|/bin/sh|/bin/zsh)$' /etc/passwd | cut -d: -f1 | sort > "$OUTDIR/03-users-shell.txt"

# 3. Accesos recientes y sesiones activas
log "Ultimos logins y sesiones activas"
last -25 > "$OUTDIR/04-last.txt" 2>&1
w > "$OUTDIR/05-who.txt" 2>&1

# 4. Reglas sudo
log "Sudoers (sin comentarios)"
grep -rhvE '^\s*(#|$)' /etc/sudoers /etc/sudoers.d/ 2>/dev/null > "$OUTDIR/06-sudoers.txt"

# 5. Permisos
log "SUID/SGID y permisos criticos"
find / -xdev -perm -4000 -type f 2>/dev/null > "$OUTDIR/07-suid.txt"
find / -xdev -perm -2000 -type f 2>/dev/null >> "$OUTDIR/07-suid.txt"
ls -la /etc/passwd /etc/shadow /etc/gshadow /etc/ssh /root 2>/dev/null >> "$OUTDIR/07-suid.txt"

# 6. Software y actualizaciones pendientes
log "Software y actualizaciones pendientes"
{ 
  command -v dpkg >/dev/null 2>&1 && echo "paquetes dpkg: $(dpkg -l 2>/dev/null | wc -l)"
  command -v rpm  >/dev/null 2>&1 && echo "paquetes rpm:  $(rpm -qa 2>/dev/null | wc -l)"
  apt list --upgradable 2>/dev/null | grep -i security
  yum check-update --security 2>/dev/null
} > "$OUTDIR/08-software.txt"

# 7. Red
log "Puertos, interfaces y firewall"
ss -tulnp > "$OUTDIR/09-ports.txt" 2>&1
ip -brief addr > "$OUTDIR/10-interfaces.txt" 2>&1 || ip addr > "$OUTDIR/10-interfaces.txt" 2>&1
iptables -S > "$OUTDIR/11-firewall.txt" 2>&1 || echo "iptables no disponible (ver nftables)" >> "$OUTDIR/11-firewall.txt"
nft list ruleset >> "$OUTDIR/11-firewall.txt" 2>&1

# 8. Servicios y tareas programadas
log "Servicios habilitados, cron y at"
systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null > "$OUTDIR/12-services.txt"
{ for d in /etc/cron* /var/spool/cron; do
    if [ -d "$d" ]; then echo "## $d"; find "$d" -type f -exec cat {} \; 2>/dev/null; fi
  done
} > "$OUTDIR/13-scheduled.txt"
ls -la /var/spool/at/ 2>/dev/null >> "$OUTDIR/13-scheduled.txt"

# 9. Logs de autenticacion
log "Intentos fallidos y logins root recientes"
for flog in /var/log/auth.log /var/log/secure; do
  if [ -f "$flog" ]; then
    grep -E 'Failed password|Invalid user' "$flog" | tail -30 > "$OUTDIR/14-failed-auth.txt"
    grep 'session opened for user root' "$flog" | tail -20 > "$OUTDIR/15-root-logins.txt"
    break
  fi
done
journalctl -u ssh --no-pager -n 20 2>/dev/null >> "$OUTDIR/14-failed-auth.txt"

# 10. Rootkits / integridad (si hay herramientas)
log "Rootkits / integridad (según herramientas instaladas)"
if command -v chkrootkit >/dev/null 2>&1; then
    chkrootkit > "$OUTDIR/16-rootkit.txt" 2>&1
else
    echo "chkrootkit no instalado (apt install chkrootkit)" | tee -a "$SUMMARY"
fi
if command -v rkhunter >/dev/null 2>&1; then
    rkhunter --check --skip-keypress >> "$OUTDIR/16-rootkit.txt" 2>&1
fi
if command -v lynis >/dev/null 2>&1; then
    lynis audit system --quick > "$OUTDIR/17-lynis.txt" 2>&1
else
    echo "lynis no instalado (apt install lynis)" | tee -a "$SUMMARY"
fi

# 11. Resumen
echo "" | tee -a "$SUMMARY"
echo "Archivos generados:" | tee -a "$SUMMARY"
ls -1 "$OUTDIR" | sed 's/^/  /' | tee -a "$SUMMARY"
echo "" | tee -a "$SUMMARY"
echo "Analiza cada archivo y genera security/report.md con hallazgos y severidades." | tee -a "$SUMMARY"