cat << 'EOF' > setup_web_server.sh
#!/bin/bash
set -e

echo "=========================================="
echo " CONFIGURANDO RED: WEB SERVER (port3)     "
echo "=========================================="

# 1. Configuración de Red estática (/29)
cat << 'NET' > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 10.25.68.138/29
      gateway4: 10.25.68.137
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
NET
netplan apply

echo "=========================================="
echo " INSTALANDO SERVICIOS (WEB, SSH, XRDP)    "
echo "=========================================="

apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y \
    nginx openssh-server xrdp xfce4 xfce4-goodies ssl-cert net-tools

# Configurar entorno de escritorio para XRDP
echo "xfce4-session" > /etc/skel/.xsession
adduser xrdp ssl-cert

echo "=========================================="
echo " CONFIGURANDO USUARIOS DEL SISTEMA        "
echo "=========================================="

# Usuario para la caja (sin permisos sudo)
useradd -m -s /bin/bash caja_user || true
echo "caja_user:123" | chpasswd
echo "xfce4-session" > /home/caja_user/.xsession
chown caja_user:caja_user /home/caja_user/.xsession

# Usuario Administrador (con sudo)
useradd -m -s /bin/bash admin_user || true
echo "admin_user:123" | chpasswd
usermod -aG sudo admin_user
echo "xfce4-session" > /home/admin_user/.xsession
chown admin_user:admin_user /home/admin_user/.xsession

echo "=========================================="
echo " DESPLEGANDO SISTEMA DE CAJA (HTTPS/443)  "
echo "=========================================="

# Certificado SSL autofirmado para HTTPS
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/caja.key \
    -out /etc/nginx/ssl/caja.crt \
    -subj "/C=DO/ST=DistritoNacional/L=SantoDomingo/O=Empresa/OU=Caja/CN=10.25.68.138"

# Interfaz visual de "Sistema de Caja"
cat << 'HTML' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Sistema de Facturación y Caja</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; background-color: #1e293b; color: #f8fafc; margin: 0; padding: 2rem; }
        .card { background-color: #334155; border-radius: 8px; padding: 2rem; max-width: 600px; margin: 2rem auto; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.5); }
        h1 { color: #38bdf8; margin-top: 0; }
        .status { display: inline-block; padding: 0.25rem 0.75rem; background: #16a34a; border-radius: 9999px; font-size: 0.875rem; font-weight: bold; }
        table { width: 100%; margin-top: 1.5rem; border-collapse: collapse; }
        th, td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #475569; }
        th { color: #94a3b8; }
        .btn { background: #0284c7; color: white; border: none; padding: 0.5rem 1rem; border-radius: 4px; cursor: pointer; margin-top: 1rem; }
    </style>
</head>
<body>
    <div class="card">
        <span class="status">SISTEMA ONLINE</span>
        <h1>Terminal Punto de Venta (TPV)</h1>
        <p>Servidor Web Interno: <strong>10.25.68.138</strong></p>
        <table>
            <tr><th>Módulo</th><th>Estado</th></tr>
            <tr><td>Cobro con Tarjeta</td><td>Operativo</td></tr>
            <tr><td>Facturación Electrónica</td><td>Conectado</td></tr>
            <tr><td>Arqueo de Caja</td><td>Habilitado</td></tr>
        </table>
        <button class="btn">Abrir Factura</button>
    </div>
</body>
</html>
HTML

# Configuración Nginx para HTTP y HTTPS
cat << 'NGINX' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    ssl_certificate /etc/nginx/ssl/caja.crt;
    ssl_certificate_key /etc/nginx/ssl/caja.key;

    root /var/www/html;
    index index.html;
    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

echo "=========================================="
echo " REINICIANDO Y HABILITANDO SERVICIOS      "
echo "=========================================="

systemctl restart nginx
systemctl restart ssh
systemctl restart xrdp
systemctl enable nginx ssh xrdp

echo "Web Server aprovisionado con éxito (HTTPS: 443, SSH: 22, RDP: 3389)"
EOF

chmod +x setup_web_server.sh
sudo ./setup_web_server.sh
