# Pentesting de Frontend con Navegador Automatizado (Playwright CLI)

Donde curl ve solo HTTP, el navegador ve la aplicación real: DOM, JS ejecutado, storage,
red del SPA, consola y sesiones. Referencia autocontenida; dudas de comandos → `playwright-cli --help`.

## 0. Instalacion en Kali

```bash
npm install -g @playwright/cli@latest        # o usar npx directamente
npx playwright install chromium              # binarios del navegador
# Alternativa python (ya presente en Kali): pip install playwright && playwright install chromium
```

## 1. Comandos esenciales para pentesting

### Sesiones
```bash
playwright-cli -s=nombre open <url>          # sesion aislada (cookies/storage propios)
playwright-cli open --browser=chrome|firefox|webkit|msedge
playwright-cli open --device="iPhone 15" --mobile     # emulacion dispositivo
playwright-cli attach --cdp=chrome           # conectar al navegador real (autorizado)
playwright-cli list / close / close-all / kill-all    # gestion de sesiones
```

### Navegacion e interaccion
| Comando | Uso en pentest |
|---|---|
| `open <url>` / `goto <url>` / `reload` | navegar |
| `snapshot` / `snapshot --filename=ui.yaml` / `find <text>` | mapear el DOM/UI |
| `click <ref|css|locator>` | hacer click: `e7`, `#btn`, `getByRole('button',{name:'X'})` |
| `fill <ref> <text>` / `type <text>` / `press <key>` | escribir en inputs (payloads) |
| `eval "el => el.outerHTML" e7` / `eval "() => document.title"` | inspeccionar atributos y DOM |

### Storage y sesion
| Comando | Uso en pentest |
|---|---|
| `cookie-list` / `cookie-get <name>` / `cookie-set <n> <v> [--httpOnly --secure]` | ver/editar cookies (flags, session switching) |
| `localstorage-list` / `localstorage-get <k>` / `localstorage-set <k> <v>` | cazar JWT/tokens/API keys en localStorage |
| `sessionstorage-list` / `-get` / `-set` | igual en sessionStorage |
| `state-save <file>.json` / `state-load <file>.json` | capturar/restaurar estado completo (cookies+storage) para tests autenticados |
| `run-code` con `page.evaluate` | leer IndexedDB, clipboard, scripts cargados |

### Red y consola
| Comando | Uso en pentest |
|---|---|
| `tracing-start` / `tracing-stop` | trace con DOM+red+consola+timing (`traces/trace-*.network` revela endpoints del SPA) |
| `video-start` / `video-stop` | evidencia en video |
| `console [level]` | mensajes de consola (errores, tokens, depuracion) |
| `requests` | listar requests recientes |
| `route "**/api/x" --status=404` / `--body='{...}'` / `--remove-header=cookie` | mockear/modificar/bloquear respuestas (authZ en cliente) |
| `route-list` / `unroute [patron]` | gestionar mocks activos |

## 2. Mapa objetivo frontend → comando

| Objetivo | Comando / patron |
|---|---|
| Mapear estructura DOM y UI | `open`, `snapshot`, `find <text>` |
| Atributos ocultos (ids, `data-*`, names de forms) | `eval "el => el.outerHTML" e7` |
| **Descubrir superficie de API del SPA** | `tracing-start` → recorrer pantallas → `tracing-stop`; examinar `traces/*.network` |
| Secretos en storage (JWT, tokens, API keys) | `cookie-list`, `localstorage-list`, `sessionstorage-list`, `state-save` + grep del JSON |
| Verificar flags de cookies (httpOnly/secure/sameSite) | `cookie-list` (incluye flags) |
| DOM XSS / ejecucion en cliente | `open` con payload en URL + `run-code` para verificar reflejo/ejecucion en sinks (`innerHTML`, `eval`, `location`) |
| Bypass de validacion client-side | `fill`/`type` con payloads que el JS bloquea; verificar en el trace si el server los acepta |
| AuthZ en cliente (BOLA/IDOR desde UI) | sesion A login + `state-save`; sesion B `cookie-set` con cookie de A → navegar a recursos de A |
| Sesion autenticada reutilizable | login una vez → `state-save auth.json` → `state-load auth.json` en cada test |
| Rate limit / lockout via UI | loop de `fill`+`click` con POCOS intentos; observar 429/lockout |
| Mockear respuesta del server (confianza en cliente) | `route "**/api/me" --body='{"role":"admin"}'` → la UI muestra opciones admin? |
| Versiones de librerias JS | `run-code` → `page.evaluate(() => [...document.scripts].map(s=>s.src))` + grep versiones |
| Request sin token CSRF | `run-code` con `page.evaluate` + fetch sin token, comparar respuesta |
| Evidencia profesional (DOM+red+consola) | `tracing-start` → reproducir → `tracing-stop` (o video); guardar en `$BASE/evidence/` |

## 3. Kit de supervivencia (flujos listos)

```bash
# 1. Sesion autenticada reutilizable
playwright-cli open https://app.example.com/login
playwright-cli snapshot
playwright-cli fill e1 "user@example.com" && playwright-cli fill e2 "password"
playwright-cli click e3
playwright-cli state-save auth.json          # cookies + localStorage + sessionStorage

# 2. Caza de secretos en storage
playwright-cli state-load auth.json
playwright-cli cookie-list
playwright-cli localstorage-list
playwright-cli run-code "async page => page.evaluate(() => Object.entries(localStorage))"

# 3. DOM XSS: inyectar en un sink y verificar ejecucion
playwright-cli open "https://app.example.com/search?q=<img src=x onerror=alert(1)>"
playwright-cli run-code "async page => page.evaluate(() => ({reflected: document.body.innerHTML.includes('onerror'), executed: !!document.querySelector('img[onerror]')}))"

# 4. Mapear APIs del SPA durante el flujo
playwright-cli tracing-start
playwright-cli open https://app.example.com/dashboard   # recorrer las pantallas
playwright-cli tracing-stop
# revisar traces/trace-*.network para extraer endpoint+payload+respuesta

# 5. AuthZ en cliente: mockear admin y ver si la UI confia
playwright-cli route "**/api/me" --body='{"user":"x","role":"admin"}'
playwright-cli open https://app.example.com/
playwright-cli snapshot   # aparecen opciones de admin? -> decision de acceso en cliente
playwright-cli unroute "**/api/me"
```

## 4. Reglas de uso

1. **Solo targets autorizados:** Playwright ejecuta JS real del target con nuestra sesion.
2. Los payloads de DOM XSS se ejecutan en NUESTRO navegador controlado: verificar reflejo/ejecucion y documentar; nunca danar el target.
3. Respetar rate limits: loops de login con pocos intentos; parar ante 429/lockout.
4. Los archivos `state-save` contienen cookies/JWT reales: no commitear, no adjuntar al informe, borrar al cerrar.
5. Evidencia primero: todo hallazgo se respalda con trace o video en `$BASE/evidence/`.
6. Cerrar sesiones al terminar: `playwright-cli close-all` (o `kill-all` si quedan procesos colgados).
7. Logica avanzada (multi-tab, iframes, downloads, WebSocket, drag&drop) → `run-code` con la API estandar (`page`, `context`).
