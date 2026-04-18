#!/bin/bash
set -euo pipefail

MC_DIR="/opt/minecraft"
MC_USER="minecraft"

# Instalar Java 25 (requisito do Minecraft latest)
dnf install -y java-25-amazon-corretto-headless aws-cli

# Criar usuário e diretório
useradd -r -m -d "$MC_DIR" -s /bin/bash "$MC_USER"
mkdir -p "$MC_DIR"

# Baixar Minecraft Server com Fabric
MANIFEST_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"
LATEST_VERSION=$(curl -s "$MANIFEST_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['latest']['release'])")

FABRIC_INSTALLER_URL="https://meta.fabricmc.net/v2/versions/installer"
FABRIC_INSTALLER=$(curl -s "$FABRIC_INSTALLER_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['url'])")

curl -o "$MC_DIR/fabric-installer.jar" "$FABRIC_INSTALLER"
cd "$MC_DIR"
java -jar fabric-installer.jar server -mcversion "$LATEST_VERSION" -downloadMinecraft
rm -f fabric-installer.jar

mkdir -p "$MC_DIR/mods"

# Aceitar EULA
echo "eula=true" > "$MC_DIR/eula.txt"

# Configurar server.properties
cat > "$MC_DIR/server.properties" <<'PROPS'
server-port=25565
max-players=8
online-mode=true
difficulty=hard
gamemode=survival
motd=Um servidor Minecraft na AWS!
view-distance=10
white-list=false
PROPS

# Ajustar permissões
chown -R "$MC_USER":"$MC_USER" "$MC_DIR"

# Criar systemd service
cat > /etc/systemd/system/minecraft.service <<SERVICE
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=$MC_USER
WorkingDirectory=$MC_DIR
ExecStart=/usr/bin/java -Xmx1536M -Xms1024M -jar fabric-server-launch.jar nogui
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Iniciar serviço
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft

# Configurar backup diário às 4h da manhã
cat > /usr/local/bin/minecraft-backup.sh <<'BACKUP'
#!/bin/bash
set -euo pipefail

MC_DIR="/opt/minecraft"
BUCKET="${bucket_name}"
BACKUP_FILE="/tmp/world-backup-$(date +%Y%m%d).tar.gz"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

tar -czf "$BACKUP_FILE" -C "$MC_DIR" world
aws s3 cp "$BACKUP_FILE" "s3://$BUCKET/world-backup-$(date +%Y%m%d).tar.gz" --region "$REGION"
rm -f "$BACKUP_FILE"

echo "Backup concluído: s3://$BUCKET/world-backup-$(date +%Y%m%d).tar.gz"
BACKUP

chmod +x /usr/local/bin/minecraft-backup.sh
echo "0 4 * * * root /usr/local/bin/minecraft-backup.sh >> /var/log/minecraft-backup.log 2>&1" > /etc/cron.d/minecraft-backup

# Configurar auto-shutdown por inatividade (verifica a cada 5 min, desliga após 15 min sem jogadores)
cat > /usr/local/bin/auto-shutdown.sh <<'SHUTDOWN'
#!/bin/bash
set -euo pipefail

COUNTER_FILE="/tmp/minecraft-idle-count"
MAX_IDLE=3
MC_PORT=25565

PLAYERS=$(python3 -c "
import socket, struct, json

def ping(host='127.0.0.1', port=$MC_PORT):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect((host, port))
        data = b'\x00\x00'
        host_bytes = host.encode('utf-8')
        data += bytes([len(host_bytes)]) + host_bytes
        data += struct.pack('>H', port)
        data += b'\x01'
        s.send(bytes([len(data)]) + data)
        s.send(b'\x01\x00')
        buf = b''
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            buf += chunk
            if len(buf) > 5:
                break
        s.close()
        i = 0
        result = 0
        while True:
            b = buf[i]
            result |= (b & 0x7F) << (7 * i)
            i += 1
            if not (b & 0x80):
                break
        buf = buf[i:]
        i = 0
        while True:
            b = buf[i]
            i += 1
            if not (b & 0x80):
                break
        buf = buf[i:]
        i = 0
        str_len = 0
        while True:
            b = buf[i]
            str_len |= (b & 0x7F) << (7 * i)
            i += 1
            if not (b & 0x80):
                break
        buf = buf[i:]
        json_str = buf[:str_len].decode('utf-8')
        data = json.loads(json_str)
        return data['players']['online']
    except Exception:
        return -1

print(ping())
" 2>/dev/null)

if [ "$PLAYERS" = "-1" ]; then
  echo "$(date): Server não respondeu, ignorando check"
  exit 0
fi

echo "$(date): $PLAYERS jogadores online"

if [ "$PLAYERS" = "0" ]; then
  CURRENT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
  CURRENT=$((CURRENT + 1))
  echo "$CURRENT" > "$COUNTER_FILE"
  echo "$(date): Idle count: $CURRENT/$MAX_IDLE"

  if [ "$CURRENT" -ge "$MAX_IDLE" ]; then
    echo "$(date): Servidor inativo por $((CURRENT * 5)) minutos. Desligando..."
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
    rm -f "$COUNTER_FILE"
  fi
else
  echo "0" > "$COUNTER_FILE"
fi
SHUTDOWN

chmod +x /usr/local/bin/auto-shutdown.sh
echo "*/5 * * * * root /usr/local/bin/auto-shutdown.sh >> /var/log/auto-shutdown.log 2>&1" > /etc/cron.d/auto-shutdown
