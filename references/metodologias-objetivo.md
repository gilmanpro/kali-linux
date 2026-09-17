# Metodologías y Formas Diferentes de Llegar al Objetivo

> Complemento al flujo PTES de SKILL.md §2. Aquí: los MARCOS de trabajo existentes y, sobre todo, cómo razonar caminos alternativos cuando el vector principal falla. "Siempre hay un camino; cambia de vector, no de objetivo."

## 1. Marcos de trabajo (frameworks) según tipo de engagement

| Marco | Qué organiza | Cuándo usarlo |
|---|---|---|
| **PTES** (7 fases) | El ciclo: recon → escaneo → expl → post-ex → reporte | Pentest de infraestructura genérico (default de esta skill) |
| **OWASP WSTG** | Checklist de pruebas web ordenada por fase (config, identity, input validation...) | Pentest web exhaustivo y reportable |
| **OWASP API Top 10** | Las 10 clases de fallo de APIs | Objetivos API-first (REST/GraphQL/gRPC) |
| **MITRE ATT&CK** | Tácticas/técnicas/subtécnicas del adversario real | Red team: medir detección, no solo explotar. Mapa cada acción a una técnica (T1xxx) en el informe |
| **NIST SP 800-115** | Proceso formal: planning → discovery → attack → reporting | Cliente corporativo que exige marco normativo |
| **OSSTMM** | Auditoría por canales (network, human, physical, wireless) | Auditorías con componente físico/humano |
| **CSCP / CVSS** | Scoring y priorización de hallazgos | Al redactar severidades del informe (SKILL.md §9) |

## 2. Modelos de test según información disponible

- **Black box**: solo el target público (dominio/IP). Máximo realismo, máximo recon. Prioriza OSINT + superficie expuesta. Herramientas: subfinder/amass/nmap/nuclei.
- **Gray box**: con credenciales de usuario normal (o un acceso bajo). El más rentable: salta el 80% del recon y permite probar escalada de privilegios horizontales/verticales (IDOR, BOLA, token abuse).
- **White box**: con código/fuentes/arquitectura. Ataca primero lógica de negocio y secrets (`git-secret-audit.sh`, code review con `@lector`); luego confirma en runtime.
- **Assumed breach**: "el atacante YA está dentro". Empieza directo en discovery/credential access lateral (equivalente a saltar a SKILL.md bucle de `escalation-lateral.md`). Típico para validar segmentación y detección.
- **Red team vs pentest**: pentest = TODO el inventario de vulnerabilidades (ruido aceptado). Red team = UN objetivo narrado ("llegar al payroll del DC sin que el SOC lo vea") — low-and-slow, OPSEC estricta (SKILL.md §7), mides la detección.

## 3. Objetivo primero (goal-driven): razonar desde el final

Al recibir un objetivo ("conseguir Domain Admin", "leer la base de clientes"), NO empezar escaneando. Primero:

1. **Definir el premio**: ¿qué activo concreto? (secreto, base de datos, DC, cuenta).
2. **Invertir el camino**: preguntar qué credenciales/accesos dan ese premio → lista de caminos posibles.
3. **Priorizar cada camino** por: probabilidad × costo (tiempo) × ruido (detección) × riesgo (caída del servicio).
4. **Ejecutar el mejor, keeping fallbacks vivos**: cada fallo alimenta el siguiente camino con info nueva (un puerto cerrado filtrado ya dice que hay firewall con reglas específicas).

Ejemplo (objetivo = Domain Admin):
```
caminos: DCSync con creds robadas > ADCS ESC1 > relay a LDAP (mitm6+ntlmrelayx) >
Kerberoast+crack de svc > AS-REP > golden ticket (necesita krbtgt) > phishing a admin (SET/gophish) >
pass-the-hash via RDP (xfreerdp + restricted admin)
ordenar por evidencia del entorno: ¿hay ADCS? → certipy. ¿IPv6 activo? → mitm6. ¿SPN con pwd débil? → kerberoast.
```

## 4. Matriz de vectores de acceso inicial (cuando no tienes nada)

Elegir en este orden salvo que la evidencia del recon diga lo contrario:

