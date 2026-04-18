#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "Erro: .env não encontrado. Copie o .env.example:"
  echo "  cp .env.example .env"
  exit 1
fi

source "$SCRIPT_DIR/.env"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION="$AWS_REGION"

ACTION="${1:-status}"

case "$ACTION" in
  start)
    echo "Ligando servidor..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --output text
    echo "Aguardando ficar online..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
    echo "Servidor online! Conecte em: $IP:25565"
    ;;
  stop)
    echo "Desligando servidor..."
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --output text
    echo "Servidor desligado."
    ;;
  status)
    STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query "Reservations[0].Instances[0].State.Name" --output text)
    IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
    echo "Estado: $STATE"
    if [ "$IP" != "None" ] && [ "$STATE" = "running" ]; then
      echo "IP: $IP:25565"
    fi
    ;;
  *)
    echo "Uso: $0 {start|stop|status}"
    exit 1
    ;;
esac
