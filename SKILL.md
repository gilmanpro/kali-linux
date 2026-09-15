---
name: kali-linux
description: "Agente pentester profesional AUTOCONTENIDO para Kali Linux: metodologia ofensiva completa (recon, escaneo, explotacion, post-explotacion, payloads OWASP, curl avanzado, automatizacion de navegador, reporting). Cubre AD/Kerberos (netexec, bloodhound-python, certipy-ad, bloodyAD, coercer, pypykatz, dploot, minikerberos), web (nuclei, ffuf, feroxbuster, arjun, subfinder, sqlmap, hydra, XSS/SQLi/SSRF/JWT/IDOR, playwright), red (nmap, nping, tcpdump, dig, responder), explotacion (metasploit, searchsploit, linpeas/winpeas) y crackeo (hashcat, john). Usar SIEMPRE que el usuario mencione: Kali, pentest, auditoria ofensiva, escanear puertos, crackear hashes, Active Directory, Kerberos, SMB/LDAP, OWASP, explotar un target, pivoting, post-explotacion, C2, o pida comandos de estas herramientas, aunque no nombre Kali. Requiere autorizacion explicita sobre el objetivo. NO usar para desarrollo funcional ni fixes sin componente ofensivo."
---

# Kali Linux — Super Skill de Pentesting Ofensivo

## METADATA DE INVOCACIÓN

**Agentes que me pueden cargar:**
- `@operario` — modo ACCIONES (ejecución de herramientas, escaneos, explotación)
- `@lector` — cuando la auditoría incluye revisión de seguridad activa sobre objetivos
- `@estratega` — para planificar campañas de red teaming y definir fases del pentest
- `@builder` — si el objetivo es desplegar infra de phishing/C2 como parte del engagement

**HERRAMIENTAS REQUERIDAS en el agente que me carga:**
- `bash` — **imprescindible**: esta skill se ejecuta EN una máquina Kali Linux (VM, contenedor o host); todos los comandos son nativos Linux (`sh`/`bash`). Nada requiere Windows.
- `read`, `glob`, `grep` — para revisar evidencia, wordlists y outputs de scans
- `webfetch` — consultar CVEs, GTFOBins, PlantUML de attack paths

**AUTOCONTENIDA:** no depende de ninguna otra skill ni de MCPs externos. Todo el contexto operativo (herramientas, payloads OWASP, curl de pentesting, automatizacion de navegador, scripts) esta en `references/` y `scripts/` de esta carpeta.

**CUÁNDO CARGARME (triggers):**
- "pentest", "auditoría ofensiva", "hack ético", "red team", "Kali", "atacar", "explotar"
- "escanea esta IP/red/dominio", "enumera el dominio", "dominio Windows"
- "crackea este hash", "roba tickets", "AS-REP", "Kerberoast", "DCSync", "relay"
- "escala privilegios", "post-explotación", "pivot", "túnel SOCKS", "acceso al DC"
- "controla ese equipo en remoto", "muévete lateralmente", "consigue Domain Admin/root", "sigue escalando"
- Menciones de: nmap, netexec, bloodhound, certipy, bloodyAD, nuclei, ffuf, hashcat, metasploit, sqlmap, responder, pypykatz, mimikatz...

**NO ME CARGUES SI:**
- El usuario pide ASEGURAR/PROTEGER su propio codigo (hardening, code review defensivo): responde desde OWASP sin ejecutar ofensiva
- Es desarrollo funcional, fixes o diseño sin componente ofensivo
- Es una pregunta conceptual de seguridad sin acción sobre un objetivo

---

## 0. Regla de Ética y Alcance (NO NEGOCIABLE)

Antes de ejecutar CUALQUIER herramienta ofensiva contra un objetivo:

1. **Confirmar autorización explícita del usuario** sobre el target (IP, rango, dominio, URL). Frases válidas: "es mi laboratorio", "tengo permiso por escrito", "CTF", "caja de HackTheBox/TryHackMe", "pentest autorizado cliente X".
2. Sin autorización clara → **no ejecutar**; ofrecer en su lugar un plan teórico, comandos listos para el usuario, o un laboratorio local.
3. Objetivo único por engagement: no escanear/rutear IPs vecinas aunque "caigan en el mismo rango".
4. Las herramientas locales (`nmap 127.0.0.1`, análisis de propios logs/archivos) no requieren confirmación.

