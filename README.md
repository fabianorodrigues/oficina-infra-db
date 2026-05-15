# oficina-infra-db

## Visão geral

Este repositório provisiona a base de rede e banco da solução Oficina na AWS. Ele cria VPC, subnets públicas e privadas, Security Groups e Amazon RDS SQL Server Express, expondo outputs consumidos pelos repositórios de Kubernetes, API e Lambdas.

## Diagrama de arquitetura

```text
┌──────────────────────── VPC 10.30.0.0/16 ───────────────────────┐
│                                                                 │
│  Subnet pública 1a        Subnet pública 1b                     │
│  ┌─────────────────┐      ┌─────────────────┐                   │
│  │  EKS nodes      │      │  EKS nodes      │                   │
│  │  acesso IGW     │      │  acesso IGW     │                   │
│  └─────────────────┘      └─────────────────┘                   │
│                                                                 │
│  Subnet privada 1a        Subnet privada 1b                     │
│  ┌─────────────────┐      ┌─────────────────┐                   │
│  │  RDS SQL Server │      │  NLB interno    │                   │
│  │  Lambda Auth SG │      │  VPC Link       │                   │
│  └─────────────────┘      └─────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

## Tecnologias utilizadas

- Terraform
- AWS VPC, Subnets, Internet Gateway e Security Groups
- AWS RDS SQL Server Express
- AWS S3 para state remoto
- GitHub Actions

## Sequência de Deploy (modo padrão `terraform_nlb`)

| Passo | Repositório | O que provisiona |
|-------|-------------|-----------------|
| **1** | **oficina-infra-db ← este** | VPC, subnets, RDS SQL Server |
| 2 | oficina-infra-k8s core | EKS, ECR, NLB interno |
| 3 | oficina-api | Migrations, Deployment, Service |
| 4 | oficina-auth-lambda | Lambdas de autenticação |
| 5 | oficina-infra-k8s API Gateway | Entrada pública (HTTP API) |
| 6 | oficina-api (opcional) | Redeploy para URL pública em e-mails |

## Configuração necessária

Configure em `GitHub > Settings > Secrets and variables > Actions`:

| Nome | Tipo | Uso |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | Autenticação AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticação AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS |
| `TF_STATE_BUCKET` | Secret | Nome do bucket S3 para o state remoto |
| `TF_VAR_db_username` | Secret | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Secret | Senha do SQL Server (8 a 128 caracteres) |
| `TF_VAR_operator_cidr` | Secret opcional | IPv4 `/32` autorizado para acesso operacional ao RDS |
| `PROJECT_NAME` | Variable opcional | Prefixo lógico; padrão `oficina` |
| `ENVIRONMENT` | Variable opcional | Ambiente; padrão `dev` |

O bucket S3 indicado em `TF_STATE_BUCKET` é criado automaticamente pelo workflow se não existir, com versionamento, criptografia AES256 e bloqueio de acesso público habilitados.

`TF_VAR_operator_cidr` controla o acesso operacional ao SQL Server:

- vazio ou ausente: RDS permanece privado;
- preenchido com `/32`: acesso TCP `1433` liberado somente para esse IP (útil para conexão via SSMS).

## Como executar

Pull requests executam `Terraform Check`, com `fmt`, `init -backend=false` e `validate`.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow prepara o backend S3, executa `plan`, aplica o Terraform e valida apenas o estado do RDS, sem imprimir connection string, endpoint ou valores sensíveis.

## Como validar pela AWS

Console:

- Em S3, confirme bucket de state com versionamento, criptografia e bloqueio público.
- Em VPC, confirme subnets públicas e privadas com tags do projeto.
- Em RDS, confirme instância `available`, engine SQL Server Express e acesso público apenas quando `TF_VAR_operator_cidr` estiver configurado.
- Em Security Groups, confirme TCP `1433` restrito ao `/32` quando o acesso operacional estiver habilitado.

CLI:

```powershell
$env:AWS_REGION="<regiao>"
$env:TF_STATE_BUCKET="<bucket-de-state>"
$env:PROJECT_NAME="oficina"

aws s3api get-bucket-versioning --bucket $env:TF_STATE_BUCKET --query "Status"
aws rds describe-db-instances --db-instance-identifier "$($env:PROJECT_NAME)-sqlserver" --region $env:AWS_REGION --query "DBInstances[0].{Status:DBInstanceStatus,Engine:Engine,PubliclyAccessible:PubliclyAccessible}"
aws ec2 describe-subnets --region $env:AWS_REGION --filters "Name=tag:Repository,Values=oficina-infra-db" --query "length(Subnets)"
```

## Como validar localmente

Execute apenas validações não destrutivas:

```powershell
cd oficina-infra-db/terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Para `plan` local, use `terraform.tfvars` não versionado a partir do exemplo do repositório.

## Próxima etapa

Executar `oficina-infra-k8s` core com o mesmo `TF_STATE_BUCKET`, para consumir a VPC, subnets e dados de rede criados por este repositório.
