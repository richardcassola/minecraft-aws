# Minecraft Server na AWS

Servidor Minecraft Java (Fabric) na AWS usando Terraform, com backup automático pro S3, auto-shutdown por inatividade e acesso via SSM.

## Stack

- **Cloud:** AWS (EC2, S3, IAM, SSM, Budgets)
- **IaC:** Terraform
- **OS:** Amazon Linux 2023
- **Runtime:** Java 25 (Amazon Corretto)
- **Servidor:** Minecraft Java Edition com Fabric mod loader
- **Shell scripts:** Bash (bootstrap da instância + CLI local)

## Arquitetura

- **EC2** (t3.small) com Amazon Linux 2023 e Java 25 (Corretto)
- **Fabric** mod loader instalado automaticamente com a versão mais recente do Minecraft
- **Elastic IP** para IP fixo entre stop/start
- **Security Group** com porta 25565 aberta (sem SSH — acesso via SSM)
- **SSM Session Manager** para acesso seguro ao servidor sem porta SSH exposta
- **S3** para backup diário do world (retenção de 7 dias, criptografado com AES256)
- **IAM Role** na instância para backup S3, auto-shutdown e SSM
- **AWS Budget** ($20/mês) com alertas por email a 50%, 75% e 100% do limite
- **Auto-shutdown** que desliga a instância após 15 min sem jogadores
- **Whitelist** de jogadores configurável via Terraform

## Estrutura

```
├── main.tf                          # providers + module
├── variables.tf                     # variáveis de entrada
├── outputs.tf                       # outputs expostos
├── terraform.tfvars.example         # exemplo de valores para as variáveis
├── modules/
│   └── minecraft/
│       ├── main.tf                  # data source (AMI)
│       ├── ec2.tf                   # instância EC2
│       ├── network.tf               # security group + Elastic IP
│       ├── iam.tf                   # role + policies + instance profile + SSM
│       ├── s3.tf                    # bucket backup + lifecycle + encryption
│       ├── budget.tf                # alerta de custo
│       ├── variables.tf             # variáveis do módulo
│       └── outputs.tf               # outputs do módulo
├── scripts/
│   ├── setup.sh                     # user data (bootstrap da instância)
│   └── server.sh                    # CLI local (start/stop/status)
└── mods/
    └── README.md                    # guia de instalação de mods Fabric
```

## Pre-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configurado
- [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) para acesso via SSM
- Um user IAM com as permissões listadas abaixo

## Setup

1. Configure as credenciais AWS:
   ```bash
   aws configure
   ```

2. Copie o exemplo de variáveis e preencha com seus valores:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Crie um arquivo `.env` para o script local (opcional):
   ```bash
   AWS_ACCESS_KEY_ID=<sua-key>
   AWS_SECRET_ACCESS_KEY=<sua-secret>
   AWS_REGION=us-east-1
   INSTANCE_ID=<preenchido após terraform apply>
   ```

4. Aplique o Terraform:
   ```bash
   terraform init
   terraform apply
   ```

5. Conecte ao servidor via SSM:
   ```bash
   # O comando completo é exibido no output do Terraform
   terraform output ssm_command
   ```

6. Conecte no Minecraft: `<ELASTIC_IP>:25565`

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

## Mods

O servidor usa **Fabric** como mod loader. Para instalar mods (ex: Lithium, Starlight, FerriteCore), consulte o guia em [`mods/README.md`](mods/README.md).

## Estimativa de custos (us-east-1)

Valores estimados com base nos preços on-demand da AWS em us-east-1 (abril/2026). O servidor é projetado para ser ligado/desligado sob demanda — os custos variam conforme o uso.

| Recurso | Tipo | 4h/dia | 8h/dia | 24/7 |
|---|---|---|---|---|
| EC2 | t3.small ($0,0208/h) | $2,50 | $4,99 | $15,18 |
| EBS | gp3 30 GB | $2,40 | $2,40 | $2,40 |
| Elastic IP | IPv4 público ($0,005/h) | $3,65 | $3,65 | $3,65 |
| S3 | Backups (7 dias retenção) | ~$0,10 | ~$0,10 | ~$0,10 |
| Data transfer | Desprezível (2 jogadores) | — | — | — |
| **Total estimado** | | **~$8,65/mês** | **~$11,14/mês** | **~$21,33/mês** |

> **Nota:** O EBS e o Elastic IP são cobrados 24/7, mesmo com a instância desligada. O Elastic IP sozinho representa ~$3,65/mês fixo. O budget de $20/mês com alertas a 50%, 75% e 100% ajuda a manter o controle.

## Variáveis

| Variável | Descrição | Default |
|---|---|---|
| `region` | Região AWS | `us-east-1` |
| `instance_type` | Tipo da instância EC2 | `t3.small` |
| `server_name` | Nome tag do servidor | `minecraft-server` |
| `alert_email` | Email para alertas de custo | (obrigatório) |
| `whitelist_players` | Lista de jogadores permitidos | (obrigatório) |

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
