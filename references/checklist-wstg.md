# Checklist OWASP WSTG v4.2 — Auditoría Web Exhaustiva

> Estructura oficial de la WSTG v4.2 (https://wstg.owasp.org/v4.2/) para no dejar ninguna categoría sin tocar. Cada ítem: test que hacer → herramienta de Kali. Al reportar, cita el ID WSTG junto al CVSS (facilita al cliente rastrear la prueba). Flujo secuencial operativo en `web-audit-curl.md`; payloads por clase en `owasp-web.md`.

## 0x04 — Information Gathering (WSTG-INFO)
- [ ] Subs/activos: `subfinder`, `amass`, `assetfinder` (0x04-001)
- [ ] DNS: `dnsrecon`, `massdns` bracket, zona transfer `dig axfr` (0x04-002/003)
- [ ] Topología de app: `waybackurls`, `gospider`, sitemap XML (0x04-004/005)
- [ ] Tech stack: `whatweb`, headers `Server`/`X-Powered-By`, cookies names (0x04-006/007)
- [ ] Usernames/emails en app: `cewl`, `photon` (0x04-008/009/010)
- [ ] Origen IPs/WAF: `wafw00f`, `lbd`, CDN check (0x04-011/012/013)

## 0x05 — Configuration & Deployment (WSTG-CONFIG)
- [ ] `route-scan.sh` → `.git`, `.env`, `.svn`, backups, `web.config`, actuator (0x05-001..007)
- [ ] CORS: `cors-test.sh` (0x05-011)
- [ ] HTTP methods: `curl -X OPTIONS` + TRACE (0x05-001)
- [ ] Cabeceras de seguridad (CSP, HSTS, X-Frame): `curl -sI` + `securityheaders.com` manual (0x05-008/009/010)
- [ ] SSL/TLS: `sslscan`, `sslyze` — versiones, suites, HSTS preload (0x05-012..014)
- [ ] Exceso de info en errores/headers: `nikto`, búsqueda de stack traces con payloads inválidos (0x05-015)

## 0x06/0x07/0x08 — Identity, Authentication, Session
- [ ] Enum usernames: timing/401-vs-404 en login, mensajes "user unknown" (0x06-002/003)
- [ ] Lockout + 2FA bypass: `rate-limit-test.sh`; probar 000000/123456, reuso de token, falta de binding (0x07-001..010)
- [ ] Credenciales default: `hydra`, `netexec` si app corporativa, foros de doc del producto (0x07-024)
- [ ] Tokens: entropía, expiración, reuso tras logout, fijación (0x08-001..023)
- [ ] Cookies: flags HttpOnly/Secure/SameSite, dominio comillas sueltas (0x06-004)

## 0x09/0x10/0x11 — Authorization, Data Validation, Errors
- [ ] IDOR/BOLA: `endpoint-authz-check.sh`, secuencia ID, cambio de propiedad entre cuentas (0x09-001..006)
- [ ] Forced browsing y method tampering (0x09-002/003)
- [ ] SQLi (todos los tipos) `sqlmap` + manual confirm; NoSQL; ORM (0x10-004)
- [ ] XSS (reflected/stored/DOM): `dalfox*`, XSStrike* + manual con Burp (0x10-008)
- [ ] SSRF: `interactsh`/collaborator OOB, gopher, cloud metadata (0x10-009 + playbook SSRF de owasp-web.md)
- [ ] XXE, SSTI (`sstimap`), LFI/RFI, Command Injection (`commix`), LDAP, NoSQL, CRLF (`crlfuzz`) (0x10-010..016)
- [ ] File uploads: extensión/MIME/magic bytes, polyglot, webshell path (0x10-010)
- [ ] HTTP Verb Tampering, HTTP Parameter Pollution, Request Smuggling (`request-smuggler*` manual con burp) (0x10-018..020)
- [ ] Deserialization: `phpggc`, `ysoserial*` si Java detectado (0x10-012)
- [ ] Stack traces / mensajes de error reveladores (0x11)

## 0x12 — Cryptography
- [ ] TLS config (ver CONFIG), padding oracle, weak random tokens, HTTP en rutas sensibles (0x12)

## 0x13 — Business Logic & 0x14 — Client-side
- [ ] Flujos multi-paso: saltar pasos, reordenar peticiones, race conditions (`turbo-intruder`/`errex*` en Burp, `arjun`) (0x13-001..004)
- [ ] DOM: `gospider --js-crawling` + búsqueda de sinks `innerHTML`/`postMessage`/`eval` en JS descargado (0x14-001..019)
- [ ] Clickjacking, CORS con credenciales, WebSocket sin auth, Client-side deserialization (0x14-007/008)
- [ ] XSS en referer/UA reflejado, cache poisoning (0x14-013)

## 0x15 — API Testing (WSTG-API)
- [ ] Descubrir spec: `/openapi.json`, `/swagger`, GraphQL introspection (`graphix*`/curl) (0x15-001)
- [ ] Auth en CADA endpoint (`endpoint-authz-check.sh`), JWT (alg none, HS/RS confusion, `jwt_tool*`) (0x15-002/003)
- [ ] BFLA/BOPLA, métodos por recurso (`OPTIONS`, PATCH), versioning (`/v1` vs `/internal`) (0x15-004)
- [ ] Mass assignment: añadir campos readonly al POST (0x15-005)
- [ ] Rate limit y resource exhaustion (0x15-006, `rate-limit-test.sh`)
- [ ] SSRF en webhooks/callbacks, GraphQL batching/depth abuse (0x15-008)

## Regla de cobertura
Marco la casilla solo si hubo TEST REAL con evidencia (comando+output). "No aplicable" se justifica. Lo no testeado aparece en el informe como *out of scope/no probado* — nunca se omite: es la diferencia entre informe WSTG-compliant y un escaneo de nuclei.
