#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

IAM_USER="terraform-minecraft"

echo "=== Teardown: removendo user IAM ==="

# Verificar se aws cli está configurado com credenciais admin
if ! aws sts get-caller-identity &>/dev/null; then
  echo "Erro: AWS CLI não configurado. Rode 'aws configure' com credenciais admin primeiro."
  exit 1
fi

if ! aws iam get-user --user-name "$IAM_USER" &>/dev/null; then
  echo "User '$IAM_USER' não encontrado. Nada a fazer."
  exit 0
fi

# Deletar access keys
KEYS=$(aws iam list-access-keys --user-name "$IAM_USER" --query "AccessKeyMetadata[].AccessKeyId" --output text 2>/dev/null || true)
for KEY in $KEYS; do
  echo "Deletando access key: $KEY"
  aws iam delete-access-key --user-name "$IAM_USER" --access-key-id "$KEY"
done

# Deletar inline policies
POLICIES=$(aws iam list-user-policies --user-name "$IAM_USER" --query "PolicyNames[]" --output text 2>/dev/null || true)
for POLICY in $POLICIES; do
  echo "Deletando inline policy: $POLICY"
  aws iam delete-user-policy --user-name "$IAM_USER" --policy-name "$POLICY"
done

# Detach managed policies
ATTACHED=$(aws iam list-attached-user-policies --user-name "$IAM_USER" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || true)
for ARN in $ATTACHED; do
  echo "Detaching managed policy: $ARN"
  aws iam detach-user-policy --user-name "$IAM_USER" --policy-arn "$ARN"
done

# Deletar user
echo "Deletando user '$IAM_USER'..."
aws iam delete-user --user-name "$IAM_USER"

# Limpar arquivos locais
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$SCRIPT_DIR/.terraform" "$SCRIPT_DIR/.terraform.lock.hcl" "$SCRIPT_DIR"/terraform.tfstate* "$SCRIPT_DIR/.env"

echo ""
echo "=== Teardown concluído! ==="
echo "User IAM e arquivos locais removidos."
