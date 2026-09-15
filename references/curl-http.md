# curl para Pentesting HTTP — Referencia Autocontenida

El catálogo de opciones de curl relevante para pentesting está integrado aquí; no se
requiere ninguna herramienta ni guía externa. Combínalo con `references/web-audit-curl.md`
(playbook de procedimientos). Para dudas puntuales de sintaxis: `curl --help <categoría>` o `man curl`.

## 1. Catálogo esencial de opciones

### HTTP y datos
| Opción | Uso en pentest |
|---|---|
| `-X GET\|POST\|PUT\|PATCH\|DELETE\|OPTIONS\|TRACE` | probar verbos, bypass por método |
| `-d "k=v&k2=v2"` | POST urlencoded crudo |
| `--data-urlencode "k=<payload>"` | POST codificando el payload (inyecciones) |
| `--json '{"k":"v"}'` | POST JSON + Content-Type (NoSQLi, GraphQL, mass assignment) |
| `-F "name=@f.php;type=image/png"` / `-F "f=@x;filename=x.php"` | multipart con truco de extensión |
| `-H "Header: valor"` | header personalizado (repetible) |
| `-A "UA"` / `-e <referer>` | User-Agent / Referer (engaño de WAF, rotación) |
| `-i` / `-I` / `-D -` | headers+body / solo headers / headers a stdout |
| `--compressed` | pedir respuesta comprimida |

### Sesiones y cookies
| Opción | Uso en pentest |
|---|---|
| `-c jar.txt` / `-b jar.txt` | guardar / reenviar cookies (login multi-paso) |
| `-b "name=value"` | enviar cookie a mano (session fixation, switching de usuario) |

### Autenticación
| Opción | Uso en pentest |
|---|---|
| `-u user:pass` + `--basic` | Basic auth |
| `--digest` / `--ntlm` / `--negotiate` | Digest / NTLM / SPNEGO-Kerberos |
| `--oauth2-bearer <token>` | JWT/Bearer (o `-H "Authorization: Bearer ..."`) |
| `--aws-sigv4 "aws:amz:region:servicio" -u access:secret` | firmas AWS SigV4 |

### TLS / SSL
| Opción | Uso en pentest |
|---|---|
| `-k` | deshabilitar verificación TLS (solo laboratorio/Burp; documentar el motivo) |
| `--cacert <file>` / `--capath <dir>` / `--ca-native` | CA custom / nativa |
| `-E cert.pem --key key.pem` | mTLS / certificado de cliente |
| `--tlsv1.0\|1.1\|1.2\|1.3` / `--tls-max <v>` / `--ciphers <suite>` | probar versiones y suites (downgrade) |
| `--cert-status` | verificación OCSP |

### Medición (`-w` variables de salida)
| Variable | Uso en pentest |
|---|---|
| `%{http_code}` | código de respuesta |
| `%{size_download}` | tamaño del body (baseline vs payload) |
| `%{time_total}` / `%{time_starttransfer}` | timing (blind SQLi, enum usuarios, timing attacks) |
| `%{remote_ip}` / `%{remote_port}` | IP/puerto real del server |
| `%{http_version}` | HTTP/1.1, 2 o 3 usado |
| `%{header_json}` | headers de respuesta en JSON |
| `%{url_effective}` | URL final tras redirects |

### Red y conexión
| Opción | Uso en pentest |
|---|---|
| `--resolve host:port:ip` | probar vhosts/Host header sin tocar DNS |
| `-H "Host: otro.dominio"` | Host header injection directa |
| `--connect-to h1:p1:h2:p2` | redirigir conexiones |
| `-x http://proxy:puerto` | Burp/ZAP (intercepción y evidencia) |
| `--socks5-hostname user:pass@host:1080` | pivoting por SOCKS |
| `-4` / `-6` / `--interface <if>` | forzar IPv4/IPv6 o interfaz de salida |
| `--rate N/s` / `--limit-rate <vel>` | controlar tasa (evitar DoS) |
| `--max-time N` / `--connect-timeout N` / `--retry N` | límites de tiempo y reintentos |

### URLs y encoding
| Opción | Uso en pentest |
|---|---|
| `-g` / `--globoff` | desactivar globbing de `{}[]` (URLs con caracteres raros) |
| `--path-as-is` | NO normalizar `..` (imprescindible en path traversal) |
| `--url-query "k=v"` | añadir a la query string |
| `--data-urlencode` | codificar payload (espacios, `&`, `#`, `'`) |