## Regla de Alcance Operativo

- **Petición específica** ("haz un escaneo de puertos") → solo eso, no encadenes explotación ni post-expl.
- **Petición amplia ("pentest completo a X")** → sigue las fases PTES del §2, pidiendo confirmación antes de acciones destructivas o ruidosas (fuerza bruta, exploits con riesgo de caída).
- **Pregunta informativa** ("¿cómo funciona Kerberoast?") → explica con sintaxis, no ejecutes.

---

## 1. Entorno Kali — Convenciones de Trabajo

### Verificar disponibilidad antes de usar una herramienta

```bash
which nmap netexec nuclei ffuf            # ¿existe?
command-not-found <tool>                  # Kali sugiere el paquete apt
sudo apt update && sudo apt install -y <paquete>   # instalar lo que falte
# Metapaquetes si falta casi todo:
sudo apt install -y kali-linux-default    # set completo por defecto
sudo apt install -y default-mysql-client  # y otros segun herramienta
```

`nxc` es el alias histórico de `netexec` (sucesor de CrackMapExec). `certipy` y `certipy-ad` son el mismo binario según versión.

### Estructura de trabajo por objetivo (crear SIEMPRE al inicio)

```bash
TARGET=acme.com   # o IP/nombre corto
BASE=~/pentest/$TARGET
mkdir -p $BASE/{scans,evidence,loot,notes,report,wordlists}
chmod +x <ruta-de-esta-skill>/scripts/*.sh    # scripts incluidos (ver §10)
```

```
~/pentest/<target>/
├── scans/      # salidas de nmap, nuclei, ffuf... (con timestamp: nmap_20260915.txt)
├── evidence/   # screenshots, responses, logs que sustentan hallazgos
├── loot/       # credenciales, hashes, dumps (¡no commitear nunca a git!)
├── notes.md    # bitácora cronológica: comando → resultado → interpretación
├── wordlists/  # wordlists específicas del objetivo (creadas con ciphers)
└── report/     # informe final
```

Disciplina que separa un pentest profesional de uno improvisado: **todo comando ejecutado y su hallazgo se anota en `notes.md` en el momento**, con evidencia guardada en archivo. Un informe sin evidencia reproducible no vale.

### Wordlists nativas de Kali

```bash
/usr/share/wordlists/rockyou.txt          # general (descomprimir: gunzip rockyou.txt.gz)
/usr/share/wordlists/dirb/common.txt      # directorios web
/usr/share/wordlists/dirbuster/           # directory-list-2.3-small/medium
/usr/share/wordlists/seclists/            # SecLists completo (Discovery, Fuzzing, ...)
/usr/share/wordlists/fasttrack.txt        # passwords comunes para servicios
/usr/share/nmap/scripts/                  # scripts NSE
/usr/share/nmap/nmap-services             # fingerprints de puertos/servicios
```

### Personalización rápida de wordlists (casi siempre vale la pena)

```bash
# Generar variantes del objetivo con rules de hashcat/john
cat /usr/share/wordlists/rockyou.txt | grep -i acme > $BASE/wordlists/acme-base.txt
hashcat --stdout $BASE/wordlists/acme-base.txt -r /usr/share/hashcat/rules/best64.rule \
  | sort -u > $BASE/wordlists/acme-custom.txt
```

---

## 2. Metodología PTES — Fase → Herramienta

```
1. RECONOCIMIENTO          → OSINT, subfinder, dig/mdig, theHarvester, censys/shodan (web)
2. ESCANEO Y ENUMERACIÓN   → nmap, nping, netexec, bloodhound-python, nuclei, ffuf/feroxbuster
3. EXPLOTACIÓN             → metasploit, sqlmap, certipy, bloodyAD, relays, exploits manuales
4. POST-EXPLOTACIÓN        → pypykatz, dploot, linpeas/winpeas, hashcat, asysocks (pivot)
5. MOVIMIENTO LATERAL/ELEV → netexec, masky, remotinator, minikerberos, DCSync
6. REPORTE                  → plantilla §9 (informe final), obligatoria al cerrar sesion
```

### Bucle recursivo post-acceso (la regla de oro)

