# Catálogo Completo de Herramientas de Kali Linux

> Fuente: https://www.kali.org/tools/ (ordenadas por las categorías/tácticas que usa Kali).
> Propósito: tener CONCIENCIA de que la herramienta existe — ante cualquier necesidad, buscar aquí antes de improvisar.
> `apt install kali-linux-<categoria>` instala packs: `kali-linux-headless`, `kali-tools-top100`, `kali-linux-large`, `kali-linux-full`, o por paquete individual `kali-<nombre>`.

## Índice rápido "necesidad → herramienta"

| Necesidad | Herramienta principal | Alternativas |
|---|---|---|
| Discover subs/activos | amass, subfinder | assetfinder, findomain, sublist3r, fierce, autorecon |
| Escaneo de puertos | nmap | masscan (rápido), unicornscan, rustscan*, zenmap (GUI) |
| OSINT sobre persona/empresa | spiderfoot, theHarvester | maltego, recon-ng, linkedin2username, sherlock, photon, emailharvester |
| DNS | dnsrecon, massdns | dnsmap, dnsenum, dnswalk, dnstracer, delv*, dig |
| Fuzzing de rutas web | ffuf, wfuzz | gobuster, dirb, dirbuster, dirsearch, feroxbuster, paros |
| Detección de tecnologías web | whatweb | wappalyzer*, wpscan, joomscan, droopescan* |
| Escaneo de vulns | nuclei, gvm (OpenVAS) | nikto, wapiti, skipfish, owasp-mantra, cat |
| Proxy interceptivo | burpsuite, zaproxy | caido, webscarab, paros, mitmproxy |
| Inyección SQL | sqlmap | sqlninja, jsql, sqlsus |
| SSTI / CRLF / inyecciones específicas | sstimap, crlfuzz, tinja (injection) | wcvs |
| Fuerza bruta servicios | hydra, medusa, ncrack | crackmapexec/netexec, crowbar, patator, legba, thc-pptp-bruter, sqldict |
| Cracking de hashes | hashcat, john | hashid/hash-identifier (tipo), rcrack (rainbow), johnny (GUI), ophcrack (LM), truecrack |
| Wordlists dirigidas | crunch, cewl, bopscrk | rsmangler, statsgen, twofi, maskgen, policygen, seclists |
| Robo de credenciales Windows | mimikatz (y pypykatz), rubeus | creddump7, samdump2, chntpw, netexec modules |
| AD enumeration | bloodhound-python, netexec | ldeep, bloodyAD*, azurehound, enum4linux-ng, ldap-domain-manager* |
| Exploitation framework | metasploit-framework | router-exploit-framework*, searchsploit + exploit local |
| Generar payloads | msfvenom | veil, shellter, donut (PE→shellcode), nishang/powersploit (PS), weewvely/webshells/phpggc |
| Post-explotación Linux | linpeas, pspy, unix-privesc-check | linux-exploit-suggester*, wsus exploitation*, lynis (defensa) |
| Post-explotación Windows | winpeas | PEASS, seatsafe*, watson*, sherlock* (privesc) |
| Accesos remotos / shell | msf console, netcat/ncat/socat | chisel (túneles), ligolo-ng, sshuttle, stunnel4, iodine (DNS), dnscat, ptunnel, pwnat, proxytunnel, udptunnel |
| C2 frameworks | metasploit, sliver*, havocs, koadic, powershell-empire (starkiller), armitage, villain | penelope, powercat |
| Exfiltración | goshs, raven, netcat | impacket-smbserver |
| Sniffing/MITM | bettercap, wireshark, tcpdump | dsniff, netsniff-ng, arpspoof, driftnet, xspy (keylogger X), ettercap |
| MitM AD | mitm6, responder | nbtscan, fakedns*, inveigh* |
| WiFi | aircrack-ng, wifite, airgeddon | reaver/pixiewps/wash (WPS), bully, cowpatty, eapmd5pass, fern-wifi-cracker, fluxion, wifiphisher, wifipumpkin3, wifi-honey, asleap, krack* |
| Bluetooth/RF | bettercap, bluelog, ubertooth-util | besside*, spooftooph, btscanner, blueranger, mfcuk/mfoc (NFC/Mifare), hackrf_info, gnuradio, gqrx, rfcat, chirp |
| VoIP | svcrack, enumiax, sipvicious (svmap/svwar/svreport) | sipp, sipsak, siproxy*, rtpbreak, voiphopper, protos-sip |
| Bases de datos | mysql, impacket-mssqlclient, oscanner, sidguess | tnscmd10g (Oracle), pgsql*, mongodb*, redis*, sqlitebrowser, mdb-sql |
| SMTP | swaks, smtp-user-enum | mxcheck |
| Cisco | cge.pl, cisco-ocs, cisco-torch, snmpenum* | copy-router-config.pl |
| Fuzzing genérico | afl-fuzz, sfuzz, generic_send_tcp/udp | bed, peach* |
| RE / binarios | ghidra, radare2/rizin/cutter | ollydbg (wine), edb, gdb+gef, apktool, jadx, jd-gui, bytecode-viewer, binwalk, pycdc*/uncompyle6 |
| Forense | autopsy (Sleuth Kit), foremost, photorec/testdisk | dc3dd/dcfldd (imaging), bulk_extractor, yara, ssdeep, chkrootkit/rkhunter/unhide, pdfid/pdf-parser, exiftool*, steghide/outguess/stegsnow (estego), vinetto, regripper, tsk suite |
| Reportes | dradis, faraday, cherrytree, witnessme | eyewitness, pipal, recordmydesktop, cutycapt, redeye, maltego CE |
| Laboratorios para practicar | dvwa-start, juice-shop-start | vulhub*, hacklab*, bWAPP* |
| Phishing | setoolkit (Social Engineer Toolkit), gophish | evilginx2 (Evilginx proxy), wifiphisher |
| WAF/IDS bypass | wafw00f (detección), firewalk | h8mail* (creds), frida (mobile bypass), genjûgo* |
| Utilidades del propio Kali | kali-tweaks, proxychains4, pwsh, shell-gpt, gemini-cli, hexstrike_server, arsenal-ng | code-oss (VS Code), snapper-gui |

