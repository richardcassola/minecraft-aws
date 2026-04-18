# Minecraft Server na AWS

Servidor Minecraft Java na AWS usando Terraform, com backup automático pro S3 e auto-shutdown por inatividade.

## Arquitetura

- **EC2** (t3.small) com Amazon Linux 2023 e Java 25 (Corretto)
- **Elastic IP** para IP fixo entre stop/start
- **Security Group** com SSH restrito por IP e porta 25565 aberta
- **S3** para backup diário do world (retenção de 7 dias)
- **IAM Role** na instância para backup S3 e auto-shutdown
- **AWS Budget** com alerta por email ao atingir 80% e 100% do limite mensal
- **Auto-shutdown** que desliga a instância após 15 min sem jogadores

## Estrutura

```
├── main.tf                          # providers + module
├── variables.tf                     # variáveis de entrada
├── outputs.tf                       # outputs expostos
├── modules/
│   └── minecraft/
│       ├── main.tf                  # data source (AMI)
│       ├── ec2.tf                   # key pair + instância
│       ├── network.tf               # security group + Elastic IP
│       ├── iam.tf                   # role + policies + instance profile
│       ├── s3.tf                    # bucket backup + lifecycle
│       ├── budget.tf                # alerta de custo
│       ├── variables.tf             # variáveis do módulo
│       └── outputs.tf               # outputs do módulo
└── scripts/
    ├── setup.sh                     # user data (bootstrap da instância)
    └── server.sh                    # CLI local (start/stop/status)
```

## Pre-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configurado
- Um user IAM com as permissões listadas abaixo

## Setup

1. Configure as credenciais AWS:
   ```bash
   aws configure
   ```

2. Crie um arquivo `.env` para o script local (opcional):
   ```bash
   AWS_ACCESS_KEY_ID=<sua-key>
   AWS_SECRET_ACCESS_KEY=<sua-secret>
   AWS_REGION=us-east-1
   INSTANCE_ID=<preenchido após terraform apply>
   ```

3. Aplique o Terraform:
   ```bash
   terraform init
   terraform apply -var 'alert_email=seu@email.com'
   ```

4. Conecte via SSH:
   ```bash
   ssh -i minecraft-key.pem ec2-user@<ELASTIC_IP>
   ```

5. Conecte no Minecraft: `<ELASTIC_IP>:25565`

## Gerenciamento do servidor

```bash
# Via script local
bash scripts/server.sh start
bash scripts/server.sh stop
bash scripts/server.sh status

# Via AWS CLI (outputs do terraform)
terraform output start_server
terraform output stop_server
```

## Variáveis

| Variável | Descrição | Default |
|---|---|---|
| `region` | Região AWS | `us-east-1` |
| `instance_type` | Tipo da instância EC2 | `t3.small` |
| `server_name` | Nome tag do servidor | `minecraft-server` |
| `allowed_ssh_ips` | CIDRs permitidos para SSH | `["179.125.152.41/32", "191.193.227.47/32"]` |
| `alert_email` | Email para alertas de custo | (obrigatório) |

## Permissões IAM do user Terraform

O user IAM que executa o Terraform (ex: `terraform-minecraft`) precisa das seguintes inline policies configuradas manualmente no Console AWS:

### MinecraftIAMManagement

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:TagRole",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::<ACCOUNT_ID>:role/minecraft-server-*",
        "arn:aws:iam::<ACCOUNT_ID>:instance-profile/minecraft-server-*"
      ]
    }
  ]
}
```

### MinecraftS3Management

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:PutBucketTagging",
        "s3:GetBucketTagging",
        "s3:PutLifecycleConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:ListBucket",
        "s3:GetBucketAcl"
      ],
      "Resource": "arn:aws:s3:::minecraft-server-backups-*"
    }
  ]
}
```

### MinecraftBudgetManagement

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "budgets:ModifyBudget",
        "budgets:ViewBudget",
        "budgets:ListTagsForResource"
      ],
      "Resource": "arn:aws:budgets::<ACCOUNT_ID>:budget/minecraft-server-*"
    }
  ]
}
```

> Substitua `<ACCOUNT_ID>` pelo ID da sua conta AWS.

Além dessas, o user precisa de permissões para EC2, VPC, EIP e Key Pair, que normalmente já estão cobertas pela policy gerenciada `AmazonEC2FullAccess` ou equivalente.