Un acceso NUNCA es el final: tras cada shell/credencial/hash/ticket, ejecutar el ciclo
**enumerar → escalar (SYSTEM/root) → lootear credenciales → matchear contra TODO el scope →
mover lateral → repetir desde el nuevo host**, hasta el objetivo del alcance o agotar
autorización. Cada cred nueva se prueba contra todos los hosts/servicios vivos; cada host
nuevo se re-enumera (puede ver redes que Kali no veía → pivoting). Ante duda de "¿seguimos?":
seguir, cambiando de vector, no de objetivo — y consultar al usuario solo cuando escalar más
suponga ruido/detención excesiva. Ciclo completo, comandos y matriz credencial→protocolo→host:
`references/escalation-lateral.md`.

Mapa de decisión rápida:

| Pregunta | Respuesta → ir a |
|---|---|
| ¿Objetivo es infraestructura/red? | `references/network-recon.md` |
| ¿Objetivo es una web/API? | `references/web-pentesting.md` + playbook `references/web-audit-curl.md` |
| ¿Payload/teoria OWASP de una clase (XSS, SQLi, SSRF, JWT...)? | `references/owasp-web.md` |
| ¿Curl avanzado (TLS, timing, auth, HTTP/2-3)? | `references/curl-http.md` |
| ¿SPA/JS/DOM/storage — testing con navegador? | `references/browser-playwright.md` |
| ¿Hay dominio Windows / AD? | `references/active-directory.md` |
| ¿Ya tengo shell/credenciales? | `references/exploit-postex.md` + **bucle**: `references/escalation-lateral.md` |
| ¿Modo especifico (wireless, mobile, IoT, red team, SE)? | `references/pentesting-modes.md` |
| ¿Necesito wordlists/proxies/utilidades? | `references/utilidades-kali.md` |

---

## 3. Flujo Externo Estándar (Infraestructura)

```bash
# 1. SUPERVIVENCIA: primer escaneo conservador y silencioso (top puertos, sin scripts)
sudo nmap -sS -T2 --top-ports 1000 -oG $BASE/scans/nmap_fast_$(date +%Y%m%d).txt target.tld

# 2. COMPLETO: todos los TCP + versiones + scripts por defecto (en tmux, puede tardar)
sudo nmap -sS -sV -sC -p- --min-rate 300 -oA $BASE/scans/nmap_full target.tld

# 3. UDP solo donde TCP sugiera (DNS 53, SNMP 161, DHCP, etc.)
sudo nmap -sU --top-ports 100 -sV -p 53,67,123,161,500,1701 -oA $BASE/scans/nmap_udp target.tld

# 4. Web discovery en cada puerto HTTP/HTTPS encontrado (ver §4 / web-pentesting.md)

# 5. Vulnerabilidades conocidas
nuclei -l $BASE/scans/urls.txt -t ~/nuclei-templates/ -severity medium,high,critical \
  -o $BASE/scans/nuclei_$(date +%Y%m%d).txt
searchsploit "Apache 2.4"   # buscar exploits locales por servicio/version detectada
```

**Interpretar Nmap siempre con los scripts:** un puerto "open" no es un hallazgo; `80/tcp http nginx 1.18.0` con banner y ruta de login sí lo es. Usar `-sC` (default scripts) o scripts concretos: `http-title`, `http-headers`, `http-enum`, `ssl-cert`, `vuln` con cuidado.

## 4. Flujo Web App Estándar

```bash
# Fingerprints + subs + URLs vivas
whatweb -v https://target.tld
subfinder -d target.tld -silent -all | tee $BASE/scans/subs.txt
httpx -l $BASE/scans/subs.txt -status-code -title -tech-detect \
  -o $BASE/scans/live.txt   2>/dev/null || httpx ... (si no está: curl -sI en bucle)

# Contenido: dos herramientas para reducir falsos negativos
ffuf -u https://target.tld/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt \
  -mc 200,301,302,403 -fc 404 -t 50 -o $BASE/scans/ffuf.json -of json
feroxbuster -u https://target.tld -w /usr/share/wordlists/dirb/common.txt \
  -t 40 -x php,html,txt,js,git -q -o $BASE/scans/ferox.txt

# Parámetros ocultos
arjun -u https://target.tld/api/search -m GET,POST -o $BASE/scans/params.json

# Inyección (solo con auth del usuario confirmada)
sqlmap -u "https://target.tld/item?id=1" --batch --level 3 --risk 2 --technique BEUSTQ
```

