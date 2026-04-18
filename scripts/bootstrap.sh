#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

IAM_USER="terraform-minecraft"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Bootstrap: criando user IAM para o Terraform ==="

# Verificar se aws cli está configurado
if ! aws sts get-caller-identity &>/dev/null; then
  echo "Erro: AWS CLI não configurado. Rode 'aws configure' com credenciais admin primeiro."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo "Conta AWS: $ACCOUNT_ID"

# Criar user se não existir
if aws iam get-user --user-name "$IAM_USER" &>/dev/null; then
  echo "User '$IAM_USER' já existe, pulando criação..."
else
  echo "Criando user '$IAM_USER'..."
  aws iam create-user --user-name "$IAM_USER"
fi

# Inline policies
echo "Configurando policies..."

aws iam put-user-policy --user-name "$IAM_USER" --policy-name MinecraftIAMManagement --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Allow\",
    \"Action\": [
      \"iam:CreateRole\", \"iam:DeleteRole\", \"iam:GetRole\",
      \"iam:PutRolePolicy\", \"iam:GetRolePolicy\", \"iam:DeleteRolePolicy\",
      \"iam:ListRolePolicies\", \"iam:ListAttachedRolePolicies\",
      \"iam:CreateInstanceProfile\", \"iam:DeleteInstanceProfile\", \"iam:GetInstanceProfile\",
      \"iam:AddRoleToInstanceProfile\", \"iam:RemoveRoleFromInstanceProfile\",
      \"iam:PassRole\", \"iam:TagRole\", \"iam:ListInstanceProfilesForRole\",
      \"iam:AttachRolePolicy\", \"iam:DetachRolePolicy\"
    ],
    \"Resource\": [
      \"arn:aws:iam::${ACCOUNT_ID}:role/minecraft-server-*\",
      \"arn:aws:iam::${ACCOUNT_ID}:instance-profile/minecraft-server-*\"
    ]
  }]
}"

aws iam put-user-policy --user-name "$IAM_USER" --policy-name MinecraftS3Management --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:CreateBucket", "s3:DeleteBucket",
      "s3:GetBucketPolicy", "s3:PutBucketPolicy",
      "s3:PutBucketTagging", "s3:GetBucketTagging",
      "s3:PutLifecycleConfiguration", "s3:GetLifecycleConfiguration",
      "s3:ListBucket", "s3:GetBucketAcl",
      "s3:GetBucketCors", "s3:PutBucketCors",
      "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketVersioning", "s3:GetBucketWebsite",
      "s3:GetBucketLogging", "s3:GetBucketObjectLockConfiguration",
      "s3:GetReplicationConfiguration", "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment"
    ],
    "Resource": "arn:aws:s3:::minecraft-server-*"
  }]
}'

aws iam put-user-policy --user-name "$IAM_USER" --policy-name MinecraftBudgetManagement --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Allow\",
    \"Action\": [
      \"budgets:ModifyBudget\", \"budgets:ViewBudget\", \"budgets:ListTagsForResource\"
    ],
    \"Resource\": \"arn:aws:budgets::${ACCOUNT_ID}:budget/minecraft-server-*\"
  }]
}"

# Managed policies
echo "Anexando managed policies..."
aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess

# Deletar access keys antigas (limite de 2 por user)
EXISTING_KEYS=$(aws iam list-access-keys --user-name "$IAM_USER" --query "AccessKeyMetadata[].AccessKeyId" --output text 2>/dev/null || true)
for KEY in $EXISTING_KEYS; do
  echo "Deletando access key antiga: $KEY"
  aws iam delete-access-key --user-name "$IAM_USER" --access-key-id "$KEY"
done

# Gerar access keys
echo "Gerando access keys..."
KEYS=$(aws iam create-access-key --user-name "$IAM_USER" --output text --query "AccessKey.[AccessKeyId,SecretAccessKey]")
ACCESS_KEY=$(echo "$KEYS" | cut -f1)
SECRET_KEY=$(echo "$KEYS" | cut -f2)

# Gerar .env
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

ALERT_EMAIL="${TF_VAR_alert_email:-${EMAIL:-}}"
if [ -z "$ALERT_EMAIL" ]; then
  read -rp "Email para alertas de custo: " ALERT_EMAIL
fi

cat > "$SCRIPT_DIR/.env" <<ENV
AWS_ACCESS_KEY_ID=$ACCESS_KEY
AWS_SECRET_ACCESS_KEY=$SECRET_KEY
AWS_REGION=$REGION
TF_VAR_alert_email=$ALERT_EMAIL
ENV
chmod 600 "$SCRIPT_DIR/.env"

echo ""
echo "=== Bootstrap concluído! ==="
echo "User: $IAM_USER"
echo "Arquivo .env gerado com as credenciais."
echo ""
echo "Próximo passo: make deploy"
