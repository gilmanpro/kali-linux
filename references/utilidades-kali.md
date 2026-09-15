# Utilidades de Kali para el Pentester

## Gestion de herramientas

```bash
sudo apt update
apt search nmap | head                       # buscar paquetes
sudo apt install -y <paquete>                # instalar tool que falta
command-not-found <tool>                     # Kali sugiere el paquete exacto
apt-file find <archivo>                      # a que paquete pertenece (requiere apt-file update)
pipx install <tool>                          # tools python modernas (netexec, certipy...) en entornos aislados
sudo apt install -y kali-tools-<categoria>   # metapaquetes por categoria:
# kali-tools-top10 | kali-tools-default | active-directory-recon | exploitation | forensic |
# hardware | information-gathering | mantain-access | password-audit | reverse-engineering |
# sniff-response | vulnerabilities | web-application
nxcdb                                        # BD interna de netexec (cred/host cross-sesion)
```

## Wordlists — donde vive todo

```bash
/usr/share/wordlists/                       # raiz oficial de Kali
├── rockyou.txt(.gz)                        # passwords general (14M)
├── dirb/common.txt                         # dirs web clasico
├── dirbuster/                              # directory-list-2.3-medium (mas profundo)
├── fasttrack.txt                           # passwords cortos + servicios
└── seclists/                               # SecLists completo (el que mas se usa):
    ├── Discovery/DNS/subdomains-top1million-110000.txt
    ├── Discovery/Web-Content/raft-medium-directories.txt / common.txt
    ├── Fuzzing/anonymizer, XSS, SQLi...    # payloads
    ├── Passwords/                            # per-region, per-default creds
    └── Username/                             # nombres corporativos
# Si /usr/share/wordlists/seclists no existe:
sudo apt install -y seclists   # o git clone --depth 1 https://github.com/danielmiessler/SecLists
```

## Utilidades de sobremesa del dia a dia

```bash
tmux                                     # sesiones persistentes SIEMPRE (scans de horas)
screen -r                                # alternativa
mkpasswd -m sha-512                      # generar hash para /etc/shadow (crear backdoor user?)
openssl rand -hex 32 / base64 / xxd / rev
md5sum/sha256sum/b2sum                   # integrity de loot
jq                                       # parsear JSON de ffuf/nuclei/arjun
xmllint                                  # formatear respuestas XML/SOAP
xdelta3/patch/diff                       # comparar outputs (baseline vs post-test)
tree -L 2                                # mapa de loot/scans
exiftool archivo.jpg                     # metadata de archivos (OSINT y uploads)
binwalk image.png                        # stegano/containers en objetivos CTF
strings, xxd, hexdump, file              # inspeccion de binarios/capturas
curl -v / --resolve / --cert / -c -b     # el navegador del pentester (catalogo completo: references/curl-http.md)
git -C $BASE init                        # versionar notes/informe (NUNCA loot/ ni creds/)
```

## Red local de Kali — configuracion previa

```bash
ip a; ip r                               # interfaz VM (NAT 192.168.x, host-only, adaptador del lab)
sudo systemctl start apache2             # servidor local para payloads/Powershell one-liners
# Servir loot/ payloads:
python3 -m http.server 80 -d $BASE/evidence    # target descarga: certutil/urlprise/curl
sudo /etc/init.d/postgresql start        # base para metasploit/msfconsole
sudo msfdb init                          # init BD de msf
ufw status verbose                       # el firewall de Kali NO debe bloquear tus listeners
```

## proxychains / rotacion de salida

```bash
# /etc/proxychains4.conf → [ProxyList] → socks4/5 segun el tunnel activo
proxychains4 nmap -sT -Pn -p445 10.10.20.5
proxychains4 python3 psexec.py ...
# En red propia con salida por VPN/WireGuard no hace falta: ip r muestra la ruta.
```

## Cron y automatizacion de scans largos

```bash
crontab -e                               # re-scan diario, nuclei semanal, etc.
# Pattern scan-largo robusto (no se cae si el agente/terminal muere):
tmux new -s fullscan -d 'sudo nmap -p- -sV -T3 --open 10.10.10.0/24 -oA $BASE/scans/full_$(date +%F) ; tee done'
```

## Almacenamiento seguro de loot

```bash
chmod 700 $BASE/loot                     # credenciales/hashes: permisos estrictos
# NO: git add loot/, no pegar hashes en chats, no subir a servicios cloud.
# Al cerrar engagement: cifrar o borrar segun politica del cliente:
tar czf - loot/ | gpg -c -o $TARGET-loot.tar.gz.gpg
```

## Snippets utiles que ahorran tiempo

```bash
# Extraer todas las URLs de un nmap XML/normal para pasarlas a nuclei:
grep -oE 'https?://[^ ]+' scans/nmap_full.gnmap | sort -u > scans/urls.txt
# Convertir "80/tcp open http nginx" de nmap en objetivo para searchsploit:
nmap -sV ... -oG - | awk '/Up$/{print $2,$6}'      # o usar `nmap2db`/scripts del repo
# Contar status codes de ffuf json para priorizar:
jq -r '.results[].status' ffuf_dirs.json | sort | uniq -c | sort -rn
# Hashcat: modos frecuentes → NT=1000 MD5=0 SHA1=100 AS-REP=18200 TGS=13100
#          NETNTLMv2=5600 WPA=22000 JWT=16500 | lista completa: hashcat --help | grep -i kerber
```
