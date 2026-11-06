#!/bin/bash
set -e

echo "Iniciando Apache 2.4.18 (HTTP Vulnerable)..."
service apache2 start

echo "Iniciando vsftpd 3.0.3 (FTP Vulnerable)..."
/usr/sbin/vsftpd /etc/vsftpd.conf &

echo "Iniciando Samba 4.3.8 (SMBv1 Vulnerable)..."
exec /usr/sbin/smbd -F -S
