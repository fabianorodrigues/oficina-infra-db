# oficina-infra-db

## Visão Geral

Este repositório provisiona a base de rede e banco de dados da solução Oficina: VPC, subnets públicas, subnets privadas sem NAT, security groups e Amazon RDS SQL Server Express.

## Responsabilidade

- Criar `public_subnet_ids` para o EKS/node group mínimo.
- Criar `private_subnet_ids` para RDS, Lambda Auth, NLB interno e VPC Link.
- Criar o security group da Lambda Auth.
- Criar o RDS SQL Server.
- Controlar acesso operacional ao RDS via SSMS por IP do operador.

## Ordem De Implantação

1. `oficina-infra-db`
2. `oficina-infra-k8s` core
3. `oficina-infra-k8s` addons
4. `oficina-api`
5. `oficina-auth-lambda`
6. `oficina-infra-k8s` API Gateway
7. novo deploy da `oficina-api` com `EMAIL_BASE_URL_APROVA_RECUSA_ORCAMENTO`

## Configuração Necessária

Configure em `GitHub > Settings > Secrets and variables > Actions`:

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Autenticação AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticação AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS |
| `TF_STATE_BUCKET` | Secret | Bucket S3 do Terraform State |
| `TF_VAR_db_username` | Secret | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Secret | Senha do SQL Server |
| `ENABLE_OPERATOR_DB_ACCESS` | Variable opcional | Habilita acesso via SSMS; padrão `false` |
| `TF_VAR_operator_cidr` | Secret opcional | IP público `/32` do operador quando o acesso via SSMS estiver habilitado |

O acesso via SSMS é operacional, opcional e restrito ao `operator_cidr`.

## Como Executar Na AWS

Pull Requests executam validações não destrutivas pelo workflow `Terraform Check`.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow prepara o backend S3 com locking nativo, executa plan/apply e valida o RDS.

## Como Validar Na AWS

Valide pelo resultado do workflow. Para validação operacional fora do pipeline, consulte os recursos em uma sessão autenticada.

Resultado esperado:

- RDS `available`.
- SQL Server Express.
- Sem acesso externo ao RDS quando `ENABLE_OPERATOR_DB_ACCESS=false`.
- Acesso via SSMS restrito ao `/32` quando `ENABLE_OPERATOR_DB_ACCESS=true`.

## Como Executar Localmente

```powershell
cd oficina-infra-db/terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Para plano local opcional, copie `terraform.tfvars.example` para `terraform.tfvars` e preencha valores reais somente localmente. Não versione `terraform.tfvars`.

## Valores Gerados

- `vpc_id`
- `vpc_cidr_block`
- `public_subnet_ids`
- `private_subnet_ids`
- `lambda_subnet_id`
- `lambda_security_group_id`
- dados mínimos do RDS para montagem segura da connection string fora do Terraform


## Próxima Etapa

Executar o `oficina-infra-k8s` core, que consome automaticamente a rede deste state remoto.