### HTTP/2-3 y debugging
| Opción | Uso en pentest |
|---|---|
| `--http1.1` / `--http2` / `--http2-prior-knowledge` / `--http3` | forzar protocolo (smuggling, confusión) |
| `-v` | verboso (headers + TLS + DNS) |
| `--trace-ascii <file>` / `--trace <file>` | evidencia completa (request+response) a archivo |
| `--trace-time` / `--trace-ids` | timestamps/IDs en el trace |

## 2. Mapa objetivo pentest → curl

| Objetivo | Flags / técnica |
|---|---|
| Medición de tiempos (blind SQLi, enum usuarios) | `-w "%{time_total} %{time_starttransfer}"` |
| Sesión persistente / login multi-paso | `-c jar.txt -b jar.txt` |
| Rotación contra rate-limit (verificación) | variar `-b`, `-H "X-Forwarded-For"`, `-A` por request |
| Probing de vhosts / Host header injection | `--resolve host:443:IP` o `-H "Host: otro.dominio"` |
| Tests TLS (versiones, ciphers, downgrade) | `--tlsv1.2`, `--tls-max`, `--ciphers` |
| mTLS / certificado de cliente | `-E client.pem --key key.pem` |
| Verbos HTTP peligrosos / bypass | `-X OPTIONS/PUT/PATCH/TRACE/DELETE` |
| Inyecciones en forms/query | `--data-urlencode "id=1' OR '1'='1"` |
| APIs JSON (NoSQLi, mass assignment, GraphQL) | `--json '{"user":{"$gt":""}}'` |
| Upload multipart con truco de extensión | `-F "file=@shell.php;type=image/png"` |
| Path traversal sin normalización | `--path-as-is` + `.%2e/%2e%2e/` |
| Autenticación Basic/Digest/NTLM/Negotiate | `-u user:pass` + `--basic`/`--digest`/`--ntlm`/`--negotiate` |
| OAuth2 / JWT | `--oauth2-bearer <token>` |
| Intercepción Burp/ZAP para evidencias | `-x http://127.0.0.1:8080 -k` |
| Pivoting por SOCKS | `--socks5-hostname user:pass@host:1080` |
| Controlar tasa (evitar DoS) | `--rate 5/s`, `--limit-rate 100k` |
| Cache poisoning / condicionales | `-z <fecha>`, `--etag-compare/--etag-save`, `If-None-Match` |
| HTTP/2 / h2c / HTTP/3 (smuggling) | `--http2`, `--http2-prior-knowledge`, `--http3`, `--http1.1` |
| Evidencia completa de un hallazgo | `--trace-ascii $BASE/evidence/hallazgo.txt` |

## 3. Kit de supervivencia (comandos listos)

```bash
# 1. Baseline con timing completo (toda auditoria usa esta estructura)
curl -s -o /dev/null -w "%{http_code}|%{size_download}|%{time_total}|%{remote_ip}\n" <url>

# 2. Sesión: login y reuso de cookies
curl -s -c jar.txt -X POST --data-urlencode "csrf=<token>" --data-urlencode "user=admin" \
  --data-urlencode "pass=x" <url>/login
curl -s -b jar.txt <url>/panel

# 3. Path traversal sin normalizacion (Apache/nginx misconfig)
curl --path-as-is -s "http://host/cgi-bin/.%2e/%2e%2e/%2e%2e/etc/passwd"

# 4. Inyeccion con encoding correcto
curl -s --data-urlencode "id=1' AND SLEEP(5)-- -" -w "\n%{time_total}s\n" <url>/api/items

# 5. Verificar bypass de proxy WAF (autorizado) e interceptar en Burp
curl -s -x http://127.0.0.1:8080 -k -H "X-Forwarded-For: 127.0.0.1" <url>/admin
```

## 4. Reglas de uso

1. Nunca `-k` en producción sin motivo documentado (laboratorio o interceptación Burp/ZAP).
2. `--path-as-is` solo para pruebas de path traversal.
3. `--data-urlencode`, no `-d`, con payloads inyectables: `-d` no codifica y los espacios/`&`/`#` rompen el payload.
4. Evidencia antes que velocidad: todo hallazgo se respalda con `--trace-ascii` o `-D evidencia.txt -o body.txt` en `$BASE/evidence/`.
5. Dudas de sintaxis → `curl --help all` / `man curl` en el propio sistema.
