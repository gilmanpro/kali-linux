# kali-linux — Skill de Pentesting Ofensivo para Kali Linux

Skill autocontenida para agentes de IA (Opencode, Zed, Claude Code) que convierte una
máquina Kali Linux en un agente pentester profesional: metodología PTES, payloads OWASP,
Active Directory/Kerberos, escalada de privilegios con bucle recursivo de movimiento
lateral y reporte final.

## Uso

Copia la carpeta a la ubicación de skills de tu agente:

```bash
# Opencode
cp -r kali-linux ~/.config/opencode/skills/
# Zed / compatible
cp -r kali-linux ~/.agents/skills/
```

## Contenido

| Ruta | Que contiene |
|---|---|
| `SKILL.md` | Metodologia, flujos por fase, bucle escalada→loot→lateral, OPSEC, plantilla de informe |
| `references/active-directory.md` | netexec, bloodhound, certipy, bloodyAD, coercer, pypykatz, dploot, minikerberos, attack paths AD |
| `references/escalation-lateral.md` | Control remoto de hosts, escalada SYSTEM/root, loot de credenciales, matriz lateral, dominio total |
| `references/web-pentesting.md` | nuclei, ffuf, feroxbuster, arjun, subfinder, sqlmap, hydra |
| `references/web-audit-curl.md` | Playbook de auditoria web con curl: fingerprint→CVE→rutas→secretos→rate-limit→bypass→inyeccion |
| `references/owasp-web.md` | A01-A10: payloads, deteccion y severidades por clase |
| `references/curl-http.md` | curl ofensivo: TLS, auth, timing, cookies, HTTP/2-3, evidencias |
| `references/browser-playwright.md` | Testing de SPAs/frontend con navegador automatizado (Playwright CLI) |
| `references/network-recon.md` | nmap, nping, tcpdump, DNS, responder, SNMP |
| `references/exploit-postex.md` | metasploit, searchsploit, escalada inicial, pivoting, limpieza |
| `references/pentesting-modes.md` | Modos: wireless, mobile, IoT/OT, red team (ATT&CK), social engineering |
| `references/utilidades-kali.md` | apt, wordlists, proxychains, tmux, loot seguro |
| `scripts/` | 9 scripts bash listos (fingerprint, CVE lookup, rutas sensibles, CORS, rate-limit, authZ, secretos git, auditoria/triage Linux) |

## Requisitos

- Kali Linux (o distro con las herramientas; la skill indica como instalarlas con `apt`).
- Uso exclusivo en entornos con **autorización explícita** (pentests, CTFs, laboratorios propios).

## Licencia

MIT
