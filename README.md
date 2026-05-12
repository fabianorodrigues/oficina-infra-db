# oficina-infra-db

## Visão geral

Este repositório provisiona a base de rede e banco de dados da solução Oficina API. Ele é a primeira etapa da implantação e entrega os recursos compartilhados pelos demais projetos: VPC, subnets públicas, security groups e uma instância Amazon RDS SQL Server Express.

A solução completa é composta por quatro repositórios, nesta ordem de implantação:

1. `oficina-infra-db`: rede, security groups e RDS.
2. `oficina-infra-k8s`: ECR, EKS e node group.
3. `oficina-api`: imagem Docker, migrations e deploy da API no EKS.
4. `oficina-auth-lambda`: Lambdas de autenticação por CPF e autorização JWT.

## Papel deste repositório

- Provisionar a VPC e as subnets usadas pela solução.
- Provisionar o RDS SQL Server Express.
- Permitir acesso administrativo ao RDS apenas pelo CIDR do operador.
- Criar o security group específico da Lambda Auth.
- Publicar outputs usados na configuração dos outros repositórios.

## Integração e dependências

Este repositório inicia a infraestrutura e não depende de outputs de outros projetos. Os outputs do Terraform existem para facilitar o provisionamento, a integração entre repositórios e a avaliação acadêmica do projeto como portfólio. Como podem expor metadados operacionais, como VPC, subnet, security group e endpoint, eles são tratados como sensíveis e não são impressos nos logs do pipeline.

| Output | Consumidor | Uso |
|---|---|---|
| `db_address`, `db_port`, `db_name` | `oficina-api`, `oficina-auth-lambda` | Montar `DB_CONNECTION_STRING` com usuário e senha do banco |
| `vpc_id` | `oficina-infra-k8s` | Configurar `TF_VAR_vpc_id` |
| `subnet_ids` | `oficina-infra-k8s` | Configurar `TF_VAR_subnet_ids` em formato JSON |
| `lambda_subnet_id` | `oficina-auth-lambda` | Configurar `LAMBDA_SUBNET_IDS` com um único subnet ID |
| `lambda_security_group_id` | `oficina-auth-lambda` | Configurar `LAMBDA_SECURITY_GROUP_IDS` com um único security group ID |
| `db_connection_string_without_password` | `oficina-api`, `oficina-auth-lambda` | Base para montar a connection string sem expor credenciais |

Modelo de connection string:

```text
Server=<db_address>,<db_port>;Database=<db_name>;User Id=<db-user>;Password=<db-password>;Encrypt=True;TrustServerCertificate=True;
```

## Configuração necessária

Configure os valores em `GitHub > Settings > Secrets and variables > Actions`.

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Autenticar na AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Autenticar na AWS |
| `AWS_SESSION_TOKEN` | Secret opcional | Usar credenciais temporárias |
| `AWS_REGION` | Secret | Região AWS usada pelo projeto |
| `TF_STATE_BUCKET` | Secret | Bucket S3 do Terraform State remoto |
| `TF_VAR_db_username` | Secret | Usuário administrador do SQL Server |
| `TF_VAR_db_password` | Secret | Senha do SQL Server |
| `TF_VAR_operator_cidr` | Secret | IP público do operador em formato `/32` |

Para descobrir o IP público no PowerShell:

```powershell
Invoke-RestMethod https://checkip.amazonaws.com
```

Configure `TF_VAR_operator_cidr` como `<seu-ip-publico>/32`.

## Como executar e validar na AWS

Em Pull Requests, o workflow `Terraform Check` valida a formatação e a configuração Terraform.

Após o merge na `main`, execute manualmente:

```text
GitHub Actions > Terraform Apply > Run workflow
```

O workflow prepara o backend remoto, executa `terraform plan`, aplica a infraestrutura e valida o RDS sem imprimir dados de infraestrutura nos logs.

Para validar manualmente:

```powershell
aws rds describe-db-instances --db-instance-identifier oficina-sqlserver --region <region> --query "DBInstances[0].[DBInstanceStatus,Engine,Endpoint.Address,Endpoint.Port,PubliclyAccessible]"
```

Resultado esperado:

- RDS com status `available`;
- engine `sqlserver-ex`;
- endpoint e porta preenchidos;
- acesso administrativo restrito ao `TF_VAR_operator_cidr`;
- acesso ao RDS liberado para o security group da Lambda Auth e para a VPC.

## Problemas comuns

| Problema | Possível causa | Como resolver |
|---|---|---|
| Workflow falha por secret ausente | Configuração obrigatória não criada | Revise a tabela de configuração |
| Acesso local ao SQL Server falha | `TF_VAR_operator_cidr` incorreto | Atualize o secret com o IP público atual em formato `/32` |
| Lambda não conecta no RDS | Subnet ou security group incorreto no repo da Lambda | Use `lambda_subnet_id` e `lambda_security_group_id` |
| RDS demora para ficar disponível | Criação ainda em andamento | Aguarde alguns minutos e valide novamente |

## Como executar e validar localmente

Para validação local do Terraform:

```powershell
cd oficina-infra-db/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Para consultar outputs em ambiente autenticado, use comandos explícitos e evite colar os valores em logs públicos:

```powershell
terraform output -raw db_address
terraform output -raw vpc_id
terraform output -json subnet_ids
terraform output -raw lambda_subnet_id
terraform output -raw lambda_security_group_id
```

Para um plano local opcional, copie o exemplo e preencha os valores reais:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
terraform plan
```

Não versione `terraform.tfvars` real.