| Vector | Señal para usarlo | Herramientas | Referencia |
|---|---|---|---|
| **CVE conocido + exploit público** | nmap/whatweb detecta versión vulnerable | searchsploit, metasploit, nuclei (verifica), kevin* | exploit-postex.md |
| **Exposición accidental** | rutas `.git/.env/backup/actuator/s3`, secretos en JS | route-scan.sh, git-secret-audit.sh, photon | web-audit-curl.md |
| **Credenciales débiles/reuso** | login expuesto, SPR+NTLM, same password | hydra/netexec, `netexec ... --no-pass`, password-spraying con bopscrk | active-directory.md |
| **Inyección directa** | parámetros en URLs/APIs | sqlmap (BEUSTQ), commix, sstimap, crlfuzz | owasp-web.md |
| **Error de autorización** | IDs secuenciales, JWT sin firma, multi-tenant | endpoint-authz-check.sh, JWT tooling | owasp-web.md |
| **SSRF como puente interno** | cualquier fetch de URL server-side | SSRF a metadatos cloud (169.254.169.254) / gopher / rebrow | owasp-web.md |
| **MITM de red local** | LAN con IPv6/LLMNR vivos | mitm6 + ntlmrelayx, responder | active-directory.md |
| **Física/social (autorizado)** | perímetro físico o SE en alcance | SET, gophish, evilginx2, USB drops | pentesting-modes.md §7 |

## 5. Cuando el vector falla: reglas de pivoteo mental

- **WAF bloquea payload** → no insistas con mutaciones al azar: codificar (unicode/ doble/ case), cambiar verbos/transporte (HTTP/2, chunked, smuggling), buscar el MISMO bug en otro endpoint, o saltar el WAF por SSRF/otro canal interno. Registrar bypasses en owasp-web.md.
- **Fuerza bruta → lockout** → pasar a password spraying (1 pwd × N usuarios) o wordlist corporativa con contexto (cewl + bopscrk del dominio).
- **Puerto filtrado** ≠ cerrado: probar otros paths (pivot desde host ya controlado con ligolo/chisel/sshuttle), IPv6, o el servicio desde otra IP de salida.
- **Sin expl para la versión** → degradar a ataque de configuración: defaults, credenciales, infoleaks, downgrade TLS, servicios internos sin auth (redis, docker.sock, actuator).
- **Todo falla** → volver al inicio con la información nueva (un banner de login distinto, un user existente vía timing) — el ciclo completo: enumerar → explotar → lootear → re-priorizar. Ver bucle en escalation-lateral.md.

## 6. Estilos operativos (adaptar al engagement)

| Estilo | Cuándo | Characteristics |
|---|---|---|
| **Blitz automatizado** | Perímetro grande, ventana corta | nuclei + autorecon + ffuf masivos; solo confirmar hallazgos altos manualmente |
| **Manual profundo** | Objetivo único de alto valor (API crítica, admin panel) | Burp/ZAP a mano, lógica de negocio, cadena de encadenamiento de bugs bajos → uno crítico |
| **Low-and-slow (red team)** | SOC activo, objetivo de sigilo | delay alto en todo, sin -p- completo, solo técnicas ATT&CK con LOLBins, canales C2 propios (DNS/HTTPS) |
| **Credential-first** | Hay dominio AD o muchas apps login | no explotar: robar y reutilizar (responder, kerberoast, spraying). El 90% de breaches reales = credenciales |
| **Chain-builder** | Ningún critical aislado | combinar mediums: SSRF→redis→RCE, open redirect→OAuth token, XXE→out-of-band LLMNR, infoleak→S3→creds→escalada |

## 7. Checkpoint de decisión rápida

```
¿Tengo ya algún acceso (shell/cred/token)? → escalation-lateral.md (bucle)
¿Objetivo web/API? → web-audit-curl.md + owasp-web.md; si SPA → browser-playwright.md
¿Infra/red? → network-recon.md; si Windows/LAN → active-directory.md
¿Nada claro? → recon OSINT completo (kali-tools-catalog.md §1) → nmap §3 SKILL.md → matriz §4 arriba
¿Atascado >3 intentos? → cambiar de vector (reglas §5), no insistir
```