\* = no viene en la página oficial pero se instala con apt/pip en Kali; validar con `which` antes.

---

## 1. RECONNAISSANCE (Reconocimiento)

### Host Information
`metagoofil` (metadatos de documentos públicos), `spiderfoot`/`spiderfoot-cli` (OSINT automatizado multi-fuente), `maltego` (grafos de entidades).

### Identity Information
`email2phonenumber`, `emailharvester`, `instaloader`, `linkedin2username`, `photon` (crawlea y extrae URLs/emails/creds del sitio), `sherlock` (usernames en redes), `tookie-osint`, `h8mail*`, `theHarvester` (emails, subs, IPs por fuentes públicas).

### Network Information
`amass` (subdomains + ASNs + screenshots), `autorecon` (multi-servicio automatizado nmap+nikto+...), `dmitry`, `legion`, `nmap`/`zenmap`, `unicornscan`.

### Network Information: DNS
`dnsmap`, `dnsrecon`, `dnsenum`, `massdns` (resolución masiva), `dnstracer`, `dnswalk`, `dig`/`mdig`/`delv` (core).

## 2. VULNERABILITY ANALYSIS (Vulnerabilidad)

### Vulnerability Scanners
`nmap` (NSE `vuln`), `CAT`, `gvm-start` (OpenVAS full scanner), `heartbleed`, `nikto` (servidores web), `wapiti`, `skipfish`, `nuclei` (templates YAML, community-driven), `subjack` (subdomain takeover).

