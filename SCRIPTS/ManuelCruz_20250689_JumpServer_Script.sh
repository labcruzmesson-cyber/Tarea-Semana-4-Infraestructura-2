cat << 'EOF' > setup_jump_server.sh
#!/bin/bash
set -e

echo "=========================================="
echo " CONFIGURANDO RED: JUMP SERVER (port2)    "
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
        - 10.25.68.130/29
      gateway4: 10.25.68.129
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
NET
netplan apply

echo "=========================================="
echo " INSTALANDO DEPENDENCIAS Y GUACAMOLE      "
echo "=========================================="

apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y \
    guacamole tomcat9 tomcat9-admin libguac-client-rdp0 libguac-client-ssh0 \
    libguac-client-vnc0 guacd net-tools curl

# Enlazar la aplicación Guacamole a Tomcat
ln -sf /var/lib/guacamole/guacamole.war /var/lib/tomcat9/webapps/

# Crear directorio de configuración de Guacamole
mkdir -p /etc/guacamole

# 2. Configurar guacamole.properties
cat << 'PROP' > /etc/guacamole/guacamole.properties
guacd-hostname: localhost
guacd-port: 4822
user-mapping: /etc/guacamole/user-mapping.xml
auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
PROP

# Enlazar configuración a Tomcat
mkdir -p /usr/share/tomcat9/.guacamole
ln -sf /etc/guacamole/guacamole.properties /usr/share/tomcat9/.guacamole/

echo "=========================================="
echo " CONFIGURANDO USUARIOS Y PERMISOS         "
echo "=========================================="

# 3. user-mapping.xml: Restricciones de usr_caja vs usr_admin
cat << 'XML' > /etc/guacamole/user-mapping.xml
<user-mapping>
    <!-- USUARIO SIN PRIVILEGIOS: Solo accede a la Web de Caja -->
    <authorize username="usr_caja" password="123">
        <connection name="Sistema de Caja (Web)">
            <protocol>rdp</protocol>
            <param name="hostname">10.25.68.138</param>
            <param name="port">3389</param>
            <param name="remote-app">||caja_web</param>
            <!-- O mapeo HTTP vía navegador integrado -->
        </connection>
    </authorize>

    <!-- USUARIO CON PRIVILEGIOS: Web, SSH y RDP completo -->
    <authorize username="usr_admin" password="123">
        <connection name="Sistema de Caja (Web)">
            <protocol>rdp</protocol>
            <param name="hostname">10.25.68.138</param>
            <param name="port">3389</param>
        </connection>
        
        <connection name="Web Server (Consola SSH - PuTTY)">
            <protocol>ssh</protocol>
            <param name="hostname">10.25.68.138</param>
            <param name="port">22</param>
            <param name="username">admin_user</param>
            <param name="password">123</param>
        </connection>

        <connection name="Web Server (Escritorio RDP)">
            <protocol>rdp</protocol>
            <param name="hostname">10.25.68.138</param>
            <param name="port">3389</param>
            <param name="username">admin_user</param>
            <param name="password">123</param>
            <param name="ignore-cert">true</param>
        </connection>
    </authorize>
</user-mapping>
XML

chmod 600 /etc/guacamole/user-mapping.xml
chown -R tomcat:tomcat /etc/guacamole

echo "=========================================="
echo " REINICIANDO SERVICIOS                    "
echo "=========================================="

systemctl restart guacd
systemctl restart tomcat9
systemctl enable guacd tomcat9

echo "Jump Server configurado exitosamente en http://10.25.68.130:8080/guacamole/"
EOF

chmod +x setup_jump_server.sh
sudo ./setup_jump_server.sh