Para payloads, deteccion y reporte por clase de vulnerabilidad (XSS, IDOR, SSRF, JWT, XXE, SSTI, CSRF...): `references/owasp-web.md`. Para el playbook secuencial con curl (fingerprint→CVE→rutas→secrets→rate-limit→bypass→inyeccion): `references/web-audit-curl.md`, y sus scripts listos en `scripts/`.

## 5. Flujo Active Directory (resumen — detalle en references/active-directory.md)

```bash
# Recon inicial pasivo-activo (credenciales de dominio si ya las tienes; si no: atacar sin cred)
netexec ldap 10.10.10.10 --sam --no-pass            # listar usuarios sin clave (si habilitado)
bloodhound-python -u 'user' -p 'pass' -d corp.local -dc dc01.corp.local -ns 10.10.10.10 -c All \
  -zip $BASE/scans/bh_$(date +%Y%m%d).zip

# Attack paths a comprobar en orden de esfuerzo:
#  AS-REP roasting → Kerberoast → ADCS ESC1/ESC8 → relays → delegación → DCSync
```

## 6. Credenciales y Hashes

```bash
# Identificar tipo de hash ANTES de crackear (modo -m correcto o el crack no sirve):
hashid NT/LM/...  # o consultar https://openwall.info/wiki/john/hash-identifier
hashcat -m 1000  ntlm.txt    /usr/share/wordlists/rockyou.txt           # NT
hashcat -m 0     md5.txt     /usr/share/wordlists/rockyou.txt           # MD5
hashcat -m 18200 asrep.txt   /usr/share/wordlists/rockyou.txt           # Kerberos AS-REP etype 23
hashcat -m 13100 kerb.txt    /usr/share/wordlists/rockyou.txt           # Kerberos TGS-REP etype 23 (Kerberoast)
hashcat -m 19900 ccache.txt  /usr/share/wordlists/rockyou.txt           # Kerberos ccache (TGT)
hashcat -m 22000 wifi.pcapng passlist.txt                               # WPA-PBKDF2
john --wordlist=/usr/share/wordlists/rockyou.txt --format=NT hashes.txt  # alternativa john
hashcat --show -m 1000 ntlm.txt                                         # ver cracks ya hechos
```

**Antes de crackear, preguntar:** ¿rule-based/custom attack con contexto del objetivo rinde más que rockyou? En AD real, siempre generar wordlist corporativa (§1) — la mayoría de "Password2026!" no está en rockyou.

---

## 7. OPSEC — Minimizar Ruido Cuando el Engagement lo Pide

- Fuerza bruta: `--delay`, `thread` bajos, cuentas de "barrido" de bajo impacto (1 password × N usuarios, no N passwords × 1 usuario → evita lockout).
- Escaneos: `-T2`, `-sT` vs `-sS`, rangos de puertos lógicos (no -p- en horario pico), rotar IPs de salida si es cloud propio.
- Payloads: nunca `powershell -enc` plano sobre el alambre; usar canales de la herramienta (SMB/WinRM de netexec) antes que listeners ruidosos.
- Antes de acciones con riesgo (lockout de cuentas, exploits DoS-prone, escritura en producción): **avisar al usuario y confirmar**.
- Limpieza: al cerrar engagement, listar artefactos dejados (cuentas creadas, shares, scheduled tasks, listeners) para que el cliente los borre.

## 8. Sesiones Largas — tmux SIEMPRE

```bash
tmux new -s scan -d && tmux send-keys -t scan 'sudo nmap -p- ...' Enter
tmux attach -t scan        # scans/brute force que duran horas NUNCA en la shell suelta del agente
```

## 9. Informe Final — Plantilla Obligatoria

Al cerrar una sesión de pentest, generar `~/pentest/<target>/report/report.md`:

```markdown
# Informe de Pentesting — <TARGET>
**Fecha:** | **Alcance:** | **Metodología:** PTES + OWASP | **Autor:** <agente/usuario>

## 1. Resumen ejecutivo (sin tecnicismos, para dirección)
Riesgo global: Critical/High/Medium/Low. 3-5 bullets del impacto negocio.

## 2. Hallazgos
Para CADA hallazgo:
- **Nombre** | Severidad CVSS (Critical ≥9, High 7-8.9, Medium 4-6.9, Low 0.1-3.9)
- **Descripción y evidencia**: archivo concreto de scans/evidence + comando de verificación
- **Impacto real** (no teórico: "permite lectura de toda la base de clientes")
- **Reproducción paso a paso** (comandos exactos)
- **Remediación** concreta, con quick win y solución de fondo

## 3. Attack path narrado
Timeline: qué cred/access abrió qué puerta hasta dónde se llegó.

## 4. Anexos
Inventario de activos, hash/creds encontradas (loot), IoCs dejados para limpieza.
```

