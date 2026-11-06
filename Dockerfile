FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalar versiones antiguas de Ubuntu 16.04 (EOL):
# Apache 2.4.18, Samba 4.3.11, vsftpd 3.0.3 (2016), PHP 7.0
RUN apt-get update && apt-get install -y \
        apache2 \
        php7.0 \
        libapache2-mod-php7.0 \
        vsftpd \
        samba \
        smbclient \
        iputils-ping \
        curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crear estructura de directorios vulnerables y archivos confidenciales (banderas/flags para la demo)
RUN mkdir -p /var/run/vsftpd/empty /srv/samba/publico /var/ftp/pub /var/www/html/backups /var/www/html/uploads \
    && chmod 755 /var/ftp \
    && chmod 777 /var/ftp/pub /srv/samba/publico /var/www/html/uploads \
    && useradd -m -s /bin/bash usuario \
    && echo "usuario:123456" | chpasswd \
    && (echo "123456"; echo "123456") | smbpasswd -s -a usuario \
    && echo "CONFIDENCIAL SMB: Respaldo de claves internas - Token_SMB_Vulnerable_2016" > /srv/samba/publico/secretos_smb.txt \
    && echo "CONFIDENCIAL FTP: Acceso base de datos produccion - DB_PASS=admin123" > /var/ftp/pub/credenciales_ftp.txt \
    && echo "RESPALDO HTTP EXPUESTO: listado de directorio habilitado - usuario:123456" > /var/www/html/backups/usuarios_backup.txt \
    && rm -f /var/www/html/index.html

# Vincular carpeta de uploads para demostrar escalada entre FTP/SMB -> Ejecucion Remota en HTTP
RUN ln -s /var/www/html/uploads /srv/samba/publico/web_uploads \
    && ln -s /var/www/html/uploads /var/ftp/pub/web_uploads

# Configurar Apache vulnerable (Exponer version exacta ServerTokens Full y permitir Directory Listing)
RUN sed -i 's/^ServerTokens .*/ServerTokens Full/' /etc/apache2/conf-enabled/security.conf \
    && sed -i 's/^ServerSignature .*/ServerSignature On/' /etc/apache2/conf-enabled/security.conf

COPY src/index.php /var/www/html/index.php
COPY vsftpd.conf /etc/vsftpd.conf
COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh /etc/vsftpd.conf /etc/samba/smb.conf /var/www/html/index.php \
    && chmod +x /entrypoint.sh

EXPOSE 80 21 139 445 21100-21110

ENTRYPOINT ["/entrypoint.sh"]