### Web Vulnerability Scanners
`burpsuite` (proxy #1, Community/Pro), `caido`/`caido-cli` (proxy moderno), `zaproxy` (OWASP ZAP), `crlfuzz`, `davtest` (WebDAV), `joomscan`, `paros`, `skipfish`, `sstimap` (SSTI), `tinja`, `watobo`, `wcvs`, `webscarab`, `whatweb`, `wpscan`, `owasp-mantra-ff`.

## 3. WIRELESS & RF (Inalámbrico)

### Bluetooth
`bettercap`, `bluelog`, `bluesnarfer`, `btscanner`, `blueranger`, `fang`, `spooftooph`, `ubertooth-util`, `besside-ng*`.

### WiFi
`aircrack-ng` (suite capture/crack), `airgeddon` (orquestador), `kismet` (wardriving), `sparrow-wifi`, `wash` (WPS), `wifite2*`, `reaver`/`bully` (WPS PIN), `pixiewps`, `cowpatty`, `eapmd5pass`, `fern-wifi-cracker`, `freeradius` (802.1X), `wifi-honey` (honeypot), `wifiphisher`, `fluxion`, `wifipumpkin3`.

### NFC/RFID
`mfcuk`, `mfoc`, `mfterm`, `mifare-classic-format`, `nfc-list`, `nfc-mfclassic`, `rfidcat*`.

### Radio Frequency
`hackrf_info`, `gnuradio`, `gqrx`, `chirp`, `rfcat`, `photon`, `universal-radio-heaven*`.

## 4. Web Application Hacking Tools

### Fuzzers & Discovery
`arjun` (parámetros ocultos), `dirb`, `dirbuster`, `dirsearch`, `feroxbuster` (recursivo), `ffuf` (el estándar, `-w FUZZ`), `finalrecon`, `findomain`, `gobuster`, `gospider` (JS crawling), `lbd` (balanceo de carga), `parsero`, `recon-ng`, `subfinder`, `sublist3r`, `uniscan-gui`, `urlcrazy` (typosquatting), `uro` (filtra ruido), `wfuzz`, `wpprobe`, `assetfinder`.

### SQL Injection
`sqlmap` (el rey: BEUSTQ, tamper, --os-shell), `sqlninja` (MSSQL), `sqlsus`, `jsql`.

### Utilities
`commix` (command injection), `jboss-linux`/`jboss-win` (JBoss), `wafw00f` (detección de WAF).

## 5. PASSWORD ATTACKING (incluida en las tácticas ATT&CK de Kali)

### Brute Force
`hydra`/`hydra-gtk` (50+ protocolos), `medusa`, `ncrack`, `crackmapexec`/`netexec` (SMB/WinRM/MSSQL/LDAP), `crowbar`, `legba`, `patator`, `thc-pptp-bruter`, `sqldict`, `CAT`, `firewalk`.

### Cracking
`hashcat` (GPU, -m por tipo, rules, masks, attack modes 0-11), `john` + `johnny` (GUI), `hashid` + `hash-identifier`, `rcrack`/`rcracki_mt` (rainbow), `fcrackzip`, `cmospwd`, `crackle` (BT), `sipcrack`, `sucrack`, `ophcrack` (LM), `truecrack`, `zip2john`/`7z2john` (extractores john).

### Wordlists & Profiling
`cewl` (genera de una web), `crunch` (masks), `bopscrk` (probabilísticas), `rsmangler` (mutaciones), `statsgen`, `twofi`, `policygen`, `maskgen`, `wordlists` (paquete), `seclists`.

### Sniffing de credenciales
`responder` (LLMNR/NBT-NS/mDNS poison), `netsniff-ng`, `dsniff` (ssf/firesheep/...), `ferret-sidejack`, `hamster-sidejack`, `xspy`.

## 6. EXPLOITATION / MITRE ATT&CK en Kali

Kali organiza su menú por tácticas ATT&CK — cada táctica tiene herramientas mapeadas. Ver SKILL.md §2 (PTES) para el flujo. Resumen por táctica:

| Táctica ATT&CK | Herramientas clave en Kali |
|---|---|
| Initial Access | metasploit, setoolkit, dns-rebind, gophish, sqlmap/commix, evilgrade |
| Execution | metasploit, armitage, beef-xss, nishang, powersploit, xsser |
| Persistence | weevely, webacoo, webshells, laudanum, phpggc, backdoor-factory, cymothoa |
| Privilege Escalation | linpeas, winpeas, PEASS, unix-privesc-check, bloodyAD, lynis, metasploit |
| Defense Evasion | donut, msfvenom, shellter, veil, exe2hex, macchanger, outguess/steghide (estego), ccrypt/padbuster, passing-the-hash, fragrouter (IDS) |
| Credential Access | mimikatz, rubeus, creddump7, samdump2, chntpw, netexec, hashcat/john, trufflehog/gitxray (secrets), kerberoast, responder, aircrack suite |
| Discovery | netexec, enum4linux-ng, bloodhound, ldeep, pspy, masscan, sslscan/sslyze, onesixtyone/snmp-check, smbmap, swaks, fierce/fping/hping3/p0f, wafw00f/firewalk |
| Lateral Movement | netexec/crackmapexec, evil-winrm(-py), impacket-* (psexec/smbexec/wmiexec/atsvc), xfreerdp3, rdesktop, pass-the-hash, rubeus, mimikatz |
| Collection | httrack (mirror), ettercap, evilginx2, mitmproxy, mitm6, fluxion/wifipumpkin3 (evil twin), sslsniff/sslsplit, fiked |
| Command & Control | metasploit, sliver*, havoc, koadic, empire/starkiller, villain, chisel, ligolo-ng, dns2tcp, dnscat, iodine, proxychains4, stunnel4, sshuttle, ptunnel, udptunnel, pwnat, socat/ncat/dbd |
| Exfiltration | impacket-smbserver, goshs, raven, netcat |
| Impact | slowhttptest, thc-ssl-dos, t50, siege, goldeneye, iaxflood, mdk3, dhcpig, rtpflood, inviteflood (DO NOT sin autorización expresa — SKILL.md §0) |

## 7. FORENSICS (Forense)

- **Imaging**: `dd_rescue`, `dc3dd`, `dcfldd`, `guymager`, `affcat`, `ewfacquire`, `safecopy`
- **Carving**: `foremost`, `photorec`/`testdisk`, `scalpel`, `magicrescue`, `extundelete`/`ext3grep`/`ext4magic`, `recoverjpeg`, `recoverdm`, `rifiuti2`, `unrar`-based*, `myrescue`
- **Sleuth Kit**: `autopsy`, `fls`, `icat`, `mactime`, `mmls`, `istat`, `sigfind`, `sorter`, `hfind`
- **Suite**: `binwalk` (+`binwalk3`), `bulk_extractor`, `yara`, `ssdeep`, `chkrootkit`, `rkhunter`, `unhide`, `xplico`, `pdfid`+`pdf-parser`, `reglookup`/`regripper`/`pasco` (registro), `readpst`, `vinetto`, `grokevt-*`, `hashdeep`, `missidentify`, `hexwalk`, `undbx`, `scrounge-ntfs`, `galleta`
- **Esteganografía**: `steghide`, `outguess`, `stegsnow`, `stegosuite`, `ccrypt`

## 8. SERVICES & OTHER (Servicios del sistema)

### Reporting Tools
`cherrytree` (bitácora arbol), `dradis-start` (gestor de hallazgos colaborativo), `faraday-start` (multiusuario, ingiere scans), `maltego`, `obsidian`, `pipal`, `recordmydesktop`, `redeye-start`, `cutycapt` (screenshots de URLs a evidencia), `eyewitness`, `witnessme`.

### Laboratories
`dvwa-start` (Damn Vulnerable Web App), `juice-shop-start` (OWASP Juice Shop). Perfectos para practicar sin riesgo.

### System Services (arrancables)
`beef-xss`, `defectdojo` (gestión de vulns CI/CD), `gophish` (campañas phishing), `gvm` (scanner), `portspoof` (confunde escáneres), `starkiller` (GUI Empire), `thehive` (CSIRT), `xplico`.

### Herramientas transversales del propio Kali
`kali-tweaks` (config del SO), `arsenal-ng` (catálogo interactivo de comandos por herramienta), `code-oss`, `pwsh` (PowerShell para Nishang/PowerSploit), `snapper-gui`, `shell-gpt`/`gemini-cli` (asistente), `hexstrike_server` (suite automatizada), `tailscale` (red privada para pivoting lab).

---

## 9. Cómo buscar herramienta para cualquier tarea

```bash
# 1. ¿Existe como paquete? (nombre aproximado)
apt search <keyword> | grep -i <keyword>
apt-cache showpkg <pkg> | head -20

# 2. Menús de Kali
ls /usr/share/applications/kali/  # .desktop por categoría
dpkg -l | grep ^ii | grep kali-   # qué hay instalado

# 3. Documentación oficial de cada herramienta
#    https://www.kali.org/tools/<nombre-herramienta>/  (ej: /tools/netexec/)

# 4. searchsploit cubre 45k+ exploits locales del Exploit Database
searchsploit --update && searchsploit <producto>
```

**Regla:** antes de escribir un script propio para una tarea ofensiva, comprobar aquí y con `apt search` si ya hay herramienta hecha. 600+ herramientas cubren casi todo; lo custom solo para lo que no existe.