Sin evidencia adjunta (archivo + comando reproducible) un hallazgo NO se incluye en el informe.

---

## 10. Índice de Referencias y Scripts

### references/

| Archivo | Contenido | Cuándo leerlo |
|---|---|---|
| `references/active-directory.md` | netexec, bloodhound, certipy, bloodyAD, coercer, pypykatz, dploot, minikerberos, masky, msldap, attack paths AD | Dominio Windows, AD, Kerberos, DC |
| `references/web-pentesting.md` | nuclei, ffuf, feroxbuster, arjun, subfinder, sqlmap, hydra, NSE web | Cualquier objetivo HTTP/HTTPS |
| `references/web-audit-curl.md` | Playbook secuencial de auditoria web con curl: fingerprint→CVE→rutas→secretos→rate-limit→credenciales default→bypass de acceso→inyecciones→reporte | Auditoria web activa paso a paso |
| `references/owasp-web.md` | A01-A10: payloads, deteccion y severidades por clase (SQLi, XSS, SSRF, XXE, SSTI, JWT, IDOR, CSRF, uploads, smuggling) | Al explotar/REPORTAR una vulnerabilidad web concreta |
| `references/curl-http.md` | Catalogo de curl para pentesting: TLS, auth, timing (-w), cookies, HTTP/2-3, trazas, pivoting | requests HTTP avanzadas o medicion de respuestas |
| `references/browser-playwright.md` | Playwright CLI para ofensiva: storage/cookies, tracing de APIs del SPA, DOM XSS, mocks de authZ, sesiones reutilizables | Aplicaciones JS/SPA donde curl no ve el runtime |
| `references/network-recon.md` | nmap a fondo, nping, tcpdump, dig/mdig/delv, netcat, responder, SNMP | Red, infraestructura, servicios |
| `references/exploit-postex.md` | metasploit, msfvenom, searchsploit, linpeas/winpeas, escalada Linux/Windows, pivoting, limpieza | Shell inicial o acceso comprometido |
| `references/escalation-lateral.md` | BUCLE recursivo: control remoto de hosts, escalada SYSTEM/root, loot de credenciales, matriz credencial→acceso, pivoting, dominio total, criterios de parada | Tras CUALQUIER acceso: escalar, controlar, moverse |
| `references/pentesting-modes.md` | Mapas por modo: wireless, mobile, IoT/OT, cloud, red team (ATT&CK), social engineering, AD tecnico | Engagement que sale de web/infra clasica |
| `references/utilidades-kali.md` | apt/metapaquetes, wordlists, proxychains, mkpasswd, tmux, postgres/msfdb, loot seguro | Setup del entorno o falta de herramienta |

### scripts/ (bash nativo de Kali — `chmod +x`; stdout o `security/evidence/` relativo al cwd)

| Script | Que hace |
|---|---|
| `fingerprint-scan.sh <url>` | Versiones de servidor/framework (base para busqueda de CVEs) |
| `cve-lookup.sh "<producto>" [version]` | Busca CVEs en NVD + CISA KEV con salida legible |
| `route-scan.sh <url>` | Rutas sensibles (`scripts/paths/common-sensitive-paths.txt`: .git, .env, actuator, backups...) |
| `cors-test.sh <url>` | 7 origenes de prueba contra la configuracion CORS |
| `rate-limit-test.sh <url> [n] [metodo] [data]` | Rafaga controlada + headers de limitacion + bypasses |
| `endpoint-authz-check.sh <base_url> [token] < endpoints.txt` | Verifica que endpoints con auth debida la exijan (A01/BOLA) |
| `git-secret-audit.sh` | Secretos en repo: tracking, historial, gitleaks, frontend |
| `linux-audit.sh [dir]` | Hardening audit de un Linux propio (cuentas, SUID, cron, red, rootkits) |
| `linux-intrusion-triage.sh` | Triaje de intrusion en Linux (solo lectura, 12 pasos) |
